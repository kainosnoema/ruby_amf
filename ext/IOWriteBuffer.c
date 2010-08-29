
#ifndef __RUBY_AMF_WRITE_IO__
#define __RUBY_AMF_WRITE_IO__

#include <ruby.h>
#include <stdint.h>
#include "IOByteOrder.h"
#include "IOWriteBuffer.h"
#include "AMFCache.h"

/**
 *    Write buffer
 */

#define INITIAL_BUFFER_SIZE 512;

inline buffer_t * buffer_new(void)
{
  buffer_t * buffer  = malloc(sizeof(buffer_t));
  buffer->allocated  = INITIAL_BUFFER_SIZE;
  buffer->buffer     = (u_char*)malloc( sizeof(u_char) * buffer->allocated );
  buffer->cursor     = buffer->buffer;
  
  buffer->amf_cache  = amf_cache_new();

  return buffer;
}

inline size_t buffer_size(buffer_t* buffer)
{
  return buffer->cursor - buffer->buffer;
}

inline int buffer_grow(buffer_t* buffer, u_int min_length)
{
  if (buffer->allocated >= min_length)
  {
    return 0;
  }
  
  while (buffer->allocated < min_length)
  {
    buffer->allocated *= 2;
  }

  u_char* old_buffer = buffer->buffer;
  buffer->buffer = (u_char*)realloc(buffer->buffer, sizeof(u_char) * buffer->allocated);
  if (buffer->buffer == NULL)
  {
      free(old_buffer);
      free(buffer);
      return 1;
  }
  return 0;
}

inline int buffer_check_space(buffer_t* buffer, u_int size) {
    if (buffer->allocated >= buffer_size(buffer) + size)
    {
        return 0;
    }
    return buffer_grow(buffer, buffer_size(buffer) + size);
}

inline int buffer_free(buffer_t* buffer) {
    if (buffer == NULL)
    {
        return 1;
    }
    amf_cache_free(buffer->amf_cache);
    free(buffer->buffer);
    free(buffer);
    return 0;
}

inline VALUE buffer_to_rstring(buffer_t* buffer)
{
  VALUE serialized = rb_str_new((char*)buffer->buffer, buffer_size(buffer));
  buffer_free(buffer);
  return serialized;
}

inline int write_bytes(buffer_t* buffer, const u_char * bytes, u_int size)
{
  if (buffer_check_space(buffer, size) != 0)
  {
      return 1;
  }
  memcpy(buffer->cursor, bytes, size);
  buffer->cursor += size;
  return 0;
}

inline void write_byte(buffer_t* buffer, const u_char * byte)
{
  write_bytes(buffer, byte, 1);
}

/**
 *    Binary helper functions
 */

inline void write_c_word8(buffer_t* buffer, uint8_t ival)
{
  write_byte(buffer, (u_char *)&ival);
}

inline void write_c_int8(buffer_t* buffer, int8_t ival)
{
  write_byte(buffer, (u_char *)&ival);
}

inline void write_c_word16_network(buffer_t* buffer, uint16_t ival)
{
  u_char * cval = (u_char *)&ival;
  if (IS_LITTLE_ENDIAN)
  {
    swap_bytes(cval, BYTELEN_2);
  }
  write_bytes(buffer, cval, BYTELEN_2);
}

inline void write_c_int16_network(buffer_t* buffer, int16_t ival)
{
  u_char * cval = (u_char *)&ival;
  if (IS_LITTLE_ENDIAN) {
    swap_bytes(cval, BYTELEN_2);
  }
  write_bytes(buffer, cval, BYTELEN_2);
}

inline void write_c_word32_network(buffer_t* buffer, uint32_t ival)
{
  u_char * cval = (u_char *)&ival;
  if (IS_LITTLE_ENDIAN)
  {
    swap_bytes(cval, BYTELEN_4);
  }
  write_bytes(buffer, cval, BYTELEN_4);
}

inline void write_c_double(buffer_t* buffer, double dval)
{
  u_char * cval = (u_char *)&dval;
  if (IS_LITTLE_ENDIAN)
  {
    swap_bytes(cval, BYTELEN_8);
  }
  write_bytes(buffer, cval, BYTELEN_8);
}

#endif
