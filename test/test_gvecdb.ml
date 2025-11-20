open Printf

module SchemaMod = Schemas.Make(Capnp.BytesMessage)

let temp_db_path () =
  Filename.(concat (get_temp_dir_name ())
             (sprintf "gvecdb_test_%d.db" (Unix.getpid ())))

let register_schemas db =
  Gvecdb.register_node_schema_capnp db "person" 0xd8e6e025e7838111L;
  Gvecdb.register_edge_schema_capnp db "knows" 0xd3c22e2de1d0b32bL

let create_person db name age email bio =
  let node = Gvecdb.create_node db "person" in
  Gvecdb.set_node_props_capnp db node "person"
    (fun b ->
       SchemaMod.Builder.Person.name_set b name;
       SchemaMod.Builder.Person.age_set_int_exn b age;
       SchemaMod.Builder.Person.email_set b email;
       SchemaMod.Builder.Person.bio_set b bio)
    SchemaMod.Builder.Person.init_root
    SchemaMod.Builder.Person.to_message;
  node

let measure_heap_growth f =
  Gc.full_major ();
  let word_bytes = Sys.word_size / 8 in
  let before = (Gc.stat ()).heap_words in
  let result = f () in
  let after = (Gc.stat ()).heap_words in
  let bytes = (after - before) * word_bytes in
  (result, bytes)

let test_zero_copy () =
  let path = temp_db_path () in
  (try Sys.remove path with _ -> ());
  let db = Gvecdb.create path in
  register_schemas db;
  
  (* 1MB bio to make allocation differences obvious *)
  let large_bio = String.make 1_000_000 'x' ^ "\n\nActual content here." in
  let bio_size = String.length large_bio in
  let alice = create_person db "Alice" 30 "alice@example.com" large_bio in

  printf "  bio size: %d bytes (~%.1f MB)\n" bio_size (float_of_int bio_size /. 1_000_000.);

  (* zero-copy read *)
  let (bio_len, first_char, last_chars), alloc_zerocopy = measure_heap_growth (fun () ->
      Gvecdb.get_node_props_capnp db alice "person"
        SchemaMod.Reader.Person.of_message
        (fun reader ->
           let bio = SchemaMod.Reader.Person.bio_get reader in
           let len = String.length bio in
           let first = bio.[0] in
           let last = String.sub bio (len - 10) 10 in
           (* read every 1000th character for checksum *)
           let checksum = ref 0 in
           for i = 0 to (len / 1000) do
             checksum := !checksum + Char.code bio.[min (i * 1000) (len - 1)]
           done;
           (len, first, last)))
  in

  (* copy read *)
  let _, alloc_copy = measure_heap_growth (fun () ->
      Gvecdb.get_node_props_capnp db alice "person"
        SchemaMod.Reader.Person.of_message
        (fun reader ->
           let bio = SchemaMod.Reader.Person.bio_get reader in
           Bytes.to_string (Bytes.of_string bio)))
  in

  printf "  zero-copy allocation: %d bytes\n" alloc_zerocopy;
  printf "  copy allocation: %d bytes\n" alloc_copy;
  printf "  savings: %d bytes (%.1fx)\n" 
    (alloc_copy - alloc_zerocopy)
    (float_of_int alloc_copy /. float_of_int (max 1 alloc_zerocopy));

  (* assertions *)
  assert (bio_len = bio_size);
  assert (first_char = 'x');
  assert (String.equal last_chars "tent here.");
  assert (alloc_zerocopy < 50_000);  (* < 50 KB overhead *)
  assert (alloc_copy > bio_size);    (* Copy allocates the full data *)
  assert (alloc_copy > alloc_zerocopy + 900_000);  (* > 900 KB difference *)
  
  printf "  zero-copy verified (accessed 1MB with <%d bytes allocated)\n" alloc_zerocopy;

  Gvecdb.close db;
  (try Sys.remove path with _ -> ())

let test_round_trip () =
  let path = temp_db_path () in
  (try Sys.remove path with _ -> ());
  let db = Gvecdb.create path in
  register_schemas db;
  
  let alice = create_person db "Alice" 31 "alice@example.com" "Engineer" in
  let edge = Gvecdb.create_edge db "knows" alice alice in

  (* test node properties *)
  let name = Gvecdb.get_node_props_capnp db alice "person"
      SchemaMod.Reader.Person.of_message
      SchemaMod.Reader.Person.name_get in
  assert (String.equal name "Alice");

  (* test edge properties *)
  Gvecdb.set_edge_props_capnp db edge "knows"
    (fun b ->
       SchemaMod.Builder.Knows.since_set b 123L;
       SchemaMod.Builder.Knows.context_set b "test";
       SchemaMod.Builder.Knows.strength_set b 0.5)
    SchemaMod.Builder.Knows.init_root
    SchemaMod.Builder.Knows.to_message;
    
  let context = Gvecdb.get_edge_props_capnp db edge "knows"
      SchemaMod.Reader.Knows.of_message
      SchemaMod.Reader.Knows.context_get in
  assert (String.equal context "test");
  
  (* verify edge metadata is preserved after setting properties *)
  (match Gvecdb.get_edge_info db edge with
   | Some info ->
       assert (String.equal info.edge_type "knows");
       assert (info.src = alice);
       assert (info.dst = alice)
   | None -> failwith "edge metadata lost after setting properties!");
  
  printf "  node and edge properties working\n";
  printf "  edge metadata preserved after setting properties\n";

  Gvecdb.close db;
  (try Sys.remove path with _ -> ())

let test_deletions () =
  let path = temp_db_path () in
  (try Sys.remove path with _ -> ());
  let db = Gvecdb.create path in
  register_schemas db;
  
  (* create test data *)
  let alice = create_person db "Alice" 30 "alice@example.com" "Engineer" in
  let bob = create_person db "Bob" 25 "bob@example.com" "Designer" in
  let edge1 = Gvecdb.create_edge db "knows" alice bob in
  let edge2 = Gvecdb.create_edge db "knows" bob alice in
  
  (* test get_node_info *)
  (match Gvecdb.get_node_info db alice with
   | Some info ->
       assert (info.id = alice);
       assert (String.equal info.node_type "person")
   | None -> failwith "node info not found!");
  
  (* test edge deletion *)
  assert (Gvecdb.edge_exists db edge1);
  Gvecdb.delete_edge db edge1;
  assert (not (Gvecdb.edge_exists db edge1));
  
  (* verify edge removed from adjacency indexes *)
  let outbound = Gvecdb.get_outbound_edges db alice in
  assert (List.length outbound = 0);  (* edge1 was the only outbound *)
  
  (* other edge should still exist *)
  assert (Gvecdb.edge_exists db edge2);
  let inbound = Gvecdb.get_inbound_edges db alice in
  assert (List.length inbound = 1);
  
  (* test node deletion *)
  assert (Gvecdb.node_exists db bob);
  Gvecdb.delete_node db bob;
  assert (not (Gvecdb.node_exists db bob));
  
  (* get_node_info should return None for deleted node *)
  (match Gvecdb.get_node_info db bob with
   | Some _ -> failwith "deleted node still has info!"
   | None -> ());
  
  printf "  deletions working correctly\n";
  
  Gvecdb.close db;
  (try Sys.remove path with _ -> ())

let () =
  printf "running gvecdb tests...\n";
  test_round_trip ();
  test_zero_copy ();
  test_deletions ();
  printf "all tests passed!\n"