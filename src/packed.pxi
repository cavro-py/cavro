
cdef packed struct _u8_64:
    uint8_t v8
    uint8_t v7
    uint8_t v6
    uint8_t v5
    uint8_t v4
    uint8_t v3
    uint8_t v2
    uint8_t v1

cdef packed struct _u8_48:
    uint8_t v6
    uint8_t v5
    uint8_t v4
    uint8_t v3
    uint8_t v2
    uint8_t v1

cdef packed struct _u8_32:
    uint8_t v4
    uint8_t v3
    uint8_t v2
    uint8_t v1

cdef packed struct _u8_24:
    uint8_t v3
    uint8_t v2
    uint8_t v1

cdef packed struct _u8_16:
    uint8_t v2
    uint8_t v1

cdef packed struct _u16_64:
    uint16_t v4
    uint16_t v3
    uint16_t v2
    uint16_t v1

cdef packed struct _u16_48:
    uint8_t  v3
    uint16_t v2
    uint16_t v1

cdef packed struct _u16_32:
    uint16_t v2
    uint16_t v1

cdef packed struct _u16_24:
    uint8_t v2
    uint16_t v1

cdef union u24:
    _u16_24 u16
    _u8_24 u8

cdef packed struct _u24_64:
    uint16_t v3
    u24 v2
    u24 v1

cdef packed struct _u24_32:
    uint8_t v2
    u24 v1

cdef packed struct _u32_64:
    uint32_t v2
    uint32_t v1

cdef packed struct _u32_48:
    uint16_t v2
    uint32_t v1

cdef packed struct _u40_64:
    uint8_t v2
    uint32_t v1

cdef packed struct _u48_64:
    uint16_t v2
    uint32_t v1

cdef packed struct _u56_64:
    uint8_t v3
    uint16_t v2
    uint32_t v1

cdef union u64:
    uint64_t u64
    _u56_64 u56
    _u48_64 u48
    _u40_64 u40
    _u32_64 u32
    _u24_64 u24
    _u16_64 u16
    _u8_64 u8

cdef union u48:
    _u32_48 u32
    _u16_48 u16
    _u8_48 u8

cdef union u32:
    uint32_t u32
    _u24_32 u24
    _u16_32 u16
    _u8_32 u8

cdef union u16:
    uint16_t u16
    _u8_16 u8