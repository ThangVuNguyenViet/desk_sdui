import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

// ---------------------------------------------------------------------------
// Cost class enum
// ---------------------------------------------------------------------------

/// The static cost class assigned to a payload function (or screen body) by
/// the codegen-time classifier.
///
/// Used by [CostDiagnostics] to decide whether to emit a diagnostic at a
/// call site, based on the call-site context (build / signal / action).
///
/// **Limitations (documented per plan):**
/// - Inter-procedural transitivity is NOT computed. A [linearInArg] function
///   called inside a loop in another function is NOT automatically O(N²).
/// - Collection-for ([ForNode]) detection is source-aware (data-dependent vs
///   literal). Imperative loops ([WhileNode], [DoNode], [ImperativeForNode])
///   are unconditionally classified as [unbounded] — their iteration count is
///   driven by mutable state, which the classifier does not analyze.
/// - Conditional/branched recursion: if ANY call site of the self-reference is
///   non-size-decreasing, the function is classified as [recursiveFree].
/// - "Registered method result with iterable shape" — the classifier detects
///   ForNode sources that are RefNodes (direct param reads); other sources are
///   conservative: classified as data-dependent loops.
enum CostClass {
  /// No loops; or loops with literal iteration counts. O(1) per call.
  pureBounded,

  /// Has at least one ForNode whose source is a parameter reference or a
  /// non-literal expression (data-dependent). O(N × body) per call.
  linearInArg,

  /// Has a loop whose bound is statically undeducible (e.g. a `while` loop
  /// driven by mutable state). Set for [WhileNode], [DoNode], and
  /// [ImperativeForNode] subtrees.
  unbounded,

  /// Recursive call passes a strictly smaller argument (e.g. `fact(n - 1)`).
  /// Treated as O(depth × body) per call — like [linearInArg] for diagnostic purposes.
  recursiveSizeDecreasing,

  /// Recursive call without a size-decrease guarantee. Treated as [unbounded].
  recursiveFree,

  /// Constructs at least one PayloadInstance. Per-call heap allocation.
  /// In tight build-path loops, may dominate frame budget.
  allocatesPerCall,
}

// ---------------------------------------------------------------------------
// Internal findings accumulator
// ---------------------------------------------------------------------------

class _Findings {
  bool hasDataDependentLoop = false;
  bool hasUnboundedLoop = false; // set by WhileNode / DoNode / ImperativeForNode and the existing ForNode
  bool hasSizeDecreasingRecursion = false;
  bool hasFreeRecursion = false;
  bool hasAllocation = false;
}

// ---------------------------------------------------------------------------
// Public classifier entry-point
// ---------------------------------------------------------------------------

/// Classifies the cost of an IR subtree.
///
/// [body] is the IrNode root to walk (screen body or payload function body).
/// [selfName] is the name of the enclosing function — used to detect
/// self-recursive calls via [MethodCallNode].
///
/// Returns the [CostClass] for this subtree.
CostClass classify(IrNode body, {required String? selfName}) {
  final findings = _Findings();
  _walk(body, findings, selfName: selfName);

  if (findings.hasFreeRecursion) return CostClass.recursiveFree;
  if (findings.hasSizeDecreasingRecursion && !findings.hasUnboundedLoop) {
    return CostClass.recursiveSizeDecreasing;
  }
  if (findings.hasUnboundedLoop) return CostClass.unbounded;
  if (findings.hasDataDependentLoop) return CostClass.linearInArg;
  if (findings.hasAllocation) return CostClass.allocatesPerCall;
  return CostClass.pureBounded;
}

// ---------------------------------------------------------------------------
// Walker
// ---------------------------------------------------------------------------

void _walk(IrNode node, _Findings f, {required String? selfName}) {
  switch (node) {
    case ForNode():
      // A ForNode whose source is a non-literal expression is data-dependent.
      // Literal sources (e.g. ForNode over a fixed ListNode) stay pureBounded.
      if (!_isLiteralSource(node.source)) {
        f.hasDataDependentLoop = true;
      }
      _walk(node.source, f, selfName: selfName);
      _walk(node.body, f, selfName: selfName);

    case MethodCallNode():
      // Self-call detection.
      if (selfName != null && node.name == selfName) {
        // Check whether at least one arg is a clear size-decrement expression.
        if (node.args.any(_isSizeDecrement)) {
          f.hasSizeDecreasingRecursion = true;
        } else {
          f.hasFreeRecursion = true;
        }
      }
      if (node.receiver != null) _walk(node.receiver!, f, selfName: selfName);
      for (final arg in node.args) {
        _walk(arg, f, selfName: selfName);
      }

    case WidgetNode():
      for (final child in node.args.values) {
        _walk(child, f, selfName: selfName);
      }
      if (node.key != null) _walk(node.key!, f, selfName: selfName);

    case BuiltinWidgetNode():
      for (final child in node.args.values) {
        _walk(child, f, selfName: selfName);
      }
      if (node.key != null) _walk(node.key!, f, selfName: selfName);

    case ListNode():
      for (final child in node.children) {
        _walk(child, f, selfName: selfName);
      }

    case MapNode():
      for (final entry in node.entries.entries) {
        _walk(entry.key, f, selfName: selfName);
        _walk(entry.value, f, selfName: selfName);
      }

    case RecordNode():
      for (final child in node.positional) {
        _walk(child, f, selfName: selfName);
      }
      for (final child in node.named.values) {
        _walk(child, f, selfName: selfName);
      }

    case ConditionalNode():
      _walk(node.condition, f, selfName: selfName);
      _walk(node.thenBranch, f, selfName: selfName);
      if (node.elseBranch != null) {
        _walk(node.elseBranch!, f, selfName: selfName);
      }

    case SpreadNode():
      _walk(node.source, f, selfName: selfName);

    case CompareOpNode():
      _walk(node.left, f, selfName: selfName);
      _walk(node.right, f, selfName: selfName);

    case ArithOpNode():
      _walk(node.left, f, selfName: selfName);
      _walk(node.right, f, selfName: selfName);

    case LogicOpNode():
      _walk(node.left, f, selfName: selfName);
      _walk(node.right, f, selfName: selfName);

    case NotOpNode():
      _walk(node.operand, f, selfName: selfName);

    case CoalesceOpNode():
      _walk(node.left, f, selfName: selfName);
      _walk(node.right, f, selfName: selfName);

    case GetterNode():
      _walk(node.receiver, f, selfName: selfName);

    case SetterCallNode():
      _walk(node.target, f, selfName: selfName);
      _walk(node.value, f, selfName: selfName);

    case LetNode():
      _walk(node.value, f, selfName: selfName);
      _walk(node.body, f, selfName: selfName);

    case AssignNode():
      _walk(node.value, f, selfName: selfName);

    case LambdaNode():
      _walk(node.body, f, selfName: selfName);

    case MemberAccessNode():
      _walk(node.target, f, selfName: selfName);

    case IndexAccessNode():
      _walk(node.target, f, selfName: selfName);
      _walk(node.key, f, selfName: selfName);

    case LengthOfNode():
      _walk(node.target, f, selfName: selfName);

    case IsNullCheckNode():
      _walk(node.operand, f, selfName: selfName);

    case IsTypeNode():
      _walk(node.receiver, f, selfName: selfName);

    case AsTypeNode():
      _walk(node.operand, f, selfName: selfName);
    case RuntimeTypeRefNode():
      _walk(node.operand, f, selfName: selfName);
    case PayloadMethodCallNode():
      _walk(node.receiver, f, selfName: selfName);
      for (final arg in node.args.values) {
        _walk(arg, f, selfName: selfName);
      }
    case PayloadFieldRefNode():
      _walk(node.receiver, f, selfName: selfName);
    case PayloadFieldAssignNode():
      _walk(node.receiver, f, selfName: selfName);
      _walk(node.value, f, selfName: selfName);
    case ThisFieldRefNode():
    case ThisRefNode():
      // No children to walk.
      break;

    case StringInterpNode():
      for (final part in node.parts) {
        if (part is IrNode) {
          _walk(part, f, selfName: selfName);
        }
      }

    case ValueCtorNode():
      for (final arg in node.args) {
        _walk(arg, f, selfName: selfName);
      }

    case ActionSequenceNode():
      for (final step in node.steps) {
        _walk(step, f, selfName: selfName);
      }

    case ActionStepNode():
      _walk(node.call, f, selfName: selfName);

    case TryStepNode():
      for (final s in node.trySteps) {
        _walk(s, f, selfName: selfName);
      }
      for (final s in node.catchSteps) {
        _walk(s, f, selfName: selfName);
      }

    case SequenceNode():
      for (final step in node.steps) {
        _walk(step, f, selfName: selfName);
      }
      _walk(node.returnExpr, f, selfName: selfName);

    case BlockNode():
      for (final s in node.statements) {
        _walk(s, f, selfName: selfName);
      }

    case IfStatementNode():
      _walk(node.cond, f, selfName: selfName);
      _walk(node.then, f, selfName: selfName);
      if (node.else_ != null) _walk(node.else_!, f, selfName: selfName);

    case ReturnNode():
      if (node.value != null) _walk(node.value!, f, selfName: selfName);

    case LetStatementNode():
      _walk(node.value, f, selfName: selfName);

    case WhileNode():
      // While-loops are unbounded by definition (iteration count depends on
      // runtime state). Mark as unbounded and recurse into sub-trees.
      f.hasUnboundedLoop = true;
      _walk(node.condition, f, selfName: selfName);
      _walk(node.body, f, selfName: selfName);

    case DoNode():
      f.hasUnboundedLoop = true;
      _walk(node.body, f, selfName: selfName);
      _walk(node.condition, f, selfName: selfName);

    case ImperativeForNode():
      f.hasUnboundedLoop = true;
      if (node.init != null) _walk(node.init!, f, selfName: selfName);
      if (node.condition != null) _walk(node.condition!, f, selfName: selfName);
      if (node.update != null) _walk(node.update!, f, selfName: selfName);
      _walk(node.body, f, selfName: selfName);

    case IrStatefulNode():
      // Field initializers run once at initState time; classify them like
      // ordinary expressions. The body runs every build like a stateless body.
      for (final field in node.fields) {
        _walk(field.initializer, f, selfName: selfName);
      }
      _walk(node.body, f, selfName: selfName);

    case IrStatefulFieldNode():
      _walk(node.initializer, f, selfName: selfName);

    case BreakNode():
    case ContinueNode():
    case LiteralNode():
    case ConstNode():
    case RefNode():
    case EventNode():
      break;

    case PayloadFunctionNode():
      // Payload function declarations are walked from the classifier entry
      // point with self-name set to the function's own name. Inside _walk,
      // we treat a PayloadFunctionNode as an opaque subtree (not re-entered
      // recursively here — the generator calls classify() on each function
      // body separately with the appropriate selfName).
      break;

    case PayloadFunctionCallNode():
      // Call sites to other payload functions: walk args for nested cost.
      for (final arg in node.args) {
        _walk(arg, f, selfName: selfName);
      }

    case ScreenWithFunctionsNode():
      // Walk the screen body; individual function bodies are classified
      // separately by the generator with their own selfName.
      _walk(node.screenBody, f, selfName: selfName);

    case PayloadFunctionValueNode():
      // Function values are metadata; treated like extension declarations.
      break;
    case PayloadExtensionNode():
      // Extension declarations are metadata; treated like mixin declarations.
      break;
    case PayloadMixinNode():
      // Mixin declarations are metadata; treated like class declarations.
      break;
    case PayloadClassNode():
      // Payload class declarations are walked from the classifier entry
      // point. The constructor and method bodies are walked separately
      // by the generator with their own context.
      break;

    case PayloadInstanceCreationNode():
      f.hasAllocation = true;
      for (final arg in node.args.values) {
        _walk(arg, f, selfName: selfName);
      }

    case PayloadFieldDeclNode():
      // Field declarations may have initializers.
      if (node.initializer != null) {
        _walk(node.initializer!, f, selfName: selfName);
      }

    case PayloadCtorNode():
      // Constructor parameters and body are walked separately.
      for (final fieldInit in node.fieldInits) {
        _walk(fieldInit, f, selfName: selfName);
      }
      if (node.body != null) {
        _walk(node.body!, f, selfName: selfName);
      }

    case PayloadFieldInitNode():
      // Field initializer value in a constructor.
      _walk(node.value, f, selfName: selfName);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns true when [source] is a statically-known literal (not data-
/// dependent). A [LiteralNode] or a [ListNode] whose children are all literals
/// qualifies; anything else is treated as data-dependent.
bool _isLiteralSource(IrNode source) {
  if (source is LiteralNode) return true;
  if (source is ConstNode) return true;
  if (source is ListNode) {
    return source.children.every(_isLiteralSource);
  }
  return false;
}

/// Returns true if [node] looks like a "size-decrement" expression: an
/// arithmetic subtraction where the left operand is a reference and the right
/// is a literal (e.g. `n - 1`, `xs.length - 1`).
bool _isSizeDecrement(IrNode node) {
  if (node is ArithOpNode && node.op == ArithOp.sub) {
    return node.right is LiteralNode;
  }
  return false;
}
