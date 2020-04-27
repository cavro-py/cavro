HAVE_SNAPPY = False
try:
    import snappy
    HAVE_SNAPPY = True
except ImportError:
    pass

HAVE_ZLIB = False
try:
    import zlib
    HAVE_ZLIB = True
except ImportError:
    pass


cdef class Codec:

    cdef const uint8_t[:] read_block(self, Reader reader, size_t length):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement read_block")

    # cdef int write_block(self, Writer writer, bytes data):
    #     raise NotImplementedError(
    #         f"{type(self).__name__} does not implement write_block")


@cython.final
cdef class SnappyCodec(Codec):
    
    cdef const uint8_t[:] read_block(self, Reader reader, size_t length):
        cdef const uint8_t[:] compressed = reader.read_n(length - 4)
        cdef const uint8_t[:] checksum = reader.read_n(4)
        cdef bytes decompressed = snappy.decompress(compressed)
        cdef const uint8_t[:] view = decompressed
        return view


cdef class NullCodec(Codec):

    cdef const uint8_t[:] read_block(self, Reader reader, size_t length):
        return reader.read_n(length)


cdef class DeflateCodec(Codec):

    cdef const uint8_t[:] read_block(self, Reader reader, size_t length):
        return zlib.decompress(reader.read_n(length))


CODECS = {
    b'null': NullCodec    
}

if HAVE_ZLIB:
    CODECS[b'deflate'] = DeflateCodec

if HAVE_SNAPPY:
    CODECS[b'snappy'] = SnappyCodec