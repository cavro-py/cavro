import cavro

if __name__ == '__main__':
    print("=================================")
    print("    Perf tests")
    print("=================================")
    for name, (fn, *spec) in cavro.__perf_tests.items():
        print(name)
        print("=================================")
        for i in range(3):
            fn(*spec)