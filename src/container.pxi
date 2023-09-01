from pathlib import Path
import uuid


OBJ_MAGIC_BYTES = b'Obj\x01'
cdef const uint8_t[:] OBJ_MAGIC = OBJ_MAGIC_BYTES
OBJ_FILE_METADATA = Schema({"type": "map", "values": "bytes"}, bytes_codec='utf8')

SLICE_TYPE = type(OBJ_MAGIC)


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
    cdef readonly Schema writer_schema
    cdef readonly Schema reader_schema
    cdef readonly Schema schema
    cdef readonly str codec_name
    cdef readonly size_t objects_left_in_block
    cdef MemoryReader current_block
    cdef Codec codec
    cdef Reader reader

    def __init__(self, src, reader_schema=None, options=DEFAULT_OPTIONS):
        self.reader = make_reader(src)
        cdef const uint8_t[:] header = self.reader.read_n(4)
        if viewcmp(header, OBJ_MAGIC):
            raise ValueError(f"Invalid file header, expected: {bytes(OBJ_MAGIC)} got {bytes(header)}")
        self.metadata = OBJ_FILE_METADATA.binary_read(self.reader)
        self.writer_schema = Schema(self.metadata['avro.schema'], options=options)
        if reader_schema is None:
            self.schema = self.reader_schema = self.writer_schema
        else:
            self.reader_schema = reader_schema
            self.schema = self.reader_schema.reader_for_writer(self.writer_schema)

        codec_name = self.metadata.get('avro.codec', b'null')
        self.codec_name = codec_name.decode()
        try:
            self.codec = CODECS[codec_name]
        except KeyError:
            raise CodecUnavailable(f"Unsupported codec: '{codec_name.decode('utf-8')}'")
        self.objects_left_in_block = 0
        self.current_block = MemoryReader(empty_buffer)
        self.marker = b''

    cpdef _read_marker(self):
        value = self.reader.read_n(16)
        if not len(self.marker):
            self.marker = value
        else:
            if viewcmp(value, self.marker):
                raise ValueError(f"Invalid block sync marker, expected {bytes(self.marker)}, got {bytes(value)}")

    cdef int next_block(self) except -1:
        try:
            self._read_marker()
            self.objects_left_in_block = zigzag_decode_long(self.reader)
        except (EOFError, ValueError) as e:
            raise StopIteration() from e
        cdef size_t block_size = zigzag_decode_long(self.reader)
        cdef const uint8_t[:] block_bytes
        if block_size > 0:
            block_bytes = self.codec.read_block(self.reader, block_size)
        else:
            block_bytes = empty_buffer
        self.current_block._reset_to(block_bytes)

    cpdef object next_object(self):
        while self.objects_left_in_block < 1:
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

    cdef readonly Schema schema
    cdef readonly Codec codec
    cdef readonly const uint8_t[:] marker
    cdef readonly size_t max_blocksize
    cdef readonly Options options

    cdef readonly bint should_write_header

    cdef readonly size_t num_pending
    cdef readonly int blocks_written
    
    cdef readonly dict metadata

    def __cinit__(self, dest, Schema schema, str codec='null', size_t max_blocksize=16352, write_header=True, metadata=None, marker=None, options=DEFAULT_OPTIONS):
        if schema is None:
            raise ValueError('Schema is required')
        self.should_write_header = write_header
        self.num_pending = 0
        self.pending_block = MemoryWriter(max_blocksize)
        self.next_item = MemoryWriter()
        self.next_block = MemoryWriter()
        self.options = options
        
        if metadata is None:
            metadata = {}
        self.metadata = metadata

        self.writer = make_writer(dest)
        try:
            self.schema = schema
            codec_b = codec.encode('utf8')
            try:
                self.codec = CODECS[codec_b]
            except KeyError as e:
                raise CodecUnavailable(codec) from e
            if marker is None:
                marker = uuid.uuid4().bytes
            else:
                if not isinstance(marker, (bytes, SLICE_TYPE)):
                    raise ValueError(f'Marker must be bytes, got: {type(marker)}')
                if len(marker) != 16:
                    raise ValueError(f'Marker must be exactly 16 bytes, got: {bytes(marker)}')
            self.marker = marker
            self.max_blocksize = max_blocksize
            self.blocks_written = 0
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
            try:
                self.close()
            except ValueError as e:
                warnings.warn(f'Error closing container file during __del__: {e}', ResourceWarning)
                pass # We might be shutting down, and our writer might have been closed

    @property
    def closed(self):
        return self.writer is None

    cdef int _write_header(self) except -1:
        self.writer.write_n(OBJ_MAGIC)
        meta = self.metadata.copy()
        meta['avro.schema'] = json.dumps(self.schema.schema)
        meta['avro.codec'] = self.codec.name
        OBJ_FILE_METADATA.binary_write(self.writer, meta)
        self.writer.write_n(self.marker)
        return 0

    def close(self):
        if self.writer is None:
            raise ValueError('Trying to close a closed Container')
        cdef Writer writer = self.writer
        self._flush_block(self.blocks_written == 0)
        self.writer = None
        self.next_item = None

    cdef int _flush_block(self, int force=False) except -1:
        cdef size_t pending_len = self.pending_block.len
        if force or self.num_pending > 0:
            if self.blocks_written == 0 and self.should_write_header:
                self._write_header()
            zigzag_encode_long(self.writer, self.num_pending)
            self.next_block.reset()
            self.codec.write_block(self.next_block, self.pending_block.view())
            zigzag_encode_long(self.writer, self.next_block.len)
            if self.next_block.len > 0:
                self.writer.write_n(self.next_block.view())
            self.writer.write_n(self.marker)
            self.blocks_written += 1
            self.pending_block.reset()
            self.num_pending = 0
        self.writer.flush()
        return 0

    def flush(self, force=False):
        self._flush_block(force)

    cpdef int write_one(self, obj) except -1:
        if self.next_item is None:
            raise ValueError('Trying to write to closed Container')
        self.next_item.reset()
        self.schema.binary_write(self.next_item, obj)

        if not self.options.container_fill_blocks:
            if self.pending_block.len + self.next_item.len > self.max_blocksize:
                self._flush_block()

        self.pending_block.write_n(self.next_item.view())
        self.num_pending += 1

        if self.options.container_fill_blocks:
            if self.pending_block.len >= self.max_blocksize:
                self._flush_block()

    def write_many(self, objs):
        for obj in objs:
            self.write_one(obj)
