(** main API for gvecdb *)

(** {1 core types} *)

(** 64-bit IDs for nodes, edges, vectors, etc *)
type id = int64

(** IDs for interned strings (node types, edge types, etc) *)
type intern_id = int64

(** node ID *)
type node_id = id

(** edge ID *)
type edge_id = id

(** vector ID *)
type vector_id = id

(** node information record *)
type node_info = {
  id : node_id;
  node_type : string;
}

(** edge information record *)
type edge_info = {
  id : edge_id;
  edge_type : string;
  src : node_id;
  dst : node_id;
}

(** database handle *)
type t

(** {1 database lifecycle} *)

(** [create path] creates or opens a gvecdb database at [path]
    
    @param path path to the database file
    @return database handle
*)
val create : string -> t

(** [close db] closes the database and releases all resources.
    
    The database handle should not be used after closing.
*)
val close : t -> unit

(** {1 nodes} *)

(** [create_node db node_type] creates a new node of the given type.
    
    @param node_type string name of the node type (e.g. "person", "document")
    @return the newly assigned node id
*)
val create_node : t -> string -> node_id

(** [node_exists db node_id] checks if a node exists *)
val node_exists : t -> node_id -> bool

(** [get_node_info db node_id] looks up node information by node id
    
    @return [Some node_info] if found, [None] if node doesn't exist
*)
val get_node_info : t -> node_id -> node_info option

(** [delete_node db node_id] deletes a node from the database.
    
    note: does not delete connected edges. delete edges first if needed.
*)
val delete_node : t -> node_id -> unit

(** {1 edges} *)

(** [create_edge db edge_type src dst] creates a directed edge from [src] to [dst].
    
    updates both outbound and inbound adjacency indexes.
    
    @param edge_type string name of the edge type (e.g. "knows", "follows_from")
    @return the newly assigned edge id
*)
val create_edge : t -> string -> node_id -> node_id -> edge_id

(** [edge_exists db edge_id] checks if an edge exists *)
val edge_exists : t -> edge_id -> bool

(** [delete_edge db edge_id] deletes an edge and cleans up adjacency indexes *)
val delete_edge : t -> edge_id -> unit

(** {1 adjacency queries} *)

(** [get_outbound_edges db node_id] returns all outbound edges from a node *)
val get_outbound_edges : t -> node_id -> edge_info list

(** [get_inbound_edges db node_id] returns all inbound edges to a node *)
val get_inbound_edges : t -> node_id -> edge_info list

(** [get_outbound_edges_by_type db node_id edge_type] returns outbound edges of a specific type
    
    @param edge_type string name of the edge type to filter by
*)
val get_outbound_edges_by_type : t -> node_id -> string -> edge_info list

(** [get_inbound_edges_by_type db node_id edge_type] returns inbound edges of a specific type
    
    @param edge_type string name of the edge type to filter by
*)
val get_inbound_edges_by_type : t -> node_id -> string -> edge_info list

(** [get_edge_info db edge_id] looks up edge information by edge id
    
    @return [Some edge_info] if found, [None] if edge doesn't exist
*)
val get_edge_info : t -> edge_id -> edge_info option

(** {1 property schemas with capnproto} *)

(** [register_node_schema_capnp db type_name schema_id] registers a node schema.
    
    stores metadata for validation. schema_id comes from capnproto-generated code.
    
    Example:
    {[
      register_node_schema_capnp db "person" 0xd8e6e025e7838111L
    ]}
*)
val register_node_schema_capnp : t -> string -> int64 -> unit

(** [register_edge_schema_capnp db type_name schema_id] registers an edge schema *)
val register_edge_schema_capnp : t -> string -> int64 -> unit

(** {1 node properties with capnproto builder/reader} *)

(** [set_node_props_capnp db node_id type_name build_fn init_root to_message] 
    sets properties using capnproto builder api.
    
    Example:
    {[
      set_node_props_capnp db alice "person"
        (fun builder ->
          Person.Builder.name_set builder "Alice";
          Person.Builder.age_set_int_exn builder 30)
        Person.Builder.init_root
        Person.Builder.to_message
    ]}
*)
val set_node_props_capnp : 
  t -> node_id -> string -> 
  ('builder -> unit) -> 
  (unit -> 'builder) -> 
  ('builder -> 'a Capnp.BytesMessage.Message.t) -> 
  unit

(** [get_node_props_capnp db node_id type_name of_message read_fn]
    gets properties using capnproto reader api with zero-copy from lmdb.
    
    Example:
    {[
      let name = get_node_props_capnp db alice "person"
        Person.Reader.of_message
        Person.Reader.name_get
    ]}
*)
val get_node_props_capnp :
  t -> node_id -> string ->
  (Capnp.Message.ro Capnp.BytesMessage.Message.t -> 'reader) ->
  ('reader -> 'result) ->
  'result

(** {1 edge properties with capnproto builder/reader} *)

(** [set_edge_props_capnp] sets edge properties using builder api *)
val set_edge_props_capnp :
  t -> edge_id -> string ->
  ('builder -> unit) ->
  (unit -> 'builder) ->
  ('builder -> 'a Capnp.BytesMessage.Message.t) ->
  unit

(** [get_edge_props_capnp] gets edge properties using reader api with zero-copy from lmdb *)
val get_edge_props_capnp :
  t -> edge_id -> string ->
  (Capnp.Message.ro Capnp.BytesMessage.Message.t -> 'reader) ->
  ('reader -> 'result) ->
  'result

