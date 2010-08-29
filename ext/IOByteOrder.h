
#ifndef __RUBY_AMF_BYTEORDER__
#define __RUBY_AMF_BYTEORDER__

#include <stdint.h>

#define IS_LITTLE_ENDIAN (*(uint16_t *)"\0\xff" > 0x100)

enum BYTE_SIZES { 
  BYTELEN_2     = 2,
  BYTELEN_4     = 4,
  BYTELEN_8     = 8
};

static inline void swap_bytes(u_char* b, u_int len)
{
  int i = 0;
  int j = len-1;
  
  char tmp;
  while (i<j) {
    tmp = b[i];
    b[i] = b[j];
    b[j] = tmp;
    i++, j--;
  }
}

#endif