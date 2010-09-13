
#ifndef __RUBY_AMF_READ_IO__
#define __RUBY_AMF_READ_IO__

#include <ruby.h>
#include <stdint.h>
#include "IOByteOrder.h"
#include "IOReadBuffer.h"
#include "AMFCache.h"

/**
 *    Read buffer
 */

inline load_context_t * context_new(VALUE string)
{
  load_context_t * context  = malloc(sizeof(load_context_t));
  context->buffer           = (u_char*)RSTRING_PTR(string);
  context->cursor           = context->buffer;
  context->buffer_end       = context->buffer + RSTRING_LEN(string);

  context->amf_cache        = amf_cache_new();

  return context;
}

inline int context_free(load_context_t* context) {
    if (context == NULL) {
        return 1;
    }
    amf_cache_free(context->amf_cache);
    free(context);
    return 0;
}

inline void check_for_eof(load_context_t* context, uint32_t len)
{
  if ((context->cursor + len) > context->buffer_end)
  {
    rb_raise(rb_eRuntimeError, "unexpected end of buffer!");
  }
}

inline u_char* read_bytes(load_context_t* context, uint32_t len)
{
  check_for_eof(context, len); // raises eof error
  u_char* buffer = context->cursor;
  context->cursor += len;
  return buffer;
}

inline u_char read_byte(load_context_t* context)
{
  check_for_eof(context, 1); // raises eof error
  u_char c = context->cursor[0];
  context->cursor++;
  return c;
}

inline u_char peek_byte(load_context_t* context)
{
  check_for_eof(context, 1); // raises eof error
  u_char c = context->cursor[0];
  return c;
}


/**
 *    Basic IO operations
 */

inline uint8_t c_read_word8(load_context_t* context)
{
  return (uint8_t)read_byte(context);
}

inline int8_t c_read_int8(load_context_t* context)
{
  return (int8_t)read_byte(context);
}

inline uint16_t c_read_word16_network(load_context_t* context)
{
  uint16_t ival;
  memcpy(&ival, read_bytes(context, BYTELEN_2), BYTELEN_2);
  if (IS_LITTLE_ENDIAN)
  {
    swap_bytes((u_char *)&ival, BYTELEN_2);
  }
  return ival;
}

inline int16_t c_read_int16_network(load_context_t* context)
{
  int16_t ival;
  memcpy(&ival, read_bytes(context, BYTELEN_2), BYTELEN_2);
  if (IS_LITTLE_ENDIAN)
  {
    swap_bytes((u_char *)&ival, BYTELEN_2);
  }
  return ival;
}

inline uint32_t c_read_word32_network(load_context_t* context)
{
  uint32_t ival;
  memcpy(&ival, read_bytes(context, BYTELEN_4), BYTELEN_4);
  if (IS_LITTLE_ENDIAN)
  {
    swap_bytes((u_char *)&ival, BYTELEN_4);
  }
  return ival;
}

inline double c_read_double(load_context_t* context)
{
  double dval;
  memcpy(&dval, read_bytes(context, BYTELEN_8), BYTELEN_8);
  if (IS_LITTLE_ENDIAN)
  {
    swap_bytes((u_char *)&dval, BYTELEN_8);
  }
  return dval;
}


#endif
