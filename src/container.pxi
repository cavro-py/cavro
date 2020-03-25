
OBJ_MAGIC_BYTES = b'Obj\x01'
cdef const uint8_t[:] OBJ_MAGIC = OBJ_MAGIC_BYTES
OBJ_FILE_METADATA = Schema({"type": "map", "values": "bytes"})


cdef int viewcmp(const uint8_t[:] a, const uint8_t[:] b):
    if len(a) != len(b):
        return 1
    return memcmp(&a[0], &b[0], len(a))


cdef class Codec:

    cdef const uint8_t[:] read_block(self, Reader reader, size_t length):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement read_block")

    # cdef int write_block(self, Writer writer, bytes data):
    #     raise NotImplementedError(
    #         f"{type(self).__name__} does not implement write_block")


cdef class NullCodec(Codec):

    cdef const uint8_t[:] read_block(self, Reader reader, size_t length):
        return reader.read_n(length)


CODECS = {
    b'null': NullCodec
}

cdef class Container:
    cdef readonly object metadata
    cdef readonly const uint8_t[:] marker
    cdef readonly Schema schema
    cdef size_t objects_left_in_block
    cdef MemoryReader current_block
    cdef Codec codec
    cdef Reader reader

    def __init__(self, file_obj):
        self.reader = FileReader(file_obj)
        cdef const uint8_t[:] header = self.reader.read_n(4)
        if viewcmp(header, OBJ_MAGIC):
            raise ValueError(f"Invalid file header, expected: {OBJ_MAGIC} got {header}")
        self.metadata = OBJ_FILE_METADATA.binary_read(self.reader)
        self.schema = Schema(self.metadata['avro.schema'])
        codec_name = self.metadata.get('avro.codec', 'null')
        try:
            self.codec = CODECS[codec_name]()
        except KeyError:
            raise ValueError(f"Unsupported codec: '{codec_name.decode('utf-8')}'")
        self.objects_left_in_block = 0
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
        self.current_block = MemoryReader(block_bytes)

    cpdef object next_object(self):
        if self.objects_left_in_block == 0:
            self.next_block()
        self.objects_left_in_block -= 1
        return self.schema.binary_read(self.current_block)

    def __iter__(self):
        return self

    def __next__(self):
        return self.next_object()
