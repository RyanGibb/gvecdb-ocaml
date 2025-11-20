(** Core type definitions for gvecdb *)

(** 64-bit IDs for nodes, edges, vectors, etc. *)
type id = int64

(** IDs for interned strings (node types, edge types, etc.) *)
type intern_id = int64

(** node ID *)
type node_id = id

(** edge ID *)
type edge_id = id

(** vector ID *)
type vector_id = id

(** edge information record *)
type edge_info = {
  id : edge_id;
  edge_type : string;
  src : node_id;
  dst : node_id;
}

(** database handle *)
type t = {
  env : Lmdb.Env.t;
  (* core indexes *)
  nodes : (string, string, [`Uni]) Lmdb.Map.t;              (* node_id -> node data blob *)
  edges : (string, string, [`Uni]) Lmdb.Map.t;              (* edge_id -> edge data blob *)
  outbound : (string, string, [`Uni]) Lmdb.Map.t;           (* (src, type, dst, edge_id) -> () *)
  inbound : (string, string, [`Uni]) Lmdb.Map.t;            (* (dst, type, src, edge_id) -> () *)
  
  (* string interning indexes *)
  intern_forward : (string, string, [`Uni]) Lmdb.Map.t;     (* string -> id *)
  intern_reverse : (string, string, [`Uni]) Lmdb.Map.t;     (* id -> string *)
  
  (* metadata *)
  metadata : (string, string, [`Uni]) Lmdb.Map.t;           (* metadata_key -> value *)
}

(** metadata keys for tracking database state *)
module Metadata = struct
  let version = "version"
  let next_node_id = "next_node_id"
  let next_edge_id = "next_edge_id"
  let next_intern_id = "next_intern_id"
  let next_vector_id = "next_vector_id"
end

(** current database version *)
let db_version = 1L

