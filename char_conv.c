/*
    Copyright (C) 2009 - 2010
    Artem Makhutov <artem@makhutov.org>
    http://www.makhutov.org

    Dmitry Vagin <dmitry2004@yandex.ru>

    Copyright (C) 2010 - 2011
    bg <bg_one@mail.ru>

    Copyright (C) 2020 Max von Buelow <max@m9x.de>
*/
#include "ast_config.h"

#include <sys/types.h>

#include <iconv.h>			/* iconv_t iconv() */
#include <string.h>			/* memcpy() */
#include <stdio.h>			/* sscanf() snprintf() */
#include <errno.h>			/* EINVAL */

#include "char_conv.h"
#include "mutils.h"			/* ITEMS_OF() */
#include "gsm7_luts.h"

static const signed char lut_hex2val[] = {
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
	0, 1, 2, 3, 4, 5, 6, 7, 8, 9, -1, -1, -1, -1, -1, -1, 
	-1, 10, 11, 12, 13, 14, 15, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
	-1, 10, 11, 12, 13, 14, 15, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1
};
static const char *lut_val2hex = "0123456789ABCDEF";

static ssize_t convert_string(const char *in, size_t in_length, char *out, size_t out_size, char *from, char *to)
{
	ICONV_CONST char *in_ptr = (ICONV_CONST char*)in;
	size_t in_bytesleft = in_length;
	char *out_ptr = out;
	size_t out_bytesleft = out_size - 1;
	ICONV_T cd = (ICONV_T)-1;
	ssize_t res;

	cd = iconv_open(to, from);
	if (cd == (ICONV_T)-1) {
		return -1;
	}

	res = iconv(cd, &in_ptr, &in_bytesleft, &out_ptr, &out_bytesleft);
	if (res < 0) {
		iconv_close(cd);
		return -1;
	}

	iconv_close(cd);

	return out_ptr - out;
}

EXPORT_DEF ssize_t utf8_to_ucs2(const char *in, size_t in_length, uint16_t *out, size_t out_size)
{
	ssize_t res = convert_string(in, in_length, (char*)out, out_size * 2, "UTF-8", "UTF-16BE");
	if (res < 0) return res;
	return res / 2;
}
/*!
 * \brief Convert UTF-16BE (as received in SMS/USSD "UCS-2") to UTF-8.
 *
 * Unlike iconv this never fails on content: surrogate pairs (emoji etc.)
 * are combined, and unpaired surrogates -- typical when a long SMS is split
 * in the middle of an emoji and each part is decoded separately -- become
 * U+FFFD instead of discarding the whole message.
 *
 * \param in        UTF-16 code units stored big-endian (byte order of the PDU)
 * \param in_length number of 16-bit code units
 * \param out_size  size of out, one byte is kept for the terminating NUL
 * \return number of bytes written (without NUL), -1 if out is too small
 */
EXPORT_DEF ssize_t ucs2_to_utf8(const uint16_t *in, size_t in_length, char *out, size_t out_size)
{
	const uint8_t *b = (const uint8_t *)in;
	size_t o = 0;

	if (out_size == 0)
		return -1;

	for (size_t k = 0; k < in_length; ++k) {
		uint32_t cp = ((uint32_t)b[2 * k] << 8) | b[2 * k + 1];

		if (cp >= 0xD800 && cp <= 0xDBFF) {
			uint32_t lo = 0;
			if (k + 1 < in_length)
				lo = ((uint32_t)b[2 * k + 2] << 8) | b[2 * k + 3];
			if (lo >= 0xDC00 && lo <= 0xDFFF) {
				cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
				++k;
			} else {
				cp = 0xFFFD;
			}
		} else if (cp >= 0xDC00 && cp <= 0xDFFF) {
			cp = 0xFFFD;
		}

		if (cp < 0x80) {
			if (o + 1 > out_size - 1) return -1;
			out[o++] = (char)cp;
		} else if (cp < 0x800) {
			if (o + 2 > out_size - 1) return -1;
			out[o++] = (char)(0xC0 | (cp >> 6));
			out[o++] = (char)(0x80 | (cp & 0x3F));
		} else if (cp < 0x10000) {
			if (o + 3 > out_size - 1) return -1;
			out[o++] = (char)(0xE0 | (cp >> 12));
			out[o++] = (char)(0x80 | ((cp >> 6) & 0x3F));
			out[o++] = (char)(0x80 | (cp & 0x3F));
		} else {
			if (o + 4 > out_size - 1) return -1;
			out[o++] = (char)(0xF0 | (cp >> 18));
			out[o++] = (char)(0x80 | ((cp >> 12) & 0x3F));
			out[o++] = (char)(0x80 | ((cp >> 6) & 0x3F));
			out[o++] = (char)(0x80 | (cp & 0x3F));
		}
	}
	out[o] = '\0';
	return (ssize_t)o;
}


static signed char hexchar2val(unsigned char h)
{
	return lut_hex2val[h];
}
static char val2hexchar(unsigned char h)
{
	return lut_val2hex[h];
}
EXPORT_DEF int unhex(const char *in, uint8_t *out)
{
	int len = 0, nibbles = 0;
	while (in[0]) {
		nibbles += 1 + !!in[1];
		signed char p0 = hexchar2val(*in++);
		signed char p1 = *in ? hexchar2val(*in++) : 0;
		if (p0 == -1 || p1 == -1) {
			return -1;
		}
		out[len++] = p0 << 4 | p1;
	}
	return nibbles;
}
EXPORT_DEF void hexify(const uint8_t *in, size_t in_length, char *out)
{
	// code from end of string to allow in-place encoding
	for (int i = in_length - 1; i >= 0; --i) {
		char c0 = val2hexchar(in[i] >> 4), c1 = val2hexchar(in[i] & 15);
		out[i * 2] = c0;
		out[i * 2 + 1] = c1;
	}
	out[in_length * 2] = '\0';
}

#/* */
static const uint8_t *get_char_gsm7_encoding(uint16_t c)
{
#if __BYTE_ORDER == __BIG_ENDIAN
	int minor = c & 0xff;
	int major = c >> 8;
#else
	int minor = c >> 8;
	int major = c & 0xff;
#endif
	int subtab = LUT_GSM7_REV1[major];
	if (subtab == -1) return LUT_GSM7_REV2_INV;
	return LUT_GSM7_REV2[subtab][minor];
}

EXPORT_DEF ssize_t gsm7_encode(const uint16_t *in, size_t in_length, uint16_t *out)
{
	// TODO: Should we check for other tables or just use UCS-2?
	unsigned bytes = 0;
	const uint8_t *escenc = get_char_gsm7_encoding(0x1B00);
	for (unsigned i = 0; i < in_length; ++i) {
		const uint8_t *enc = get_char_gsm7_encoding(in[i]);
		uint8_t c = enc[0];
		if (c == GSM7_INVALID) {
			return -1;
		}
		if (c > 127) {
			bytes += 2;
			out[i] = (escenc[0] << 8) | (c - 128);
		} else {
			++bytes;
			out[i] = c;
		}
	}
	return bytes;
}
EXPORT_DEF ssize_t gsm7_pack(const uint16_t *in, size_t in_length, char *out, size_t out_size, unsigned out_padding)
{
	size_t i, x;
	unsigned value = 0;

	/* compute number of bytes we need for the final string, rounded up */
	x = ((out_padding + (7 * in_length) + 7) / 8) + 1;

	/* check that the buffer is not too small */
	if (x > out_size)
		return -1;

	for (x = i = 0; i != in_length; i++) {
		char c[] = { in[i] >> 8, in[i] & 255 };

		for (int j = c[0] == 0; j < 2; ++j) {
			value |= (c[j] & 0x7F) << out_padding;
			out_padding += 7;
			if (out_padding < 8)
				continue;
			/* output one byte */
			out[x++] = value & 0xff;
			value >>= 8;
			out_padding -= 8;
		}
	}
	if (out_padding != 0) {
		out[x++] = value & 0xff;
	}

	/* return total string length in nibbles, excluding terminating zero */
	return x * 2 - (out_padding == 1 || out_padding == 2 || out_padding == 3 ? 1 : 0);
}
EXPORT_DEF ssize_t gsm7_unpack_decode(const char *in, size_t in_nibbles, uint16_t *out, size_t out_size, unsigned in_padding, uint8_t ls, uint8_t ss)
{
	if (ls > 13) ls = 0;
	if (ss > 13) ss = 0;
	size_t i;
	size_t x;
	unsigned value = 0;
	unsigned c;

	if (out_size == 0) {
		return -1;
	}

	/* check if string is empty */
	if (in_nibbles < 2) {
		out[0] = '\0';
		return 0;
	}

	/* account for the bit padding */
	in_padding = 7 - in_padding;

	/* parse the hexstring */
	int esc = 0;
	for (x = i = 0; i < in_nibbles; ++i) {
		if (x >= out_size)
			return -1;
		c = in[i / 2];
		if (i & 1) c >>= 4;
		uint8_t n = c & 0xf;
		value |= n << in_padding;
		in_padding += 4;

		while (in_padding >= 7 * 2) {
			in_padding -= 7;
			value >>= 7;
			{
				uint16_t val = (esc ? LUT_GSM7_SS16 : LUT_GSM7_LS16)[esc ? ss : ls][value & 0x7f];
				if (val == 0x1b) {
					esc = 1;
				} else {
					esc = 0;
#if __BYTE_ORDER == __BIG_ENDIAN
					out[x++] = val;
#else
					out[x++] = ((val & 0xff) << 8) | (val >> 8);
#endif
				}
			}
		}
	}

	return x;
}
