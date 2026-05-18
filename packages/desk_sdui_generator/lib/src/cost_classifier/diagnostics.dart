import 'classifier.dart';

// ---------------------------------------------------------------------------
// Call-site context
// ---------------------------------------------------------------------------

/// The context in which a payload function is called.
enum CallSiteContext {
  /// Inside a @Screen body or a WidgetNode arg (sync, per-frame).
  build,

  /// Inside a reactive binding / computed slot (sync, per-signal-tick).
  signal,

  /// Inside an ActionSequenceNode step or other event handler.
  action,
}

// ---------------------------------------------------------------------------
// Call-site record
// ---------------------------------------------------------------------------

/// A single call site recorded by the lowerer for post-lowering diagnostic
/// emission.
class CallSiteRecord {
  const CallSiteRecord({
    required this.calleeName,
    required this.callerName,
    required this.context,
    this.location,
  });

  final String calleeName;
  final String callerName;
  final CallSiteContext context;

  /// Optional source location string for the diagnostic message.
  final String? location;
}

// ---------------------------------------------------------------------------
// Severity
// ---------------------------------------------------------------------------

enum Severity { info, warning }

// ---------------------------------------------------------------------------
// Diagnostic matrix
// ---------------------------------------------------------------------------

/// Returns the [Severity] for calling a function of [cls] in [ctx], or `null`
/// if no diagnostic should be emitted (silent).
Severity? diagnosticFor(CostClass cls, CallSiteContext ctx) {
  return switch ((cls, ctx)) {
    (CostClass.pureBounded, _) => null,
    (CostClass.linearInArg, CallSiteContext.build) => Severity.info,
    (CostClass.linearInArg, CallSiteContext.signal) => Severity.info,
    (CostClass.linearInArg, CallSiteContext.action) => null,
    (CostClass.unbounded, CallSiteContext.build) => Severity.warning,
    (CostClass.unbounded, CallSiteContext.signal) => Severity.warning,
    (CostClass.unbounded, CallSiteContext.action) => Severity.info,
    (CostClass.recursiveSizeDecreasing, CallSiteContext.build) => Severity.info,
    (CostClass.recursiveSizeDecreasing, CallSiteContext.signal) => Severity.info,
    (CostClass.recursiveSizeDecreasing, CallSiteContext.action) => null,
    (CostClass.recursiveFree, _) => Severity.warning,
    (CostClass.allocatesPerCall, CallSiteContext.build) => Severity.info,
    (CostClass.allocatesPerCall, CallSiteContext.signal) => Severity.info,
    (CostClass.allocatesPerCall, CallSiteContext.action) => null,
  };
}

// ---------------------------------------------------------------------------
// Message templates
// ---------------------------------------------------------------------------

/// Returns the human-readable diagnostic message for calling [fnName] of
/// [cls] in [ctx].
String messageFor(CostClass cls, CallSiteContext ctx, String fnName) {
  return switch ((cls, ctx)) {
    (CostClass.linearInArg, CallSiteContext.build) =>
      '"$fnName" is O(N) in its arg. Called per frame in build. '
      'Consider collection-for or moving to an event handler.',
    (CostClass.linearInArg, CallSiteContext.signal) =>
      '"$fnName" is O(N) in its arg. Called per signal tick.',
    (CostClass.unbounded, CallSiteContext.build) =>
      '"$fnName" has no statically-derivable upper bound. '
      'In a per-frame path; this may stall builds.',
    (CostClass.unbounded, CallSiteContext.signal) =>
      '"$fnName" has no statically-derivable upper bound. '
      'In a signal-tick path; this may stall reactive rebuilds.',
    (CostClass.unbounded, CallSiteContext.action) =>
      '"$fnName" has no statically-derivable upper bound. '
      'In an action handler — confirm termination.',
    (CostClass.recursiveFree, _) =>
      '"$fnName" is recursive without a size-decreasing argument. '
      'Stack overflow risk; confirm termination.',
    (CostClass.recursiveSizeDecreasing, _) =>
      '"$fnName" recursive with size-decreasing arg. O(depth × body) per call.',
    (CostClass.allocatesPerCall, CallSiteContext.build) =>
      '"$fnName" allocates a payload instance per call. '
      'In a build path; consider memoizing if called > ~100× per frame.',
    (CostClass.allocatesPerCall, CallSiteContext.signal) =>
      '"$fnName" allocates a payload instance per call. '
      'In a signal-tick path; consider memoizing.',
    _ => '',
  };
}

// ---------------------------------------------------------------------------
// Diagnostic code
// ---------------------------------------------------------------------------

/// Returns the diagnostic code string for the given class+context pair.
/// Authors can suppress with `// ignore: <code>`.
String codeFor(CostClass cls, CallSiteContext ctx) {
  return switch ((cls, ctx)) {
    (CostClass.linearInArg, CallSiteContext.build) =>
      'sdui_potential_cost.linear_in_build',
    (CostClass.linearInArg, CallSiteContext.signal) =>
      'sdui_potential_cost.linear_in_signal',
    (CostClass.unbounded, CallSiteContext.build) =>
      'sdui_potential_cost.unbounded_in_build',
    (CostClass.unbounded, CallSiteContext.signal) =>
      'sdui_potential_cost.unbounded_in_signal',
    (CostClass.unbounded, CallSiteContext.action) =>
      'sdui_potential_cost.unbounded_in_action',
    (CostClass.recursiveSizeDecreasing, _) =>
      'sdui_potential_cost.recursive_size_decreasing',
    (CostClass.recursiveFree, _) =>
      'sdui_potential_cost.recursive_free',
    (CostClass.allocatesPerCall, CallSiteContext.build) =>
      'sdui_potential_cost.allocates_in_build',
    (CostClass.allocatesPerCall, CallSiteContext.signal) =>
      'sdui_potential_cost.allocates_in_signal',
    _ => 'sdui_potential_cost',
  };
}

// ---------------------------------------------------------------------------
// Emitter
// ---------------------------------------------------------------------------

/// A single emitted diagnostic from [emitCostDiagnostics].
class CostDiagnostic {
  const CostDiagnostic({
    required this.severity,
    required this.code,
    required this.message,
    required this.calleeName,
    required this.callerName,
    required this.context,
    this.location,
  });

  final Severity severity;
  final String code;
  final String message;
  final String calleeName;
  final String callerName;
  final CallSiteContext context;
  final String? location;

  @override
  String toString() =>
      '[${severity.name.toUpperCase()}] $code: $message'
      '${location != null ? ' ($location)' : ''}';
}

/// Processes [sites] against a pre-classified [classes] map and returns the
/// list of diagnostics that should be surfaced.
///
/// Per plan: warnings do NOT fail the build — surfacing them is the value.
/// The caller is responsible for forwarding these to the IDE/analyzer reporter.
List<CostDiagnostic> emitCostDiagnostics(
  List<CallSiteRecord> sites,
  Map<String, CostClass> classes,
) {
  final diagnostics = <CostDiagnostic>[];
  for (final site in sites) {
    final cls = classes[site.calleeName];
    if (cls == null) continue;
    final sev = diagnosticFor(cls, site.context);
    if (sev == null) continue;
    final msg = messageFor(cls, site.context, site.calleeName);
    final code = codeFor(cls, site.context);
    diagnostics.add(CostDiagnostic(
      severity: sev,
      code: code,
      message: msg,
      calleeName: site.calleeName,
      callerName: site.callerName,
      context: site.context,
      location: site.location,
    ));
  }
  return diagnostics;
}
