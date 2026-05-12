/// Mutable single-value holder. Backs every variable binding in an
/// @Screen body / payload function. Holds a native Dart value — no
/// `$Value` boxing.
///
/// All [Cell]s are unconditionally writable at runtime — there is no
/// `writable` flag. `final`-ness is enforced entirely at lowering time:
/// the lowerer tracks `BindingKind.finalBinding` vs `varBinding` and
/// rejects any [AssignNode] targeting a final-bound name with a
/// `LoweringError`. The runtime trusts that codegen-time guarantee and
/// performs no write-permission check.
class Cell {
  Cell(this.value);
  Object? value;
}

/// Converts a public-API `Map<String, Object?>` input map into the internal
/// cell-backed env. Called once at every resolver entry point.
Map<String, Cell> toEnv(Map<String, Object?> inputs) {
  return {for (final e in inputs.entries) e.key: Cell(e.value)};
}
