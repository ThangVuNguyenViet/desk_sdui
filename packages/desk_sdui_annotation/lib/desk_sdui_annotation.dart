/// Annotations and IR types for desk_sdui.
///
/// ## What is the IR?
///
/// "IR" stands for **Intermediate Representation** — borrowed from compiler
/// terminology. It is the JSON-serializable tree of nodes ([IrTree], [IrNode]
/// and its subclasses) that sits between the author's Dart `@Screen` function
/// and the rendered widget tree at runtime:
///
/// ```
///   @Screen Dart source
///         │
///         │  desk_sdui_generator  (build-time)
///         ▼
///       IrTree (the IR)
///         │
///         │  serialized as .sdui.json
///         │  shipped as a static asset, served from a CDN,
///         │  or generated at request time by a server
///         ▼
///       Runtime materializes Flutter widgets
/// ```
///
/// The IR is what makes desk_sdui's screens **portable**: the same screen can
/// be baked into the binary, fetched over the network, or composed on a
/// backend, because all paths converge on the same [IrTree] shape.
library;

export 'src/annotations.dart';
export 'src/ir/ir_node.dart';
export 'src/ir/ir_tree.dart';
export 'src/ir/compare_op.dart';
export 'src/ir/arith_op.dart';
export 'src/ir/logic_op.dart';
export 'src/ir/codec/json_ir_codec.dart';
