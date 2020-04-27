# cavro

An Avro serializer/deserializer for python written in cython.

# Functinoality

## Basic

-   [x] Parse Schema json
-   [x] Non-core attributes
-   [x] name resolution
-   [x] namespaced name resolution

## Basic schema support

-   [x] Null
-   [x] Union array
-   [x] boolean
-   [x] int
-   [x] long
-   [x] float
-   [x] double
-   [x] bytes
-   [x] string
-   [x] record
-   [x] fixed
-   [x] enum
-   [x] array
-   [x] map

## Value Reading (Binary encoding)

-   [x] Null
-   [x] bool
-   [x] int
-   [x] long
-   [x] float
-   [x] double
-   [x] bytes
-   [x] string
-   [x] record
-   [x] fixed
-   [x] enum
-   [x] array
-   [x] map

## Value Writing (Binary encoding)

-   [x] Null
-   [x] bool
-   [x] int
-   [x] long
-   [x] float
-   [x] double
-   [x] bytes
-   [x] string
-   [x] record
-   [x] fixed
-   [x] enum
-   [x] array
-   [x] map

## Value Reading (Json encoding)

-   [ ] Null
-   [ ] bool
-   [ ] int
-   [ ] long
-   [ ] float
-   [ ] double
-   [ ] bytes
-   [ ] string
-   [ ] record
-   [ ] fixed
-   [ ] enum
-   [ ] array
-   [ ] map

## Value Writing (Json encoding)

-   [ ] Null
-   [ ] bool
-   [ ] int
-   [ ] long
-   [ ] float
-   [ ] double
-   [ ] bytes
-   [ ] string
-   [ ] record
-   [ ] fixed
-   [ ] enum
-   [ ] array
-   [ ] map

## Schema Validation

-   [ ] Null
-   [ ] bool
-   [ ] int
-   [ ] long
-   [ ] float
-   [ ] double
-   [ ] bytes
-   [ ] string
-   [ ] record
-   [ ] fixed
-   [ ] enum
-   [ ] array
-   [ ] map

## Canonical form

-   [x] Null
-   [x] bool
-   [x] int
-   [x] long
-   [x] float
-   [x] double
-   [x] bytes
-   [x] string
-   [x] record
-   [x] fixed
-   [x] enum
-   [x] array
-   [x] map
-   [x] fingerprinting
-   [x] md5, sha256
-   [x] rabin

## Container format

-   [x] basic reading
-   [x] read schema
-   [x] read objects
-   [ ] Write container
-   [x] null schema
-   [ ] deflate support
-   [x] snappy support
-   [ ] Improved reader error handling
-   [ ] Snappy checksum validation

## Logical Types

-   [ ] Decimal
-   [ ] Date
-   [ ] Time (millis)
-   [ ] Time (micros)
-   [ ] Timestamp (millis)
-   [ ] Timestamp (micros)
-   [ ] Duration

## Other

-   [ ] writing array & maps by chunk
