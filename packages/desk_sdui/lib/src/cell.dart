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

/// Reserved input-map key holding a `Map<String, Cell>` of persistent
/// state cells installed by an enclosing `IrStatefulNode` host. When [toEnv]
/// encounters this key, it splices those cells into the resulting env in
/// place of freshly-allocated ones for matching names — so writes to those
/// cells survive across resolver invocations (cross-build screen state).
const String kStateCellsKey = r'__stateCells__';

/// Reserved input-map key holding a `void Function()` installed by the
/// enclosing `IrStatefulNode` host. Event handlers that mutate persistent
/// state cells invoke this after running so Flutter schedules a rebuild.
/// Absent in stateless screens — both the resolver and the lambda evaluator
/// treat absence as a no-op.
const String kStatefulSetStateKey = r'__setState__';

/// Converts a public-API `Map<String, Object?>` input map into the internal
/// cell-backed env. Called once at every resolver entry point.
///
/// If [inputs] contains a [kStateCellsKey] entry holding a
/// `Map<String, Cell>`, those persistent cells shadow freshly-allocated ones
/// for matching names. This is how an `IrStatefulNode` host preserves
/// mutable state across rebuilds.
Map<String, Cell> toEnv(Map<String, Object?> inputs) {
  final stateCellsRaw = inputs[kStateCellsKey];
  final env = <String, Cell>{};
  for (final e in inputs.entries) {
    if (e.key == kStateCellsKey) continue;
    env[e.key] = Cell(e.value);
  }
  if (stateCellsRaw is Map<String, Cell>) {
    for (final entry in stateCellsRaw.entries) {
      env[entry.key] = entry.value;
    }
  }
  return env;
}
