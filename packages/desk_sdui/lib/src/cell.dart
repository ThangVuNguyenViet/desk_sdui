/// Mutable single-value holder. Backs every variable binding in an
/// @Screen body / payload function. Holds a native Dart value — no
/// $Value boxing. `final` bindings allocate `_Cell` with `writable: false`;
/// AssignNode against a non-writable cell is a codegen-time error
/// (enforced in the lowerer; runtime trusts the codegen guarantee).
class Cell {
  Cell(this.value);
  Object? value;
}

/// Converts a public-API `Map<String, Object?>` input map into the internal
/// cell-backed env. Called once at every resolver entry point.
Map<String, Cell> toEnv(Map<String, Object?> inputs) {
  return {for (final e in inputs.entries) e.key: Cell(e.value)};
}
