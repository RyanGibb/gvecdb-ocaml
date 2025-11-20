(** main API for gvecdb *)

include Types

(** create or open a database at the given path *)
let create = Store.create

(** close the database *)
let close = Store.close

(** parse edge data back into components *)
let parse_edge_data (data : string) : (intern_id * node_id * node_id) =
  Scanf.sscanf data "%Ld:%Ld:%Ld" (fun intern_id src dst -> (intern_id, src, dst))

(** get edge info by edge ID *)
let get_edge_info (db : t) (edge_id : edge_id) : edge_info option =
  try
    let edge_data = Lmdb.Map.get db.edges (Keys.encode_id edge_id) in
    let (intern_id, src, dst) = parse_edge_data edge_data in
    let edge_type = Store.unintern db intern_id in
    Some { id = edge_id; edge_type; src; dst }
  with Not_found -> None

(** create a new node with the given type
    returns the node ID *)
let create_node (db : t) (node_type : string) : node_id =
  let intern_id = Store.intern db node_type in
  let node_id = Store.get_next_id db Metadata.next_node_id in
  (* TODO: store node data blob with type and properties *)
  let node_data = Keys.encode_id intern_id in  (* placeholder *)
  Lmdb.Map.set db.nodes (Keys.encode_id node_id) node_data;
  node_id

(** create a new edge between two nodes
    returns the edge ID *)
let create_edge (db : t) (edge_type : string) (src : node_id) (dst : node_id) : edge_id =
  let intern_id = Store.intern db edge_type in
  let edge_id = Store.get_next_id db Metadata.next_edge_id in
  
  (* store edge data *)
  (* TODO: store edge data blob with type and properties *)
  let edge_data = Printf.sprintf "%Ld:%Ld:%Ld" intern_id src dst in  (* placeholder *)
  Lmdb.Map.set db.edges (Keys.encode_id edge_id) edge_data;
  
  (* update adjacency indexes *)
  let outbound_key = Keys.encode_adjacency ~node_id:src ~intern_id 
    ~opposite_id:dst ~edge_id in
  let inbound_key = Keys.encode_adjacency ~node_id:dst ~intern_id 
    ~opposite_id:src ~edge_id in
  
  Lmdb.Map.set db.outbound outbound_key "";
  Lmdb.Map.set db.inbound inbound_key "";
  
  edge_id

(** scan an adjacency index with a prefix and collect edge IDs, then look up edge info *)
let scan_adjacency_index (db : t) (map : (string, string, [`Uni]) Lmdb.Map.t) (prefix : string) : edge_info list =
  let prefix_len = String.length prefix in
  (* first, collect all edge IDs using cursor *)
  let edge_ids = Lmdb.Cursor.go Lmdb.Ro map (fun cursor ->
    let rec collect acc =
      try
        let (key, _) = Lmdb.Cursor.next cursor in
        if String.length key >= prefix_len && String.sub key 0 prefix_len = prefix then
          let (_, _, _, edge_id) = Keys.decode_adjacency key in
          collect (edge_id :: acc)
        else
          acc
      with Lmdb.Not_found -> acc
    in
    try
      let (key, _) = Lmdb.Cursor.seek_range cursor prefix in
      if String.length key >= prefix_len && String.sub key 0 prefix_len = prefix then
        let (_, _, _, edge_id) = Keys.decode_adjacency key in
        List.rev (collect [edge_id])
      else
        []
    with Lmdb.Not_found -> []
  ) in
  (* now look up edge info for each ID (after cursor is closed) *)
  List.filter_map (fun edge_id -> get_edge_info db edge_id) edge_ids

(** get all outbound edges from a node *)
let get_outbound_edges (db : t) (node_id : node_id) : edge_info list =
  let prefix = Keys.encode_adjacency_prefix ~node_id () in
  scan_adjacency_index db db.outbound prefix

(** get all inbound edges to a node *)
let get_inbound_edges (db : t) (node_id : node_id) : edge_info list =
  let prefix = Keys.encode_adjacency_prefix ~node_id () in
  scan_adjacency_index db db.inbound prefix

(** get all outbound edges of a specific type from a node *)
let get_outbound_edges_by_type (db : t) (node_id : node_id) (edge_type : string) : edge_info list =
  let intern_id = Store.intern db edge_type in
  let prefix = Keys.encode_adjacency_prefix ~node_id ~intern_id () in
  scan_adjacency_index db db.outbound prefix

(** get all inbound edges of a specific type to a node *)
let get_inbound_edges_by_type (db : t) (node_id : node_id) (edge_type : string) : edge_info list =
  let intern_id = Store.intern db edge_type in
  let prefix = Keys.encode_adjacency_prefix ~node_id ~intern_id () in
  scan_adjacency_index db db.inbound prefix

(** check if a node exists *)
let node_exists (db : t) (node_id : node_id) : bool =
  try
    let _ = Lmdb.Map.get db.nodes (Keys.encode_id node_id) in
    true
  with Not_found -> false

(** check if an edge exists *)
let edge_exists (db : t) (edge_id : edge_id) : bool =
  try
    let _ = Lmdb.Map.get db.edges (Keys.encode_id edge_id) in
    true
  with Not_found -> false

