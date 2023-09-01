

cdef class PromoteToFloat(ValueAdapter):

    cdef encode_value(self, value):
        raise NotImplementedError(f"Promoting schemas (reader/writer) do no support encoding values, use the Writer schema directly.")

    cdef decode_value(self, value):
        return float(value)


cdef class PromoteBytesToString(ValueAdapter):

    cdef encode_value(self, value):
        raise NotImplementedError(f"Promoting schemas (reader/writer) do no support encoding values, use the Writer schema directly.")

    cdef decode_value(self, value):
        return value.decode("utf-8")


cdef class PromoteStringToBytes(ValueAdapter):

    cdef encode_value(self, value):
        raise NotImplementedError(f"Promoting schemas (reader/writer) do no support encoding values, use the Writer schema directly.")

    cdef decode_value(self, value):
        return value.encode("utf-8")


cdef class CannotPromote(ValueAdapter):

    cdef readonly AvroType reader_type
    cdef readonly AvroType writer_type

    def __init__(self, reader_type, writer_type):
        self.reader_type = reader_type
        self.writer_type = writer_type

    cdef encode_value(self, value):
        raise NotImplementedError(f"Promoting schemas (reader/writer) do no support encoding values, use the Writer schema directly.")

    cdef decode_value(self, value):
        raise CannotPromoteError(self.reader_type, self.writer_type)