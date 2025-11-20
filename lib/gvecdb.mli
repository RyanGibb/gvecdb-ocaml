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
    @return the newly assigned node ID
*)
val create_node : t -> string -> node_id

(** [node_exists db node_id] checks if a node exists.
*)
val node_exists : t -> node_id -> bool

(** {1 edges} *)

(** [create_edge db edge_type src dst] creates a directed edge from [src] to [dst].
    
    updates both outbound and inbound adjacency indexes.
    
    @param edge_type string name of the edge type (e.g. "knows", "follows_from")
    @return the newly assigned edge ID
*)
val create_edge : t -> string -> node_id -> node_id -> edge_id

(** [edge_exists db edge_id] checks if an edge exists.
*)
val edge_exists : t -> edge_id -> bool

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

(** [get_edge_info db edge_id] looks up edge information by edge ID
    
    @return [Some edge_info] if found, [None] if edge doesn't exist
*)
val get_edge_info : t -> edge_id -> edge_info option

