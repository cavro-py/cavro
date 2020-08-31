HAVE_ZLIB = False
try:
    import zlib
    crc32 = zlib.crc32
    HAVE_ZLIB = True
except ImportError:
    pass


HAVE_SNAPPY = False
if HAVE_ZLIB: # Needed for crc32
    try:
        import snappy
        HAVE_SNAPPY = True
    except ImportError:
        pass


cdef class Codec:

    cdef const uint8_t[:] read_block(self, Reader reader, size_t length):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement read_block")

    cdef ssize_t write_block(self, Writer writer, const uint8_t[:] data) except -1:
        raise NotImplementedError(
            f"{type(self).__name__} does not implement write_block")


@cython.final
cdef class SnappyCodec(Codec):

    cdef const uint8_t[:] read_block(self, Reader reader, size_t length):
        cdef const uint8_t[:] compressed = reader.read_n(length - 4)
        cdef const uint8_t[:] checksum = reader.read_n(4)
        cdef bytes decompressed = snappy.decompress(compressed)
        cdef const uint8_t[:] view = decompressed
        return view

    cdef ssize_t write_block(self, Writer writer, const uint8_t[:] data) except -1:
        cdef bytes compressed = snappy.compress(data)
        cdef uint32_t crc = crc32(compressed)
        cdef uint8_t *crc_ptr = <uint8_t *>&crc
        writer.write_n(compressed)
        writer.write_n(crc_ptr[:4])
        return len(compressed) + 4



cdef class NullCodec(Codec):

    cdef const uint8_t[:] read_block(self, Reader reader, size_t length):
        return reader.read_n(length)

    cdef ssize_t write_block(self, Writer writer, const uint8_t[:] data) except -1:
        writer.write_n(data)
        return data.shape[0]


cdef class DeflateCodec(Codec):

    cdef const uint8_t[:] read_block(self, Reader reader, size_t length):
        return zlib.decompress(reader.read_n(length))

    cdef ssize_t write_block(self, Writer writer, const uint8_t[:] data) except -1:
        cdef bytes compressed = zlib.compress(data)
        writer.write_n(compressed)
        return len(compressed)


CODECS = {
    b'null': NullCodec()
}

if HAVE_ZLIB:
    CODECS[b'deflate'] = DeflateCodec()

if HAVE_SNAPPY:
    CODECS[b'snappy'] = SnappyCodec()