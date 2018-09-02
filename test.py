import cavro

DEFN = '["int", "long"]'

def main():
    schema = cavro.Schema(DEFN, permissive=True)
    print(schema.binary_encode(2**20))
    print(schema.binary_encode(2**40))
    #print(schema.encode_to_str(2))


if __name__ == '__main__':
    main()