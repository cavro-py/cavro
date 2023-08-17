

cdef class LogicalType:
    logical_name = NotImplemented
    underlying_types = NotImplemented

    @classmethod
    def for_type(cls, underlying: AvroType):
        for underlying_type in cls.underlying_types:
            if isinstance(underlying, underlying_type):
                inst = cls._for_type(underlying)
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
    cdef readonly object size

    def __init__(self, precision, scale, size):
        self.precision = precision
        self.scale = scale
        self.scale_val = decimal.Decimal('1').scaleb(-scale)
        self.context = decimal.Context(prec=self.precision, clamp=1)
        self.size = size

    @classmethod
    def _for_type(cls, underlying: AvroType):
        meta = underlying.metadata
        precision = meta.get('precision')
        if precision is None:
            return 
        scale = meta.get('scale', 0)
        if not isinstance(scale, int):
            raise ValueError('scale must be an integer')
        
        size = None
        if isinstance(underlying, FixedType):
            size = underlying.size
            max_precision = math.floor(math.log10(2) * (8 * size - 1))
            if precision > max_precision: # Numbers may not fit into the fixed
                return None

        return cls(precision, scale, size)

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


        


cdef class UUIDStringType(LogicalType):
    logical_name = 'uuid'
    underlying_types = (StringType, )

    @classmethod
    def _for_type(cls, underlying: AvroType):
        return cls()

    cdef encode_value(self, value):
        if not isinstance(value, uuid.UUID):
            value = uuid.UUID(value)
        return str(value)

    cdef decode_value(self, value):
        return uuid.UUID(value)


cdef class UUIDFixedType(LogicalType):
    logical_name = 'uuid'
    underlying_types = (FixedType, )

    @classmethod
    def _for_type(cls, underlying: AvroType):
        if underlying.size != 16:
            return None
        return cls()

    cdef encode_value(self, value):
        if not isinstance(value, uuid.UUID):
            value = uuid.UUID(value)
        return value.bytes

    cdef decode_value(self, value):
        return uuid.UUID(bytes=value)