(** key encoding/decoding helpers for LMDB indexes *)

open Types

(** convert int64 to big-endian 8-byte string *)
let encode_id (id : int64) : string =
  let buf = Bytes.create 8 in
  Bytes.set_int64_be buf 0 id;
  Bytes.to_string buf

(** convert big-endian 8-byte string to int64 *)
let decode_id (s : string) : int64 =
  let buf = Bytes.of_string s in
  Bytes.get_int64_be buf 0

(** encode adjacency key for outbound/inbound indexes
    format: (src_or_dst_id, intern_id, opposite_id, edge_id) -> 32 bytes *)
let encode_adjacency ~node_id ~intern_id ~opposite_id ~edge_id : string =
  let buf = Bytes.create 32 in
  Bytes.set_int64_be buf 0 node_id;
  Bytes.set_int64_be buf 8 intern_id;
  Bytes.set_int64_be buf 16 opposite_id;
  Bytes.set_int64_be buf 24 edge_id;
  Bytes.to_string buf

(** decode adjacency key *)
let decode_adjacency (s : string) : node_id * intern_id * node_id * edge_id =
  let buf = Bytes.of_string s in
  let node_id = Bytes.get_int64_be buf 0 in
  let intern_id = Bytes.get_int64_be buf 8 in
  let opposite_id = Bytes.get_int64_be buf 16 in
  let edge_id = Bytes.get_int64_be buf 24 in
  (node_id, intern_id, opposite_id, edge_id)

(** encode prefix for adjacency range queries
    can query by just node_id, or node_id + intern_id, etc *)
let encode_adjacency_prefix ?node_id ?intern_id ?opposite_id () : string =
  match node_id, intern_id, opposite_id with
  | None, _, _ -> ""
  | Some nid, None, _ -> encode_id nid
  | Some nid, Some tid, None ->
      let buf = Bytes.create 16 in
      Bytes.set_int64_be buf 0 nid;
      Bytes.set_int64_be buf 8 tid;
      Bytes.to_string buf
  | Some nid, Some tid, Some oid ->
      let buf = Bytes.create 24 in
      Bytes.set_int64_be buf 0 nid;
      Bytes.set_int64_be buf 8 tid;
      Bytes.set_int64_be buf 16 oid;
      Bytes.to_string buf

