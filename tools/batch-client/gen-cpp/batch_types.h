/**
 * Autogenerated by Thrift Compiler (0.9.0)
 *
 * DO NOT EDIT UNLESS YOU ARE SURE THAT YOU KNOW WHAT YOU ARE DOING
 *  @generated
 */
#ifndef batch_TYPES_H
#define batch_TYPES_H

#include <thrift/Thrift.h>
#include <thrift/TApplicationException.h>
#include <thrift/protocol/TProtocol.h>
#include <thrift/transport/TTransport.h>

#include "attrs_types.h"
#include "defs_types.h"
#include "graph_types.h"
#include "libs_types.h"
#include "types_types.h"


namespace flowbox { namespace batch {

typedef struct _MissingFieldsException__isset {
  _MissingFieldsException__isset() : message(false) {}
  bool message;
} _MissingFieldsException__isset;

class MissingFieldsException : public ::apache::thrift::TException {
 public:

  static const char* ascii_fingerprint; // = "66E694018C17E5B65A59AE8F55CCA3CD";
  static const uint8_t binary_fingerprint[16]; // = {0x66,0xE6,0x94,0x01,0x8C,0x17,0xE5,0xB6,0x5A,0x59,0xAE,0x8F,0x55,0xCC,0xA3,0xCD};

  MissingFieldsException() : message() {
  }

  virtual ~MissingFieldsException() throw() {}

  std::string message;

  _MissingFieldsException__isset __isset;

  void __set_message(const std::string& val) {
    message = val;
    __isset.message = true;
  }

  bool operator == (const MissingFieldsException & rhs) const
  {
    if (__isset.message != rhs.__isset.message)
      return false;
    else if (__isset.message && !(message == rhs.message))
      return false;
    return true;
  }
  bool operator != (const MissingFieldsException &rhs) const {
    return !(*this == rhs);
  }

  bool operator < (const MissingFieldsException & ) const;

  uint32_t read(::apache::thrift::protocol::TProtocol* iprot);
  uint32_t write(::apache::thrift::protocol::TProtocol* oprot) const;

};

void swap(MissingFieldsException &a, MissingFieldsException &b);

}} // namespace

#endif
