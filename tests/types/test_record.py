import cavro


def test_record_creation():
    schema = cavro.Schema({'type': 'record', 'name': 'A', 'fields': [
        {'name': 'a', 'type': 'int'}
    ]})

# TODO!
