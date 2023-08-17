

cdef class LogicalType:
    logical_name = NotImplemented
    underlying_types = NotImplemented

    cdef readonly AvroType underlying

    def __init__(self, underlying: AvroType):
        self.underlying = underlying

    @classmethod
    def for_underlying(cls, underlying: AvroType):
        for underlying_type in cls.underlying_types:
            if isinstance(underlying, underlying_type):
                inst = cls._for_underlying(underlying)
                if inst is not None:
                    return inst

    cdef encode_value(self, value):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement encode_value")

    cdef decode_value(self, value):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement decode_value")


cdef class DecimalType(LogicalType):
    logical_name = 'decimal'
    underlying_types = (BytesType, FixedType)

    cdef readonly int precision
    cdef readonly int scale
    cdef readonly object scale_val
    cdef readonly object context

    def __init__(self, precision, scale):
        self.precision = precision
        self.scale = scale
        self.scale_val = decimal.Decimal('1').scaleb(-scale)
        self.context = decimal.Context(prec=self.precision, clamp=1)

    @classmethod
    def _for_underlying(cls, underlying: AvroType):
        meta = underlying.metadata
        if 'precision' not in meta:
            return None
        scale = meta.get('scale', 0)
        if not isinstance(scale, int):
            raise ValueError('scale must be an integer')
        return cls(meta['precision'], scale)

    cdef encode_value(self, value):
        if not isinstance(value, decimal.Decimal):
            value = decimal.Decimal(value)
        
        quant = value.quantize(self.scale_val, context=self.context)
        
        sign, digits, exp = quant.as_tuple()
        assert exp == -self.scale

        coeff = 0
        for d in digits:
            coeff = coeff * 10 + d
        if sign:
            coeff = -coeff
        
        n_bytes = (coeff.bit_length() + 8) // 8
        return coeff.to_bytes(n_bytes, byteorder='big', signed=True)

    cdef decode_value(self, value):
        coeff = int.from_bytes(value, byteorder='big', signed=True)
        decimal_val = self.context.create_decimal(coeff)
        return decimal_val.scaleb(-self.scale, context=self.context)


        


cdef class UUIDType(LogicalType):
    logical_name = 'uuid'
    underlying_types = (StringType, )