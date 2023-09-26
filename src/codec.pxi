
HAVE_BZIP2 = False
try:
    import bz2
    HAVE_BZIP2 = True
except ImportError:
    pass

HAVE_XZ = False
try:
    import lzma
    HAVE_XZ = True
except ImportError:
    pass

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


HAVE_ZSTD = False
try:
    import zstandard
    HAVE_ZSTD = True
except ImportError:
    pass


HAVE_LZ4 = False
try:
    import lz4.frame
    HAVE_LZ4 = True
except ImportError:
    pass


cdef class Codec:

    """
    Abstract base class for all codecs.  This class is not meant to be used directly.

    Subclasses must be implemented in cython.
    """

    name = NotImplemented

    cdef const uint8_t[:] read_block(self, _Reader reader, size_t length):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement read_block")

    cdef ssize_t write_block(self, _Writer writer, const uint8_t[:] data) except -1:
        raise NotImplementedError(
            f"{type(self).__name__} does not implement write_block")


@cython.final
cdef class _SnappyCodec(Codec):
    """
    Implemented the snappy codec if python-snappy is installed.
    """

    name = 'snappy'

    cdef const uint8_t[:] read_block(self, _Reader reader, size_t length):
        cdef const uint8_t[:] compressed = reader.read_n(length - 4)
        cdef const uint8_t[:] checksum = reader.read_n(4)
        cdef bytes decompressed = snappy.decompress(compressed)
        cdef const uint8_t[:] view = decompressed
        return view

    cdef ssize_t write_block(self, _Writer writer, const uint8_t[:] data) except -1:
        cdef bytes compressed = snappy.compress(data)
        cdef uint32_t crc = crc32(compressed)
        cdef uint8_t *crc_ptr = <uint8_t *>&crc
        writer.write_n(compressed)
        writer.write_n(crc_ptr[:4])
        return len(compressed) + 4


cdef class _NullCodec(Codec):
    """
    Implements the null codec (no compression)
    """
    name = 'null'

    cdef const uint8_t[:] read_block(self, _Reader reader, size_t length):
        return reader.read_n(length)

    cdef ssize_t write_block(self, _Writer writer, const uint8_t[:] data) except -1:
        writer.write_n(data)
        return data.shape[0]


cdef class _DeflateCodec(Codec):
    """
    Implements the deflate codec
    """
    name = 'deflate'

    cdef const uint8_t[:] read_block(self, _Reader reader, size_t length):
        return zlib.decompress(reader.read_n(length), wbits=-15)

    cdef ssize_t write_block(self, _Writer writer, const uint8_t[:] data) except -1:
        cdef bytes compressed = zlib.compress(data)[2:-1]
        writer.write_n(compressed)
        return len(compressed)


cdef class __Bzip2Codec(Codec):
    """
    Implements the bzip2 codec
    """
    name = 'bzip2'

    cdef const uint8_t[:] read_block(self, _Reader reader, size_t length):
        return bz2.decompress(reader.read_n(length))

    cdef ssize_t write_block(self, _Writer writer, const uint8_t[:] data) except -1:
        cdef bytes compressed = bz2.compress(data)
        writer.write_n(compressed)
        return len(compressed)    


cdef class _LzmaCodec(Codec):
    """
    Implements the lzma codec
    """
    name = 'xz'

    cdef const uint8_t[:] read_block(self, _Reader reader, size_t length):
        return lzma.decompress(reader.read_n(length))

    cdef ssize_t write_block(self, _Writer writer, const uint8_t[:] data) except -1:
        cdef bytes compressed = lzma.compress(data)
        writer.write_n(compressed)
        return len(compressed)


cdef class _ZStandardCodec(Codec):
    """
    Implements the zstandard codec if zstandard is installed.
    """
    name = 'zstandard'

    cdef readonly object compressor
    cdef readonly object decompressor

    def __init__(self):
        self.compressor = zstandard.ZstdCompressor()
        self.decompressor = zstandard.ZstdDecompressor()

    cdef const uint8_t[:] read_block(self, _Reader reader, size_t length):
        decompress_obj = self.decompressor.decompressobj()
        return decompress_obj.decompress(reader.read_n(length))

    cdef ssize_t write_block(self, _Writer writer, const uint8_t[:] data) except -1:
        cdef bytes compressed = self.compressor.compress(data)
        writer.write_n(compressed)
        return len(compressed)


cdef class _Lz4Codec(Codec):
    """
    Implements the lz4 codec if lz4 is installed.
    """
    name = 'lz4'

    cdef const uint8_t[:] read_block(self, _Reader reader, size_t length):
        return lz4.frame.decompress(reader.read_n(length))

    cdef ssize_t write_block(self, _Writer writer, const uint8_t[:] data) except -1:
        cdef bytes compressed = lz4.frame.compress(data)
        writer.write_n(compressed)
        return len(compressed)


CODECS = {
    b'null': _NullCodec()
}

if HAVE_ZLIB:
    CODECS[b'deflate'] = _DeflateCodec()

if HAVE_BZIP2:
    CODECS[b'bzip2'] = __Bzip2Codec()

if HAVE_XZ:
    CODECS[b'xz'] = _LzmaCodec()

if HAVE_SNAPPY:
    CODECS[b'snappy'] = _SnappyCodec()

if HAVE_ZSTD:
    CODECS[b'zstandard'] = _ZStandardCodec()

if HAVE_LZ4:
    CODECS[b'lz4'] = _Lz4Codec()