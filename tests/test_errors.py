import cavro
import pytest

def test_nested_value_error():
    schema = cavro.Schema(
        {"type": "record", "name": "A", "fields": [
            {"name": "a", "type": {
                "type": "map", "values": {
                    "type": "array", "items": {
                        "type": "record", "name": "B", "fields": [
                            {"name": "b", "type": "int"},
                        ]
                    }
                }
            }}
        ]}
    )
    with pytest.raises(cavro.InvalidValue) as exc:
        schema.binary_encode({"a": {"x": [{"b": '1'}]}})
    assert exc.value.schema_path == ('a', 'x', 0, 'b')