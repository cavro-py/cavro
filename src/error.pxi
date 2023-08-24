
class CavroException(Exception):
    pass


class InvalidName(CavroException):
    pass


class DuplicateName(CavroException):
    pass


class InvalidHasher(CavroException):
    pass


class ExponentTooLarge(CavroException):
    pass


class CannotPromoteError(CavroException):
    def __init__(self, reader_type, writer_type, extra=None):
        self.reader_type = reader_type
        self.writer_type = writer_type
        msg = f"Cannot promote {reader_type} to {writer_type}"
        if extra:
            msg += ': ' + extra
        super().__init__(msg)


class InvalidValue(CavroException, ValueError):
    
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