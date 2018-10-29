

cdef class Writer:

    cdef int write_u8(self, uint8_t val) except -1:
        raise NotImplementedError(
            f"{type(self).__name__} does not implement write_u8")

    cdef int write_n(self, size_t num, char *bytes) except -1:
        raise NotImplementedError(
            f"{type(self).__name__} does not implement write_n")


cdef class Reader:

    cdef uint8_t read_u8(self) except? 0xba:
        raise NotImplementedError(
            f"{type(self).__name__} does not implement read_u8")

    cdef const uint8_t[:] read_n(self, size_t n):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement read_n")