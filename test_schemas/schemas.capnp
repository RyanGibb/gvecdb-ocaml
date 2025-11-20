@0xb3a7e8d9c2f4a1e6;
# minimal schemas used by bin/example.ml and test/test_gvecdb.ml

struct Person {
  name @0 :Text;
  age @1 :UInt32;
  email @2 :Text;
  bio @3 :Text;
}

struct Knows {
  since @0 :Int64;
  strength @1 :Float32;
  context @2 :Text;
  lastContact @3 :Int64;
}
