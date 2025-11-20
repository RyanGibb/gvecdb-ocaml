@0xa1b2c3d4e5f67890;
# internal gvecdb wrapper schemas
# these wrap user-defined property schemas to add metadata

struct NodePropertyBlob {
  # Wrapper for node properties
  version @0 :UInt32;        # schema format version
  typeId @1 :UInt64;         # interned type name ID
  properties @2 :Data;       # user's CapnProto message as raw bytes
}

struct EdgePropertyBlob {
  # wrapper for edge properties
  version @0 :UInt32;        # schema format version
  typeId @1 :UInt64;         # interned type name ID
  src @2 :UInt64;            # source node ID
  dst @3 :UInt64;            # destination node ID
  properties @4 :Data;       # user's CapnProto message as raw bytes
}

