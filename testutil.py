import re

def _str2chr(data):
    if len(data) == 2:
        return chr(int(data, 16))
    return data

def bytesx(val):
    lines = [line.split("//", 1)[0].strip() for line in val.splitlines()]
    compact = " " + " ".join(lines).strip()
    raw = re.sub(r"\s+([A-Fa-f\d]{2}|[^\s])", lambda m: _str2chr(m.group(1)), compact)
    return raw.encode('latin1')