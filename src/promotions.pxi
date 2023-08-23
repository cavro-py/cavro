

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