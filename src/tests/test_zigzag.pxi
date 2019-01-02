
cpdef str ubin(val, n_bytes):
    cdef str raw = bin(val)[2:]
    padded = raw.rjust(n_bytes * 8, '0')
    parts = [padded[i:i+8] for i in range(0, len(padded), 8)]
    return " ".join(parts)

cdef struct random_t:
    uint64_t state
    uint64_t inc

cdef uint32_t rand(random_t *rng):
    cdef uint64_t oldstate = rng.state;
    rng.state = oldstate * 6364136223846793005ULL + (rng.inc|1);
    cdef uint32_t xorshifted = ((oldstate >> 18u) ^ oldstate) >> 27u;
    cdef uint32_t rot = oldstate >> 59u;
    return (xorshifted >> rot) | (xorshifted << ((-rot) & 31));

cdef bytes boring_varint_encoder(uint64_t val):
    cdef uint8_t cur = 0
    out = []
    while val:
        cur = val & 0x7f
        val >>= 7
        if val:
            out.append(cur | 0x80)
    out.append(cur)
    return bytes(out)

@_tests
def _tests(add):

    def test_readvarint(uint32_t mask):
        cdef random_t state

        cdef uint32_t actual
        cdef uint32_t given
        cdef bytes src
        cdef MemoryReader reader

        cdef uint32_t i

        for i in range(50_000):
            given = rand(&state) & mask
            src = boring_varint_encoder(given)
            reader = MemoryReader(src)
            actual = read_varint(reader)
            if actual != given:
                raise AssertionError(f"{src}:\n   {ubin(actual, 4)}\n!= {ubin(given, 4)}")
    for mask in [0x7f, 0x7fff, 0x7fffff, 0x7fffffff, UINT32_MAX]:
        add(test_readvarint, mask)

    def test_zigzag_long(uint64_t mask):
        cdef random_t state

        cdef int64_t actual
        cdef int64_t given
        cdef MemoryWriter writer = MemoryWriter()
        cdef MemoryReader reader

        cdef uint64_t i
        cdef uint64_t pad

        pad = (<uint64_t>rand(&state) | (<uint64_t>rand(&state) << 32))
        for i in range(50_000):
            writer.reset()
            given = <int64_t>((<uint64_t>rand(&state) | (<uint64_t>rand(&state) << 32)) & mask)
            zigzag_encode_long(writer, given)
            reader = MemoryReader(writer.bytes())
            actual = zigzag_decode_long(reader)
            if actual != given:
                raise AssertionError(f"{writer.bytes()}: {given}\n   {ubin(actual, 8)}\n!= {ubin(given, 8)}")

    def test_readvarlong(uint64_t mask):
        cdef random_t state

        cdef uint64_t actual
        cdef uint64_t given
        cdef bytes src
        cdef MemoryReader reader

        cdef uint64_t i
        cdef uint64_t pad

        pad = (<uint64_t>rand(&state) | (<uint64_t>rand(&state) << 32))
        for i in range(50_000):
            given = (<uint64_t>rand(&state) | (<uint64_t>rand(&state) << 32)) & mask
            src = boring_varint_encoder(given)
            src += (<char*>&pad)[:8]
            reader = MemoryReader(src)
            actual = read_varlong(reader)
            if actual != given:
                raise AssertionError(f"{src}: {given}\n   {ubin(actual, 8)}\n!= {ubin(given, 8)}")

    for mask in [
        0x7f, 0x7fff, 0x7fffff, 0x7fffffff, 0x7fffffffffull,
         0x7fffffffffffull, 0x7fffffffffffffull, 0x7fffffffffffffffull,
        UINT64_MAX]:
        add(test_readvarlong, mask)
        add(test_zigzag_long, mask)