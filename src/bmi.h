#include <stdint.h>
#include <x86intrin.h>

int _sw_count_pack_bits(uint32_t val) {
    size_t gap_pos = (__builtin_ctz((~val & 0x80808080u) | 0x80000000ul) + 1) / 8;
    return gap_pos + (gap_pos == 4 ? ((0x80000000ul & val) >> 31) : 0);
}

int _pdep_count_pack_bits(uint32_t val) {
    uint32_t bits = ~_pext_u32(val, 0x80808080u);
    return __builtin_ctz(bits) + 1;
}

int count_pack_bits_ull(uint64_t val) {
    size_t gap_pos = (__builtin_ctzll((~val & 0x8080808080808080ull) | 0x8000000000000000ull)+1) / 8;
    return gap_pos + (gap_pos == 8 ? ((0x8000000000000000ull & val) >> 63) : 0);
}

uint32_t _sw_pack_7_8u(uint32_t a, uint8_t n) {
    uint64_t mask = (1u << (n*4u) << (n*4u)) - 1u;
    uint64_t masked = a & (0x7f7f7f7fU & mask);
    return (masked & 0x7f)
           | ((masked & 0x7f00u) >> 1)
           | ((masked & 0x7f0000u) >> 2)
           | ((masked & 0x7f000000u) >> 3);
}

uint32_t _pdep_pack_7_8u(uint32_t a, uint8_t n){
    uint32_t mask = (1u << (n*4u) << (n*4u)) - 1u;
    uint32_t shift_mask = 0x7f7f7f7f & mask;
    return _pext_u32(a, shift_mask);
}

uint64_t _sw_pack_7_8ull(uint64_t a, uint8_t n) {
//uint64_t pack_7_8ull(uint64_t a, uint8_t n) {
    uint64_t mask = (1ull << (n*4u) << (n*4u)) - 1u;
    uint64_t masked = a & (0x7f7f7f7f7f7f7f7full & mask);
    return (masked & 0x7f)
           | ((masked & 0x7f00ull) >> 1)
           | ((masked & 0x7f0000ull) >> 2)
           | ((masked & 0x7f000000ull) >> 3)
           | ((masked & 0x7f00000000ull) >> 4)
           | ((masked & 0x7f0000000000ull) >> 5)
           | ((masked & 0x7f000000000000ull) >> 6)
           | ((masked & 0x7f00000000000000ull) >> 7);
}

uint64_t _pdep_pack_7_8ull(uint64_t a, uint8_t n){
    uint64_t mask = (1ull << (n*4u) << (n*4)) - 1u;
    uint64_t shift_mask = 0x7f7f7f7f7f7f7f7full & mask;
    return _pext_u64(a, shift_mask);
}

uint32_t(*pack_7_8u)(uint32_t, uint8_t);
uint64_t(*pack_7_8ull)(uint64_t, uint8_t);
int(*count_pack_bits)(uint32_t);

void bmi2_detect() {
    __builtin_cpu_init();
    if (__builtin_cpu_supports("bmi2")) {
        pack_7_8ull = _pdep_pack_7_8ull;
        pack_7_8u = _pdep_pack_7_8u;
        count_pack_bits = _pdep_count_pack_bits;
    } else {
        pack_7_8ull = _sw_pack_7_8ull;
        pack_7_8u = _sw_pack_7_8u;
        count_pack_bits = _sw_count_pack_bits;
    }
}

