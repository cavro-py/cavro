import io


cdef class Writer:

    cdef int write_u8(self, uint8_t val) except -1:
        raise NotImplementedError(
            f"{type(self).__name__} does not implement write_u8")

    cdef int write_n(self, size_t num, uint8_t *bytes) except -1:
        raise NotImplementedError(
            f"{type(self).__name__} does not implement write_n")


cdef class Reader:

    cdef uint8_t read_u8(self) except? 0xba:
        raise NotImplementedError(
            f"{type(self).__name__} does not implement read_u8")

    cdef bytes read_bytes(self, Py_ssize_t n):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement read_bytes")

    cdef const uint8_t[:] read_n(self, Py_ssize_t n):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement read_n")


cdef class FileReader(Reader):
    cdef object file_obj

    def __init__(self, file_obj):
        self.file_obj = file_obj

    cdef uint8_t read_u8(self) except? 0xba:
        cdef bytes data = self.file_obj.read(1)
        if len(data) != 1:
            raise EOFError(f"End of file found trying to read 1 byte")
        return ord(data)

    cdef bytes read_bytes(self, Py_ssize_t n):
        cdef bytes result = self.file_obj.read(n)
        if len(result) != n:
            raise EOFError(f"End of file found trying to read {n} bytes")
        return result

    cdef const uint8_t[:] read_n(self, Py_ssize_t n):
        cdef bytes result = self.file_obj.read(n)
        if len(result) != n:
            raise EOFError(f"End of file found trying to read {n} bytes")
        return result