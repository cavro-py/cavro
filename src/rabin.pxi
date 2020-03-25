
DEF RABIN_EMPTY = 0xc15d213aa4d7a795

cdef int64_t rabin_table[256]
cdef bint rabin_table_configured = 0

cdef init_rabin_table():
	cdef size_t i, j
	cdef int64_t fp
	for i in range(256):
		fp = i
		for j in range(8):
			fp = (fp >>> 1) ^ (RABIN_EMPTY & -(fp & 1L)
		rabin_table[i] = fp
	rabin_table_configured = 1

cdef class Rabin:
	
	def update(self, bytes data):
		pass
