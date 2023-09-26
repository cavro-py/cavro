

cdef class PromoteToFloat(ValueAdapter):

    """
    A value adapter that converts a value to a float on read.
    """

    cdef encode_value(self, value):
        raise NotImplementedError(f"Promoting schemas (reader/writer) do no support encoding values, use the writer schema directly.")

    cdef decode_value(self, value):
        return float(value)


cdef class PromoteBytesToString(ValueAdapter):

    """
    A value adapter that decodes bytes to a string (utf8) on read.
    """

    cdef encode_value(self, value):
        raise NotImplementedError(f"Promoting schemas (reader/writer) do no support encoding values, use the writer schema directly.")

    cdef decode_value(self, value):
        return value.decode("utf-8")


cdef class PromoteStringToBytes(ValueAdapter):

    """
    A value adapter that encodes a string to bytes (utf8) on read.
    """

    cdef encode_value(self, value):
        raise NotImplementedError(f"Promoting schemas (reader/writer) do no support encoding values, use the writer schema directly.")

    cdef decode_value(self, value):
        return value.encode("utf-8")


cdef class CannotPromote(ValueAdapter):

    """
    A captured schema promotion error that has been deferred by `Options`, the first time this value is read, the error will be raised.
    """


    cdef readonly AvroType reader_type
    cdef readonly AvroType writer_type
    cdef readonly object extra

    def __init__(self, reader_type, writer_type, extra=None):
        self.reader_type = reader_type
        self.writer_type = writer_type
        self.extra = extra

    cdef encode_value(self, value):
        raise NotImplementedError(f"Promoting schemas (reader/writer) do no support encoding values, use the writer schema directly.")

    cdef decode_value(self, value):
        raise CannotPromoteError(self.reader_type, self.writer_type, self.extra)