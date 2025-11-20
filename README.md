
# gvecdb - A Hybrid Graph-Vector Database in OCaml

This is a Part II project for the Computer Science Tripos at the University of Cambridge. Please see the [proposal doc](proposal.pdf) for full context!

## Project Structure

- `lib/` - core library (link this into your OCaml projects)
  - `types.ml` - core type definitions
  - `keys.ml` - key encoding/decoding for LMDB
  - `store.ml` - low-level LMDB operations and string interning
  - `gvecdb.ml/.mli` - public API
- `bin/` - example executables
  - `example.ml` - full working example demonstrating the API
  - `main.ml` - CLI tool (placeholder)
- `test/` - unit tests
- `reports/` - weekly progress reports and design decisions
- `vendor/` - vendored dependencies (ocaml-lmdb)

## Quick Start

### Build

```bash
dune build
```

### Run Example

```bash
dune exec bin/example.exe
```

This creates a simple graph with person nodes and knows/likes edges, demonstrating:

- creating nodes with string type names
- creating edges with string type names
- querying edges and getting full edge information (type, src, dst)
- string interning happens automatically under the hood
- persistence across runs

### Use as a Library

```ocaml
(* in your dune file: (libraries gvecdb) *)

let db = Gvecdb.create "/path/to/db" in

(* create nodes - just pass type as a string *)
let alice = Gvecdb.create_node db "person" in
let bob = Gvecdb.create_node db "person" in

(* create edges - types are strings too *)
let edge = Gvecdb.create_edge db "knows" alice bob in

(* query edges - returns edge_info records with full details *)
let edges = Gvecdb.get_outbound_edges db alice in
List.iter (fun edge_info ->
  Printf.printf "edge %Ld: [%s] -> node %Ld\n"
    edge_info.id edge_info.edge_type edge_info.dst
) edges;

(* look up a specific edge *)
match Gvecdb.get_edge_info db edge with
| Some info -> Printf.printf "Found: %Ld -[%s]-> %Ld\n" 
                 info.src info.edge_type info.dst
| None -> print_endline "Edge not found";

Gvecdb.close db
```

## Testing

```bash
dune runtest
```
