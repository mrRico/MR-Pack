#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

typedef enum {
	MP_RESERVED, // zero reserved
	MP_DIE,
	MP_STR 		= 0x10, //0b00010000,
	MP_UINT 	= 0x20, //0b00100000,
	MP_SINT 	= 0x30, //0b00110000,
	MP_DOUBLE 	= 0x40, //0b01000000,
	MP_UNDEF 	= 0x50, //0b01010000,
	MP_ARRAY 	= 0x60, //0b01100000,
	MP_HASH 	= 0x70, //0b01110000
} ber_context;

typedef struct {
    char * cur;
    const char * end;
    SV * sv;
    
    const char * inc;
    unsigned long icur;
    STRLEN ilen;
    
    unsigned int depth;
    unsigned int utf8;
} packBUF;

typedef packBUF *MR__Pack;

static inline void append_buf(packBUF* const self, const void* const buf, STRLEN const len) {
    if (self->cur + len >= self->end) {
        dTHX;
        STRLEN const cur = self->cur - SvPVX_const(self->sv);
        sv_grow (self->sv, cur + (len < (cur >> 2) ? cur >> 2 : len) + 1);
        self->cur = SvPVX_mutable(self->sv) + cur;
        self->end = SvPVX_const(self->sv) + SvLEN (self->sv) - 1;
    }

    memcpy(self->cur, buf, len);
    self->cur += len;
}

static inline void pack_llen(packBUF * self, ber_context context, unsigned long size) {
	unsigned char as_string[8];
	as_string[7] = context;
	signed char ind = 7;
	if (size) {
		as_string[7] |= size & 0xf;
		size >>= 4;
		
		while (size && ind > -1) {
			as_string[--ind] = 0x80 | size & 0x7f;
			size >>= 7;
		}
		
		if (size) {
			Perl_croak(aTHX_ "pack_llen overflow\n");
		}
		
	}
	append_buf(self, as_string+ind, 8-ind);
}

typedef union {
	const double as_int;
	const unsigned char as_string[8];
} doubleBUF;
static inline void pack_double(packBUF * self, double num) {
	doubleBUF u_double = {num};
	pack_llen(self, MP_DOUBLE, 0);
	append_buf(self, u_double.as_string, 8);
}

static inline void pack_undef(packBUF * self) {
	pack_llen(self, MP_UNDEF, 0);
}

static inline void pack_hash(packBUF * self, int len) {
	pack_llen(self, MP_HASH, len);
}

static inline void pack_array(packBUF * self, int len) {
	pack_llen(self, MP_ARRAY, len);
}

static inline void pack_string(packBUF * self, const char* const pv, STRLEN const len) {
	pack_llen(self, MP_STR, len);
	append_buf(self, pv, len);
}

static inline void pack_int(packBUF * self, ber_context context, unsigned long s_int) {
	pack_llen(self, context, s_int);
}

static inline void c_pack(packBUF * self, SV * sv, unsigned int depth) {
	if (!depth) Perl_croak(aTHX_ "depth is exhausted\n");
	SvGETMAGIC(sv);
    if (SvPOKp(sv)) {
        STRLEN const len     = SvCUR(sv);
        const char* const pv = SvPVX_const(sv);
        pack_string(self, pv, len);
    } else if (SvNOKp(sv)) {
    	pack_double(self, (double)SvNVX(sv));
    } else if (SvIOKp(sv)) {
    	if(SvUOK(sv)) {
    		pack_int(self, MP_UINT, (unsigned long) SvUVX(sv));
    	} else {
    		// signed long long at unpack
    		signed long ee = SvIVX(sv);
    		if (ee < 0) {
				pack_int(self, MP_SINT, (unsigned long) -ee);
    		} else {
    			pack_int(self, MP_UINT, (unsigned long) ee);
    		}
    	}
    } else if (SvROK(sv)) {
    	SV* rsv = SvRV(sv);
        SvGETMAGIC(rsv);
        svtype svt = SvTYPE(rsv);
        if (svt == SVt_PVHV) {
            HV* hval = (HV*)rsv;
            int count = hv_iterinit(hval);
        	if (SvTIED_mg(sv,PERL_MAGIC_tied)) {
        		Perl_croak(aTHX_ "MR::Pack for perl doesn't supported tie hash.\n");
			}
        	pack_hash(self, count);
            HE* he;
            while ((he = hv_iternext(hval))) {
            	c_pack(self, hv_iterkeysv(he), depth - 1);
            	c_pack(self, hv_iterval(hval, he), depth - 1);
            }
            
        } else if (svt == SVt_PVAV) {
            AV* ary = (AV*)rsv;
            int len = av_len(ary) + 1;
            pack_array(self, len);
            if (len) {
            	int i = 0;
				for (; i<len; i++) {
					SV** svp = av_fetch(ary, i, 0);
					if (svp) {
						c_pack(self, *svp, depth - 1);
					} else {
						pack_undef(self);
					}
				}
            }
        }
    } else if (!SvOK(sv)) {
    	pack_undef(self);
    } else if (isGV(sv)) {
        Perl_croak(aTHX_ "MR::Pack cannot pack the GV\n");
    } else {
        sv_dump(sv);
        Perl_croak(aTHX_ "MR::Pack for perl doesn't supported this type: %d\n", SvTYPE(sv));
    }
    
    return;
}

static inline ber_context unpack_llen(packBUF * self, unsigned long * size) {
	unsigned long long ext = 0;
	ber_context context;
	
	signed char i = 0;
	while (self->icur < self->ilen && i++ < 8) {
		unsigned char c = self->inc[self->icur++];
		if (c < 0x80) {
			i = -1;
			context = c & 0x70;
			ext <<= 4;
			ext |= c & 0xf;
			break;
		} else {
			ext <<= 7;
			ext |= c & 0x7f;
		}
	}
	if (i != -1) return MP_DIE;
	 
	*size = ext;
	return context; 
}

static inline SV* c_unpack(packBUF * self, unsigned int depth) {
	if (!depth) {
		self->inc = NULL;
		Perl_croak(aTHX_ "depth is exhausted\n");
	}
	SV* ret;
	
	unsigned long size;
	ber_context context = unpack_llen(self, &size);
	if (context == MP_DIE) {
		return NULL;
	} else if (context == MP_STR) {
		dTHX;
		if (size) {
			ret = newSV(size+1);
			char * cur = SvPVX(ret);
			char * end = SvEND(ret);
			SvPOK_only(ret);
		    memcpy(cur, self->inc + self->icur, size);
		    cur += size;
		    self->icur += size; 
		    SvCUR_set(ret, cur - SvPVX(ret));
		    *SvEND (ret) = 0;
		    if (self->utf8) SvUTF8_on(ret);
		} else {
			ret = newSVpvs("");
		}
	} else if (context == MP_UINT) {
		dTHX;
		ret = newSVuv(size);
	} else if (context == MP_SINT) {
		dTHX;
		ret = newSViv(-1*(signed long)size);
	} else if (context == MP_DOUBLE) {
		dTHX;
		doubleBUF u_double = {0};
		memcpy(&u_double.as_string, self->inc + self->icur, 8);
		self->icur += 8;
		ret = newSVnv(u_double.as_int);
	} else if (context == MP_UNDEF) {
		dTHX;
		ret = newSV(0);
	} else if (context == MP_ARRAY) {
		dTHX;
	    AV* const a = newAV();
	    ret = newRV_noinc((SV*)a);
	    av_extend(a, size + 1);
	    unsigned long n = 0;
		for (; n < size; n++) {
			SV * el = c_unpack(self, depth-1);
			if (el == NULL) return NULL;
			(void)av_store(a, AvFILLp(a) + 1, el);
		}
	} else if (context == MP_HASH) {
	    dTHX;
	    HV* const h = newHV();
	    hv_ksplit(h, size);
	    ret = newRV_noinc((SV*)h);
	    unsigned long n = 0;
		for (; n < size; n++) {
			SV * k = c_unpack(self, depth-1);
			if (k == NULL) return NULL;
			SV * v = c_unpack(self, depth-1);
			if (k == NULL) return NULL;
			(void)hv_store_ent(h, k, v, 0);
			SvREFCNT_dec(k);
		}
	}
		
	return ret;
}

MODULE = MR::Pack		PACKAGE = MR::Pack	PREFIX = mr_

MR::Pack
mr_new(clazz)
	char *clazz
	PREINIT:
		PERL_UNUSED_VAR(clazz);
		MR__Pack self;
	CODE:
		self = calloc(1, sizeof(packBUF));
		if (self == NULL) XSRETURN_UNDEF;
		self->depth = 512;
		RETVAL = self;
	OUTPUT:
		RETVAL

		
MR::Pack
mr_set_depth(self, depth)
	MR::Pack self
	unsigned int depth
	CODE:
		self->depth = depth;
		RETVAL = self;
	OUTPUT:
		RETVAL

unsigned int
mr_get_depth(self)
	MR::Pack self
	CODE:
		RETVAL = self->depth;
	OUTPUT:
		RETVAL

		
MR::Pack
mr_set_utf8(self, utf8)
	MR::Pack self
	unsigned int utf8
	CODE:
		self->utf8 = utf8;
		RETVAL = self;
	OUTPUT:
		RETVAL

unsigned int
mr_get_utf8(self)
	MR::Pack self
	CODE:
		RETVAL = self->utf8;
	OUTPUT:
		RETVAL
		
SV * 
mr_pack(self, ...)
	MR::Pack self
	PROTOTYPE: $@
	PPCODE:
		if (items == 0) XSRETURN_UNDEF;
		self->sv = sv_2mortal(newSV(32));
		self->cur = SvPVX(self->sv);
		self->end = SvEND(self->sv);
		SvPOK_only(self->sv);
		
		int i;
		for (i = 1; i < items; i++) {
			c_pack(self, (SV *)ST(i), self->depth);	
		}
		
	    SvCUR_set(self->sv, self->cur - SvPVX(self->sv));
	    *SvEND (self->sv) = 0;
		XPUSHs(self->sv);
	    self->cur = NULL;
	    self->end = NULL;
	    self->sv = NULL;

SV * 
mr_unpack(self, data)
	MR::Pack self
	SV* data
	PROTOTYPE: $$
	PPCODE:
		STRLEN dlen;
		const char* const inc = SvPV_const(data, dlen);
		if (dlen == 0) XSRETURN_UNDEF;
		self->inc = inc;
		self->ilen = dlen;
		self->icur = 0;
		while (self->icur < self->ilen) {
			SV* const obj = c_unpack(self, self->depth);
			if (obj == NULL) {
				self->inc = NULL;
				self->ilen = 0;
				self->icur = 0;
				Perl_croak(aTHX_ "MR::Pack cannot unpack this\n");
			} else {
				sv_2mortal(obj);
				XPUSHs(obj);
			}
		}
		self->inc = NULL;
		self->ilen = 0;
		self->icur = 0;
