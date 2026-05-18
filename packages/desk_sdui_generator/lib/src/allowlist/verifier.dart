import 'package:analyzer/dart/ast/ast.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

/// In-memory index of registered leaves visible to the verifier.
class RegistryIndex {
  RegistryIndex({
    this.registeredWidgets = const {},
    this.registeredValueBuilders = const {},
    this.registeredMethods = const {},
    this.registeredGetters = const {},
    this.registeredSetters = const {},
    this.payloadFunctionNames = const {},
    this.payloadClassNames = const {},
    this.payloadMixinNames = const {},
    this.payloadExtensionMethods = const {},
  });

  final Set<String> registeredWidgets;
  final Set<String> registeredValueBuilders;
  final Map<String, Set<String>> registeredMethods;
  final Map<String, Set<String>> registeredGetters;
  final Map<String, Set<String>> registeredSetters;
  final Set<String> payloadFunctionNames;
  final Set<String> payloadClassNames;
  final Set<String> payloadMixinNames;
  final Map<String, Set<String>> payloadExtensionMethods;
}

/// A single allowlist violation.
class AllowlistViolation {
  AllowlistViolation({
    required this.message,
    required this.node,
    this.decl,
  });

  final String message;
  final IrNode node;
  final AstNode? decl;
}

/// Verifies that every leaf call in payload function/method bodies resolves to
/// a registered global, a payload-defined function/method, or a built-in primitive.
List<AllowlistViolation> verifyAllowlist(
  IrNode root,
  RegistryIndex registry, {
  String? payloadFnName,
  AstNode? decl,
}) {
  final violations = <AllowlistViolation>[];
  _walk(root, registry, violations, payloadFnName: payloadFnName, decl: decl);
  return violations;
}

void _walk(
  IrNode node,
  RegistryIndex registry,
  List<AllowlistViolation> violations, {
  String? payloadFnName,
  AstNode? decl,
}) {
  switch (node) {
    case MethodCallNode(:final receiver, :final name):
      if (receiver == null) {
        final isPlainLowercase = !name.contains('.') &&
            name.isNotEmpty &&
            name[0] == name[0].toLowerCase();
        if (isPlainLowercase &&
            !registry.payloadFunctionNames.contains(name) &&
            !registry.registeredValueBuilders.contains(name) &&
            !registry.registeredWidgets.contains(name)) {
          violations.add(AllowlistViolation(
            message: 'Payload function "${payloadFnName ?? "<unknown>"}" calls '
                '"$name" which is neither a registered global nor another '
                'payload function in this file.',
            node: node,
            decl: decl,
          ));
        }
      } else {
        // Instance method call: check registered methods.
        final bucket = name.split('.').first;
        final methodSet = registry.registeredMethods[bucket];
        if (methodSet != null && !methodSet.contains(name)) {
          violations.add(AllowlistViolation(
            message: 'Method "$name" is not registered on type "$bucket".',
            node: node,
            decl: decl,
          ));
        }
      }
      if (receiver != null) {
        _walk(receiver, registry, violations, payloadFnName: payloadFnName, decl: decl);
      }
      for (final arg in node.args) {
        _walk(arg, registry, violations, payloadFnName: payloadFnName, decl: decl);
      }

    case PayloadFunctionCallNode(:final name):
      if (!registry.payloadFunctionNames.contains(name)) {
        violations.add(AllowlistViolation(
          message: 'Payload function call "$name" is not declared in this file.',
          node: node,
          decl: decl,
        ));
      }
      for (final arg in node.args) {
        _walk(arg, registry, violations, payloadFnName: payloadFnName, decl: decl);
      }

    case PayloadMethodCallNode(:final receiver):
      _walk(receiver, registry, violations, payloadFnName: payloadFnName, decl: decl);
      for (final arg in node.args.values) {
        _walk(arg, registry, violations, payloadFnName: payloadFnName, decl: decl);
      }

    case BuiltinWidgetNode():
      for (final child in node.args.values) {
        _walk(child, registry, violations, payloadFnName: payloadFnName, decl: decl);
      }
      if (node.key != null) {
        _walk(node.key!, registry, violations, payloadFnName: payloadFnName, decl: decl);
      }
    case WidgetNode(:final name):
      if (!registry.registeredWidgets.contains(name)) {
        violations.add(AllowlistViolation(
          message: 'Widget "$name" is not registered.',
          node: node,
          decl: decl,
        ));
      }
      for (final child in node.args.values) {
        _walk(child, registry, violations, payloadFnName: payloadFnName, decl: decl);
      }
      if (node.key != null) {
        _walk(node.key!, registry, violations, payloadFnName: payloadFnName, decl: decl);
      }

    case ValueCtorNode(:final name):
      if (!registry.registeredValueBuilders.contains(name)) {
        violations.add(AllowlistViolation(
          message: 'Value constructor "$name" is not registered.',
          node: node,
          decl: decl,
        ));
      }
      for (final arg in node.args) {
        _walk(arg, registry, violations, payloadFnName: payloadFnName, decl: decl);
      }

    case ListNode():
      for (final child in node.children) {
        _walk(child, registry, violations, payloadFnName: payloadFnName, decl: decl);
      }

    case MapNode():
      for (final entry in node.entries.entries) {
        _walk(entry.key, registry, violations, payloadFnName: payloadFnName, decl: decl);
        _walk(entry.value, registry, violations, payloadFnName: payloadFnName, decl: decl);
      }

    case RecordNode():
      for (final child in node.positional) {
        _walk(child, registry, violations, payloadFnName: payloadFnName, decl: decl);
      }
      for (final child in node.named.values) {
        _walk(child, registry, violations, payloadFnName: payloadFnName, decl: decl);
      }

    case ConditionalNode():
      _walk(node.condition, registry, violations, payloadFnName: payloadFnName, decl: decl);
      _walk(node.thenBranch, registry, violations, payloadFnName: payloadFnName, decl: decl);
      if (node.elseBranch != null) {
        _walk(node.elseBranch!, registry, violations, payloadFnName: payloadFnName, decl: decl);
      }

    case ForNode():
      _walk(node.source, registry, violations, payloadFnName: payloadFnName, decl: decl);
      _walk(node.body, registry, violations, payloadFnName: payloadFnName, decl: decl);

    case SpreadNode():
      _walk(node.source, registry, violations, payloadFnName: payloadFnName, decl: decl);

    case CompareOpNode(:final left, :final right):
      _walk(left, registry, violations, payloadFnName: payloadFnName, decl: decl);
      _walk(right, registry, violations, payloadFnName: payloadFnName, decl: decl);

    case ArithOpNode(:final left, :final right):
      _walk(left, registry, violations, payloadFnName: payloadFnName, decl: decl);
      _walk(right, registry, violations, payloadFnName: payloadFnName, decl: decl);

    case LogicOpNode(:final left, :final right):
      _walk(left, registry, violations, payloadFnName: payloadFnName, decl: decl);
      _walk(right, registry, violations, payloadFnName: payloadFnName, decl: decl);

    case NotOpNode():
      _walk(node.operand, registry, violations, payloadFnName: payloadFnName, decl: decl);

    case CoalesceOpNode(:final left, :final right):
      _walk(left, registry, violations, payloadFnName: payloadFnName, decl: decl);
      _walk(right, registry, violations, payloadFnName: payloadFnName, decl: decl);

    case GetterNode(:final receiver):
      _walk(receiver, registry, violations, payloadFnName: payloadFnName, decl: decl);

    case SetterCallNode(:final target, :final value):
      _walk(target, registry, violations, payloadFnName: payloadFnName, decl: decl);
      _walk(value, registry, violations, payloadFnName: payloadFnName, decl: decl);

    case LetNode(:final value, :final body):
      _walk(value, registry, violations, payloadFnName: payloadFnName, decl: decl);
      _walk(body, registry, violations, payloadFnName: payloadFnName, decl: decl);

    case AssignNode(:final value):
      _walk(value, registry, violations, payloadFnName: payloadFnName, decl: decl);

    case SequenceNode(:final steps, :final returnExpr):
      for (final step in steps) {
        _walk(step, registry, violations, payloadFnName: payloadFnName, decl: decl);
      }
      _walk(returnExpr, registry, violations, payloadFnName: payloadFnName, decl: decl);

    case LambdaNode(:final body):
      _walk(body, registry, violations, payloadFnName: payloadFnName, decl: decl);

    case MemberAccessNode(:final target):
      _walk(target, registry, violations, payloadFnName: payloadFnName, decl: decl);

    case IndexAccessNode(:final target, :final key):
      _walk(target, registry, violations, payloadFnName: payloadFnName, decl: decl);
      _walk(key, registry, violations, payloadFnName: payloadFnName, decl: decl);

    case LengthOfNode(:final target):
      _walk(target, registry, violations, payloadFnName: payloadFnName, decl: decl);

    case IsNullCheckNode(:final operand):
      _walk(operand, registry, violations, payloadFnName: payloadFnName, decl: decl);

    case IsTypeNode(:final receiver):
      _walk(receiver, registry, violations, payloadFnName: payloadFnName, decl: decl);

    case AsTypeNode(:final operand):
      _walk(operand, registry, violations, payloadFnName: payloadFnName, decl: decl);

    case RuntimeTypeRefNode(:final operand):
      _walk(operand, registry, violations, payloadFnName: payloadFnName, decl: decl);

    case StringInterpNode():
      for (final part in node.parts) {
        if (part is IrNode) {
          _walk(part, registry, violations, payloadFnName: payloadFnName, decl: decl);
        }
      }

    case PayloadFieldRefNode(:final receiver):
      _walk(receiver, registry, violations, payloadFnName: payloadFnName, decl: decl);

    case PayloadFieldAssignNode(:final receiver, :final value):
      _walk(receiver, registry, violations, payloadFnName: payloadFnName, decl: decl);
      _walk(value, registry, violations, payloadFnName: payloadFnName, decl: decl);

    case ThisFieldRefNode():
    case ThisRefNode():
    case LiteralNode():
    case ConstNode():
    case RefNode():
    case BreakNode():
    case ContinueNode():
    case ReturnNode():
    case PayloadInstanceCreationNode():
    case PayloadFieldDeclNode():
    case PayloadCtorNode():
    case PayloadFieldInitNode():
    case PayloadFunctionNode():
    case PayloadClassNode():
    case PayloadMixinNode():
    case PayloadExtensionNode():
    case PayloadFunctionValueNode():
    case ScreenWithFunctionsNode():
    case EventNode():
    case ActionSequenceNode():
    case ActionStepNode():
    case TryStepNode():
    case BlockNode():
    case IfStatementNode():
    case LetStatementNode():
    case WhileNode():
    case DoNode():
    case ImperativeForNode():
    case IrStatefulNode():
    case IrStatefulFieldNode():
      // Leaves or nodes not containing calls.
      break;
  }
}
