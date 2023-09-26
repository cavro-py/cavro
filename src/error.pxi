
class CavroException(Exception):
    """
    Base class for exceptions raised by cavro
    """


class InvalidName(CavroException):
    """
    The schema contains a type or enum symbol with an invalid name (as per the avro specification)
    """


class UnknownType(CavroException):

    """
    The schema contains an unexptected type name (either a missing named-type definition, or invalid primitive type)
    """

    def __init__(self, name):
        self.name = name
        super().__init__(f"Unknown type: {name}")


class DuplicateName(CavroException):
    """
    A record contains multiple fields with the same name, a schema contains multiple types of the same name, or an enum has multiple identical symbols.
    """


class InvalidHasher(CavroException):
    """
    An unknown hash method was requested
    """


class ExponentTooLarge(CavroException):
    """
    The exponent of a decimal value is too large to be represented in the given type
    """
    


class CodecUnavailable(CavroException):
    """
    A requested codec (or codec in a container) is not available or is unknown.
    """


class CannotPromoteError(CavroException):

    """
    A schema cannot be promoted to another schema. (reader/writer schema promotion)

    Attributes:
     * `reader_type`: The schema type of the reader
     * `writer_type`: The schema type of the writer
     * `extra`: An optional extra message
    """

    def __init__(self, reader_type, writer_type, extra=None):
        self.reader_type = reader_type
        self.writer_type = writer_type
        self.extra = extra
        msg = f"Cannot promote {reader_type.get_schema()} to {writer_type.get_schema()}"
        if extra:
            msg += ': ' + extra
        super().__init__(msg)


class InvalidValue(CavroException, ValueError):

    """
    A value is invalid for a given avro type.
        
    Attributes:
     * `value`: The value that caused the error
     * `dest_type`: The schema type that the value was being converted to
     * `schema_path`: A sequence of identifiers (field names etc) to help locate the value that caused the error
    """
    
    def __init__(self, value, dest_type, path=()):
        self.value = value
        self.dest_type = dest_type
        self.schema_path = path
        super().__init__()

    def __str__(self):
        if self.schema_path:
            path_str = ".".join(str(p) for p in self.schema_path)
            return f"Invalid value {repr(self.value)} for type {self.dest_type.type_name} at {path_str}"
        return f"Invalid value {repr(self.value)} for type {self.dest_type.type_name}"