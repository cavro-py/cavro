
@_perf
def _perf(add):
    def _test_zigzag_perf(const uint64_t mask):
        from time import clock
        import os
        cdef random_t state

        cdef uint64_t BATCH_SIZE = 5_000_000

        cdef uint64_t actual
        cdef uint64_t given
        cdef bytes src
        cdef MemoryWriter writer = MemoryWriter(3442987655)
        cdef MemoryReader reader

        cdef size_t total_nums = 0
        cdef int n
        cdef uint64_t i
        cdef uint64_t out_state = 0
        t_a = clock()
        for i in range(BATCH_SIZE):
            given = (<uint64_t>rand(&state) | (<uint64_t>rand(&state) << 32)) & mask
            zigzag_encode_long(writer, given)
            total_nums += 1
        write_time = clock() - t_a
        t_a = clock()
        reader = MemoryReader(writer.bytes())
        copy_time = clock() - t_a
        t_a = clock()
        for n in range(total_nums):
            out_state ^= zigzag_decode_long(reader)
        read_time = clock() - t_a

        write_perf = (1_000_000_000 * write_time) / BATCH_SIZE
        read_perf = (1_000_000_000 * read_time) / BATCH_SIZE
        print(f"{hex(mask)}: {out_state}: write: {write_perf} ns, copy: {copy_time} s, read: {read_perf} ns")

    for mask in [
        0x7f, 0x7fff, 0x7fffff, 0x7fffffff, UINT32_MAX,
        0x7ffffffffful, 0x7ffffffffffful, 0x7ffffffffffffful,
        0x7ffffffffffffffful, UINT64_MAX
        ]:
        add(_test_zigzag_perf, mask)
