from pathlib import Path
import uuid


OBJ_MAGIC_BYTES = b'Obj\x01'
cdef const uint8_t[:] OBJ_MAGIC = OBJ_MAGIC_BYTES
OBJ_FILE_METADATA = Schema({"type": "map", "values": "bytes"})


cdef int viewcmp(const uint8_t[:] a, const uint8_t[:] b):
    if len(a) != len(b):
        return 1
    return memcmp(&a[0], &b[0], len(a))


cdef Reader make_reader(src):
    if isinstance(src, Reader):
        return src
    elif isinstance(src, bytes):
        return MemoryReader(src)
    elif isinstance(src, (str, Path)):
        return FileReader(Path(src).open('rb'))
    elif hasattr(src, 'read'):
        return FileReader(src)
    else:
        raise NotImplementedError(f"Cannot read from '{src}'")


cdef Writer make_writer(src):
    if isinstance(src, Writer):
        return src
    elif isinstance(src, (str, Path)):
        return FileObjWriter(Path(src).open('wb'))
    elif hasattr(src, 'write'):
        return FileObjWriter(src)
    raise NotImplementedError(f"Cannot write to '{src}'")
    

cdef class ContainerReader:
    cdef readonly object metadata
    cdef readonly const uint8_t[:] marker
    cdef readonly Schema schema
    cdef size_t objects_left_in_block
    cdef MemoryReader current_block
    cdef Codec codec
    cdef Reader reader

    def __init__(self, src):
        self.reader = make_reader(src)
        cdef const uint8_t[:] header = self.reader.read_n(4)
        if viewcmp(header, OBJ_MAGIC):
            raise ValueError(f"Invalid file header, expected: {bytes(OBJ_MAGIC)} got {bytes(header)}")
        self.metadata = OBJ_FILE_METADATA.binary_read(self.reader)
        self.schema = Schema(self.metadata['avro.schema'])
        codec_name = self.metadata.get('avro.codec', b'null')
        try:
            self.codec = CODECS[codec_name]
        except KeyError:
            raise ValueError(f"Unsupported codec: '{codec_name.decode('utf-8')}'")
        self.objects_left_in_block = 0
        self.current_block = MemoryReader(empty_buffer)
        self.marker = b''

    cdef int next_block(self) except -1:
        cdef const uint8_t[:] marker = self.reader.read_n(16)
        if not len(self.marker):
            self.marker = marker
        else:
            if viewcmp(marker, self.marker):
                raise ValueError(f"Invalid block sync marker, expected {self.marker}, got {marker}")

        try:
            self.objects_left_in_block = zigzag_decode_long(self.reader)
        except EOFError:
            raise StopIteration()
        cdef size_t block_size = zigzag_decode_long(self.reader)
        cdef const uint8_t[:] block_bytes = self.codec.read_block(self.reader, block_size)
        self.current_block._reset_to(block_bytes)

    cpdef object next_object(self):
        if self.objects_left_in_block == 0:
            self.next_block()
        self.objects_left_in_block -= 1
        return self.schema.binary_read(self.current_block)

    def __iter__(self):
        return self

    def __next__(self):
        return self.next_object()


@cython.no_gc_clear
cdef class ContainerWriter:

    cdef Writer writer
    cdef MemoryWriter pending_block
    cdef MemoryWriter next_block
    cdef MemoryWriter next_item

    cdef readonly Schema _schema
    cdef readonly Codec codec
    cdef readonly const uint8_t[:] magic
    cdef readonly size_t max_blocksize

    cdef readonly size_t num_pending
    cdef readonly int blocks_written

    def __cinit__(self, dest, Schema schema, str codec='null', size_t max_blocksize=16352):
        self.num_pending = 0
        self.pending_block = MemoryWriter(max_blocksize)
        self.next_item = MemoryWriter()
        self.next_block = MemoryWriter()

        self.writer = make_writer(dest)
        try:
            self._schema = schema
            codec_b = codec.encode('utf8')
            self.codec = CODECS[codec_b]
            self.magic = uuid.uuid4().bytes
            self.max_blocksize = max_blocksize
            self.blocks_written = 0

            self._write_header(codec_b)
        except:
            self.writer = None
            raise

    def __enter__(self):
        if self.writer is None:
            raise ValueError('Container is closed')
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.writer is not None:
            self.close()
        return False

    def __del__(self):
        if self.writer is not None:
            self.close()

    @property
    def closed(self):
        return self.writer is None

    cdef _write_header(self, bytes codec):
        self.writer.write_n(OBJ_MAGIC)
        OBJ_FILE_METADATA.binary_write(self.writer, {
            'avro.schema': json.dumps(self._schema.source).encode(),
            'avro.codec': codec,
        })
        self.writer.write_n(self.magic)

    def close(self):
        if self.writer is None:
            raise ValueError('Trying to close a closed Container')
        cdef Writer writer = self.writer
        self._flush_block(self.blocks_written == 0)
        self.writer = None
        self.next_item = None

    cdef _flush_block(self, int force=False):
        cdef size_t pending_len = self.pending_block.len
        if force or pending_len > 0:
            zigzag_encode_long(self.writer, self.num_pending)
            self.next_block.reset()
            if pending_len > 0:
                self.codec.write_block(self.next_block, self.pending_block.view())
            zigzag_encode_long(self.writer, self.next_block.len)
            if self.next_block.len > 0:
                self.writer.write_n(self.next_block.view())
            self.writer.write_n(self.magic)
            self.blocks_written += 1
            self.pending_block.reset()
            self.num_pending = 0

    cpdef write_one(self, obj):
        if self.next_item is None:
            raise ValueError('Trying to write to closed Container')
        self.next_item.reset()        
        self._schema.binary_write(self.next_item, obj)
        if self.pending_block.len + self.next_item.len > self.max_blocksize:
            self._flush_block()

        self.pending_block.write_n(self.next_item.view())
        self.num_pending += 1

    def write_many(self, objs):
        for obj in objs:
            self.write_one(obj)
