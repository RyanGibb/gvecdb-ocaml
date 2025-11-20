(** example client demonstrating gvecdb usage *)

let () =
  print_endline "=== gvecdb example client ===" ;
  print_endline "" ;
  
  print_endline "creating database at /tmp/gvecdb_example.db" ;
  let db = Gvecdb.create "/tmp/gvecdb_example.db" in
  print_endline "" ;
  
  print_endline "creating person nodes" ;
  let alice = Gvecdb.create_node db "person" in
  let bob = Gvecdb.create_node db "person" in
  let charlie = Gvecdb.create_node db "person" in
  
  Printf.printf "  alice (node ID): %Ld\n" alice ;
  Printf.printf "  bob (node ID): %Ld\n" bob ;
  Printf.printf "  charlie (node ID): %Ld\n" charlie ;
  print_endline "" ;
  
  print_endline "creating edges" ;
  let edge1 = Gvecdb.create_edge db "knows" alice bob in
  let edge2 = Gvecdb.create_edge db "knows" bob charlie in
  let edge3 = Gvecdb.create_edge db "likes" alice charlie in
  
  Printf.printf "  alice --[knows]--> bob (edge ID): %Ld\n" edge1 ;
  Printf.printf "  bob --[knows]--> charlie (edge ID): %Ld\n" edge2 ;
  Printf.printf "  alice --[likes]--> charlie (edge ID): %Ld\n" edge3 ;
  print_endline "" ;
  
  print_endline "testing existence checks" ;
  assert (Gvecdb.node_exists db alice) ;
  assert (Gvecdb.edge_exists db edge1) ;
  assert (not (Gvecdb.node_exists db 9999L)) ;
  assert (not (Gvecdb.edge_exists db 9999L)) ;
  print_endline "existence checks working correctly" ;
  print_endline "" ;
  
  print_endline "testing adjacency queries" ;
  let alice_outbound = Gvecdb.get_outbound_edges db alice in
  let bob_outbound = Gvecdb.get_outbound_edges db bob in
  let charlie_inbound = Gvecdb.get_inbound_edges db charlie in
  
  Printf.printf "  alice outbound edges (%d):\n" (List.length alice_outbound) ;
  List.iter (fun edge ->
    Printf.printf "    edge %Ld: [%s] -> node %Ld\n" 
      edge.Gvecdb.id edge.Gvecdb.edge_type edge.Gvecdb.dst
  ) alice_outbound ;
  
  Printf.printf "  bob outbound edges (%d):\n" (List.length bob_outbound) ;
  List.iter (fun edge ->
    Printf.printf "    edge %Ld: [%s] -> node %Ld\n"
      edge.Gvecdb.id edge.Gvecdb.edge_type edge.Gvecdb.dst
  ) bob_outbound ;
  
  Printf.printf "  charlie inbound edges (%d):\n" (List.length charlie_inbound) ;
  List.iter (fun edge ->
    Printf.printf "    edge %Ld: [%s] from node %Ld\n"
      edge.Gvecdb.id edge.Gvecdb.edge_type edge.Gvecdb.src
  ) charlie_inbound ;
  print_endline "" ;
  
  print_endline "testing adjacency queries by type" ;
  let alice_knows = Gvecdb.get_outbound_edges_by_type db alice "knows" in
  let alice_likes = Gvecdb.get_outbound_edges_by_type db alice "likes" in
  
  Printf.printf "  alice --[knows]--> edges (%d):\n" (List.length alice_knows) ;
  List.iter (fun edge ->
    Printf.printf "    edge %Ld -> node %Ld\n" edge.Gvecdb.id edge.Gvecdb.dst
  ) alice_knows ;
  
  Printf.printf "  alice --[likes]--> edges (%d):\n" (List.length alice_likes) ;
  List.iter (fun edge ->
    Printf.printf "    edge %Ld -> node %Ld\n" edge.Gvecdb.id edge.Gvecdb.dst
  ) alice_likes ;
  print_endline "" ;
  
  print_endline "testing get_edge_info" ;
  (match Gvecdb.get_edge_info db edge1 with
   | Some info ->
       Printf.printf "  edge %Ld: node %Ld --[%s]--> node %Ld\n"
         info.Gvecdb.id info.Gvecdb.src info.Gvecdb.edge_type info.Gvecdb.dst
   | None -> print_endline "  edge not found!") ;
  print_endline "" ;
  
  print_endline "closing database" ;
  Gvecdb.close db ;
  
  print_endline "" ;
  print_endline "example completed successfully!" ;
  print_endline "" ;
  print_endline "note: node/edge properties are not yet implemented." ;
  print_endline "      vector operations are not yet implemented." ;

