
import cavro

def test_type_schema():
    schema = cavro.Schema('{"type": "int"}')
    assert schema.type.get_schema() == 'int'


def test_record_type_schema():
    schema = cavro.Schema({'type': 'record', 'name': 'A', 'fields': [
        {'name': 'a', 'type': 'int'},
        {'name': 'b', 'type': 'int', 'default': 123},
    ]})
    assert schema.type.get_schema() == {
        "type": "record", 
        "name": "A", 
        "fields": [
            {"name": "a", "type": "int"}, 
            {"name": "b", "type": "int", "default": 123}
        ]
    }

def test_recursion():
    schema = cavro.Schema({
        "type": "record",
        "name": "A",
        "fields": [
            {'name': 'a', 'type': 'A'},
        ]
    })
    assert schema.type.get_schema() == {
        "type": "record", 
        "name": "A", 
        "fields": [
            {"name": "a", "type": "A"}, 
        ]
    }


def test_deduplication():
    schema = cavro.Schema([
    {"type": "enum", "name": "A", "symbols": ["a", "b"]}, 
    {
        "type": "record",
        "name": "B",
        "fields": [
            {'name': 'x', 'type': 'A'},
            {'name': 'y', 'type': 'A'},
        ]
    }])
    rec_type = schema.type.union_types[1]
    assert rec_type.get_schema() == {
        "type": "record",
        "name": "B",
        "fields": [
            {"name": "x", "type": {"type": "enum", "name": "A", "symbols": ["a", "b"]}},
            {"name": "y", "type": "A"},
        ]
    }