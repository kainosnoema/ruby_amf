#ifndef __AMF_CONSTANTS__
#define __AMF_CONSTANTS__

enum AMF_TYPES {
  READ_TYPE_FROM_IO        = 0xff, // special

  // AMF0 type markers
  AMF0_NUMBER       = 0x00, // "\000"
  AMF0_BOOLEAN      = 0x01, // "\001"
  AMF0_STRING       = 0x02, // "\002"
  AMF0_OBJECT       = 0x03, // "\003"
  AMF0_MOVIE_CLIP   = 0x04, // "\004"
  AMF0_NULL         = 0x05, // "\005"
  AMF0_UNDEFINED    = 0x06, // "\006"
  AMF0_REFERENCE    = 0x07, // "\a"
  AMF0_HASH         = 0x08, // "\b"
  AMF0_OBJECT_END   = 0x09, // "\t"
  AMF0_STRICT_ARRAY = 0x0A, // "\n"
  AMF0_DATE         = 0x0B, // "\v"
  AMF0_LONG_STRING  = 0x0C, // "\f"
  AMF0_UNSUPPORTED  = 0x0D, // "\r"
  AMF0_RECORDSET    = 0x0E, // "\016"
  AMF0_XML          = 0x0F, // "\017"
  AMF0_TYPED_OBJECT = 0x10, // "\020"
  AMF0_AMF3_TYPE    = 0x11, // "\021"
  
  // AMF3 type markers
  AMF3_UNDEFINED    = 0x00, //"\000"
  AMF3_NULL         = 0x01, //"\001"
  AMF3_FALSE        = 0x02, //"\002"
  AMF3_TRUE         = 0x03, //"\003"
  AMF3_INTEGER      = 0x04, //"\004"
  AMF3_DOUBLE       = 0x05, //"\005"
  AMF3_STRING       = 0x06, //"\006"
  AMF3_XML_DOC      = 0x07, //"\a"
  AMF3_DATE         = 0x08, //"\b"
  AMF3_ARRAY        = 0x09, //"\t"
  AMF3_OBJECT       = 0x0A, //"\n"
  AMF3_XML          = 0x0B, //"\v"
  AMF3_BYTE_ARRAY   = 0x0C, //"\f"
  
  // Other AMF3 Markers
  AMF3_EMPTY_STRING         = 0x01, // "\001"
  AMF3_ANONYMOUS_OBJECT     = 0x01, // "\001"
  AMF3_DYNAMIC_OBJECT       = 0x0B, // "\v"
  AMF3_CLOSE_DYNAMIC_OBJECT = 0x01, // "\001"
  AMF3_CLOSE_DYNAMIC_ARRAY  = 0x01, // "\001"
  
  MAX_AMF3_INTEGER  = 268435455,
  MIN_AMF3_INTEGER  = -268435456
};

#endif