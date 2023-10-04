import textwrap
import inspect

import avro_compat.avro.datafile
import avro_compat.avro.io
from avro_compat import avro as avro_compat

import avro_compat.fastavro as fastavro_compat


def adapt_compat(method):
    '''
    Slightly crazy function that gets a method's source code
    and replaces usages of a library with usages of the comparative
    avro-compat shim.
    '''
    remote_globals = inspect.getclosurevars(method).globals
    name = method.__name__
    adapted_name = f'{name}_compat'
    method_source = textwrap.dedent(inspect.getsource(method))
    adapted = (method_source
        .replace(f'{name}.', f'{name}_compat.')
        .replace(f'def {name}(', f'def {adapted_name}(')
    )
    locals = {}
    exec_globals = remote_globals.copy()
    exec_globals['avro_compat'] = avro_compat
    exec_globals['fastavro_compat'] = fastavro_compat
    exec(adapted, exec_globals, locals)
    return locals[adapted_name]
