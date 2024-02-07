cdef class ValueAdapter:

    """
    Abstract base class for any helper that affects how values are transformed prior to avro encoding/decoding.
    """


    cdef encode_value(self, value):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement encode_value")

    cdef decode_value(self, value):
        raise NotImplementedError(
            f"{type(self).__name__} does not implement decode_value")


cdef int twos_complement(int value, int bits):
    cdef int mask = (1 << bits) - 1
    value = (value ^ mask) + 1
    return value & mask


cdef class LogicalType(ValueAdapter):

    """
    Semi-abstract class for all logical types.
    
    Subclasses must be implemented as cython classes.
    """

    logical_name = NotImplemented
    underlying_types = NotImplemented

    @_class_inst_method
    def for_type(inst, cls, underlying: AvroType):
        cdef object ob = inst
        if inst is None:
            ob = cls

        for underlying_type in ob.underlying_types:
            if isinstance(underlying, underlying_type):
                inst = ob._for_type(underlying)
                if inst is not None:
                    return inst

import gzip
from io import BytesIO


cdef class GzipStringType(LogicalType):
    """Logical type for gzip-compressed string values"""
    logical_name = 'gzip-str'
    underlying_types = (BytesType, )

    @classmethod
    def _for_type(cls, underlying: AvroType):
        # Only apply this logical type to bytes type
        return cls() if isinstance(underlying, BytesType) else None

    cdef encode_value(self, value):
        if not isinstance(value, str):
            raise TypeError(f"Value to encode should be a string, got {type(value)}")
        with BytesIO() as bytes_io:
            with gzip.GzipFile(fileobj=bytes_io, mode='wb') as gzip_file:
                gzip_file.write(value.encode('utf-8'))
            return bytes_io.getvalue()

    cdef decode_value(self, value):
        with BytesIO(value) as bytes_io:
            with gzip.GzipFile(fileobj=bytes_io, mode='rb') as gzip_file:
                return gzip_file.read().decode('utf-8')


cdef class CustomLogicalType(LogicalType):

    """
    Logical type that allows custom encoding/decoding functions to be provided.
    
    To use a custom logical type, subclass this class, and implement the:
     * `encode_value(value: object) -> object` - Transforms a provided value into something that can be encoded by the underlying type.
     * `decode_value(value: object) -> object` - Transforms a value decoded by the underlying type into a value to return to the user.
    methods.

    Also implement two class attributes, and a classmethod:
     * `logical_name` - The name to look for in the schema
     * `underlying_types` A tuple of `AvtoType` classes that this logical type can be applied to.
     * `_for_type(cls, underlying: AvroType) -> Cls` 
        A classmethod that returns an instance of the class, optionally customized with information from the underlying type,
        or None if the logical type is not applicable to the underlying type.
    """

    cdef encode_value(self, value):
        return self.custom_encode_value(value)

    cdef decode_value(self, value):
        return self.custom_decode_value(value)


cdef class DecimalType(LogicalType):
    """Logical type for decimal values."""

    logical_name = 'decimal'
    underlying_types = (BytesType, FixedType)

    cdef readonly int precision
    cdef readonly int scale
    cdef readonly object scale_val
    cdef readonly object context
    cdef readonly object size
    cdef str underlying_name

    cdef readonly bint check_exp_overflow

    def __init__(self, precision, scale, size, check_exp_overflow, underlying_name):
        self.precision = precision
        self.scale = scale
        self.scale_val = decimal.Decimal('1').scaleb(-scale)
        self.context = decimal.Context(prec=self.precision, clamp=1)
        self.size = size
        self.check_exp_overflow = check_exp_overflow
        self.underlying_name = underlying_name

    @property
    def type_name(self):
        return f'{self.underlying_name}(decimal)'

    @classmethod
    def _for_type(cls, underlying: AvroType):
        meta = underlying.metadata
        precision = meta.get('precision')
        if precision is None:
            return
        if not isinstance(precision, int) or precision < 1 or precision > decimal.MAX_PREC:
            if underlying.options.raise_on_invalid_logical:
                raise ValueError(f'Precision must be an integer between 1 and {decimal.MAX_PREC}, got: {repr(precision)}')
            return
        scale = meta.get('scale', 0)
        if not isinstance(scale, int) or scale < 0:
            if underlying.options.raise_on_invalid_logical:
                raise ValueError(f'Scale must be a positive integer, got: {repr(scale)}')
            return
        
        if scale > precision:
            if underlying.options.raise_on_invalid_logical:
                raise ValueError(f'Precision must be greater than scale. scale: {scale}, precision: {precision}')
            return
        
        size = None
        if isinstance(underlying, FixedType):
            size = underlying.size
            max_precision = math.floor(math.log10(2) * (8 * size - 1))
            if precision > max_precision: # Numbers may not fit into the fixed
                if underlying.options.raise_on_invalid_logical:
                    raise ValueError(f'Precision is too large for fixed size {size}. Precision: {precision}, Max precision is {max_precision}')
                return None

        return cls(precision, scale, size, underlying.options.decimal_check_exp_overflow, underlying.type_name)

    cdef encode_value(self, value):
        if isinstance(value, bytes):
            return value
        if not isinstance(value, decimal.Decimal):
            value = decimal.Decimal(value)
        
        if self.check_exp_overflow:
            _, _, orig_exp = value.as_tuple()
            if orig_exp < -self.scale:
                raise ExponentTooLarge(f"Decimal value {value} has exponent {orig_exp} which is greater than the scale {self.scale}")
        
        quant = value.quantize(self.scale_val, context=self.context)
        
        sign, digits, exp = quant.as_tuple()
        assert exp == -self.scale

        coeff = 0
        for d in digits:
            coeff = coeff * 10 + d
        if sign:
            coeff = -coeff
        
        if self.size is not None:
            return coeff.to_bytes(self.size, byteorder='big', signed=True)
        else:
            n_bytes = (coeff.bit_length() + 8) // 8
            return coeff.to_bytes(n_bytes, byteorder='big', signed=True)

    cdef decode_value(self, value):
        coeff = int.from_bytes(value, byteorder='big', signed=True)
        decimal_val = self.context.create_decimal(coeff)
        return decimal_val.scaleb(-self.scale, context=self.context)

      

cdef class UUIDBase(LogicalType):
    """Logical type for UUID values"""
    logical_name = 'uuid'
    cdef bint return_uuid_object

    def __init__(self, return_uuid_object):
        self.return_uuid_object = return_uuid_object

    @classmethod
    def _for_type(cls, underlying: AvroType):
        return cls(underlying.options.return_uuid_object)


cdef class UUIDStringType(UUIDBase):
    underlying_types = (StringType, )

    @classmethod
    def _for_type(cls, underlying: AvroType):
        return cls(underlying.options.return_uuid_object)

    @property
    def type_name(self):
        return 'string(uuid)'

    cdef encode_value(self, value):
        # apache avro lib behaviour is weird here, 
        # value should be validated, but unmodified value should
        # be encoded (i.e. the presence of '-' or not should be retained)
        if isinstance(value, uuid.UUID):
            return str(value)
        try:
            _ = uuid.UUID(hex=value)
        except TypeError as e:
            raise InvalidValue(value, self) from e
        return value

    cdef decode_value(self, value):
        if self.return_uuid_object:
            return uuid.UUID(value)
        return value
        

cdef class UUIDFixedType(UUIDBase):
    underlying_types = (FixedType, )

    @classmethod
    def _for_type(cls, underlying: AvroType):
        if underlying.size != 16:
            return None
        return cls(underlying.options.return_uuid_object)

    @property
    def type_name(self):
        return 'fixed(uuid)'

    cdef encode_value(self, value):
        if not isinstance(value, uuid.UUID):
            value = uuid.UUID(value)
        return value.bytes

    cdef decode_value(self, value):
        if self.return_uuid_object:
            return uuid.UUID(bytes=value)
        return value


EPOCH_DATE = datetime.date(1970, 1, 1)
EPOCH_DT = datetime.datetime(1970, 1, 1, tzinfo=datetime.timezone.utc)
EPOCH_DT_NO_TZ = datetime.datetime(1970, 1, 1)

cdef class Date(LogicalType):
    """Logical type for Date values"""
    logical_name = 'date'
    underlying_types = (IntType, )

    cdef readonly bint accepts_string

    def __init__(self, accepts_string):
        self.accepts_string = accepts_string

    @classmethod
    def _for_type(cls, underlying: AvroType):
        return cls(underlying.options.date_type_accepts_string)

    @property
    def type_name(self):
        return 'int(date)'

    cdef encode_value(self, value):
        if self.accepts_string and isinstance(value, str):
            value = datetime.datetime.strptime(value, '%Y-%m-%d').date()
        if isinstance(value, int) and value >= 0 and value <= 2**16:
            return value
        if isinstance(value, datetime.datetime):
            value = value.date()
        if isinstance(value, datetime.date):
            return (value - EPOCH_DATE).days
        raise ValueError(f"Expected datetime.date, got {type(value)}")

    cdef decode_value(self, value):
        return EPOCH_DATE + datetime.timedelta(days=value)


def _time_to_micros(value):
    return value.microsecond + 1_000_000 * (value.second + 60 * (value.minute + 60 * value.hour))


def _micros_to_time(value):
    return datetime.time(
        hour=value // 3_600_000_000,
        minute=(value // 60_000_000) % 60,
        second=(value // 1_000_000) % 60,
        microsecond=value % 100_0000
    )


MAX_TIME = _time_to_micros(datetime.time.max)


cdef object dt_to_timedelta(value):
    if value.tzinfo is None:
        value = value.astimezone(datetime.timezone.utc)
    return value - EPOCH_DT


cdef class TimeMillis(LogicalType):
    """Logical type for time-millis values"""
    logical_name = 'time-millis'
    underlying_types = (IntType, )

    @classmethod
    def _for_type(cls, underlying: AvroType):
        return cls()

    @property
    def type_name(self):
        return 'int(time-millis)'

    cdef encode_value(self, value):
        if isinstance(value, int) and value >= 0 and value <= (MAX_TIME // 1_000):
            return value
        if isinstance(value, datetime.datetime):
            value = value.time()
        return _time_to_micros(value) // 1_000

    cdef decode_value(self, value):
        return _micros_to_time(value * 1_000)


cdef class TimeMicros(LogicalType):
    """Logical type for time-micros values"""
    logical_name = 'time-micros'
    underlying_types = (LongType, )

    @classmethod
    def _for_type(cls, underlying: AvroType):
        return cls()

    @property
    def type_name(self):
        return 'long(time-micros)'

    cdef encode_value(self, value):
        if isinstance(value, int) and value >= 0 and value <= MAX_TIME:
            return value
        if isinstance(value, datetime.datetime):
            value = value.time()
        return _time_to_micros(value)

    cdef decode_value(self, value):
        return _micros_to_time(value)


cdef class TimestampMillis(LogicalType):
    """Logical type for timestamp-micros values"""
    logical_name = 'timestamp-millis'
    underlying_types = (LongType, )

    cdef readonly bint alternate_timestamp_encoding

    def __init__(self, alternate_timestamp_encoding):
        self.alternate_timestamp_encoding = alternate_timestamp_encoding

    @classmethod
    def _for_type(cls, underlying: AvroType):
        return cls(
            underlying.options.alternate_timestamp_millis_encoding,
        )

    @property
    def type_name(self):
        return 'long(timestamp-millis)'

    cdef encode_value(self, value):
        if isinstance(value, int):
            return value
        if not isinstance(value, datetime.datetime):
            raise ValueError(f"Expected datetime.datetime, got {type(value)}")
        if self.alternate_timestamp_encoding:
            delta = dt_to_timedelta(value)
            return (delta.microseconds // 1_000) + (delta.seconds + delta.days * 24 * 3600) * 1_000
        else:
            return int(value.timestamp() * 1_000)

    cdef decode_value(self, value):
        return EPOCH_DT + datetime.timedelta(microseconds=value * 1_000)


cdef class TimestampMicros(LogicalType):
    """Logical type for timestamp-micros values"""
    logical_name = 'timestamp-micros'
    underlying_types = (LongType, )

    @classmethod
    def _for_type(cls, underlying: AvroType):
        return cls()

    @property
    def type_name(self):
        return 'long(timestamp-micros)'

    cdef encode_value(self, value):
        if isinstance(value, int):
            return value
        if not isinstance(value, datetime.datetime):
            raise ValueError(f"Expected datetime.datetime, got {type(value)}")
        delta = dt_to_timedelta(value)
        return delta.microseconds + (delta.seconds + delta.days * 24 * 3600) * 1_000_000

    cdef decode_value(self, value):
        return EPOCH_DT + datetime.timedelta(microseconds=value)
