import subprocess
import click
import random
from pathlib import Path

HERE = Path(__file__).parent
CAVRO = HERE.parent.absolute()


def get_sub_args(cpu):
    random.seed(cpu)
    args = []
    env = {}

    args.extend(['-S', f'cavro-{cpu}'])
    if use_mopt := random.random() <= 0.1:
        args.extend(['-L', '0'])

    if use_queue_cycling := random.random() <= 0.1:
        args.extend(['-Z'])
    if disable_trim := random.random() <= 0.5:
        env['AFL_DISABLE_TRIM'] = '1'
        
    p_mode = random.random()
    if p_mode < 0.4:
        args.extend(['-P', 'explore'])
    elif p_mode < 0.6:
        args.extend(['-P', 'exploit'])

    if random.random() >= 0.3:
        args.extend(['-a', 'binary'])    
    
    return args, env

    


@click.command()
@click.argument('mode', type=click.Choice(['M', 'S']))
@click.argument('cpu', type=click.INT, default=-1)
@click.option('--detach', '-d', is_flag=True, default=False)
def run(mode, cpu, detach):
    args = ['afl-fuzz', '-i', 'inputs-unique', '-o', 'output', '-t', '1000']
    env = {}
    if mode == 'M':
        args += ['-M', 'main']
        env['AFL_FINAL_SYNC'] = '1'
        cpu = 0
    elif mode == 'S':
        assert cpu >= 0, cpu
        sub_args, sub_env = get_sub_args(cpu)
        args.extend(sub_args)
        env.update(sub_env)

    args += ['./test']

    docker_args = ['docker', 'run', '-it', '--rm', '-v', f'{CAVRO}:/src']
    if detach:
        docker_args += ['-d']
    if cpu >= 0:
        docker_args += ['--cpuset-cpus', str(cpu)]
    for key, value in env.items():
        docker_args += ['-e', f'{key}={value}']
    docker_args += ['cavro-afl']
    docker_args += args
    
    print(docker_args)
    subprocess.call(docker_args)
    

    

if __name__ == "__main__":
    run()