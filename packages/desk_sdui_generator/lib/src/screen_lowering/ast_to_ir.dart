import 'package:analyzer/dart/ast/ast.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import '../diagnostics.dart';
import 'widget_lowerer.dart';
import 'expression_lowerer.dart';

class ScreenLowerResult {
  ScreenLowerResult({
    required this.name,
    required this.root,
    required this.params,
    required this.reactiveParams,
    required this.methodRefs,
    required this.widgetRefs,
    required this.fnRefs,
  });

  final String name;
  final IrNode root;
  final List<({String name, String type})> params;
  final List<String> reactiveParams;

  /// Method references indexed by input name.
  /// e.g. `{'vm': ['increment', 'decrement']}`
  final Map<String, List<String>> methodRefs;
  final Set<String> widgetRefs;
  final Set<String> fnRefs;

  ScreenLowerResult copyWith({IrNode? root}) {
    return ScreenLowerResult(
      name: name,
      root: root ?? this.root,
      params: params,
      reactiveParams: reactiveParams,
      methodRefs: methodRefs,
      widgetRefs: widgetRefs,
      fnRefs: fnRefs,
    );
  }
}

class ScreenAnnotationData {
  ScreenAnnotationData({required this.name});
  final String name;
}

ScreenLowerResult lowerScreen(FunctionDeclaration fn, ScreenAnnotationData ann) {
  final body = fn.functionExpression.body;
  if (body is! ExpressionFunctionBody) {
    throw LoweringError('@Screen function must be `=>`-bodied', fn);
  }

  final expr = body.expression;
  final IrNode rootIr;
  if (expr is InstanceCreationExpression) {
    rootIr = lowerWidgetInstance(expr);
  } else if (expr is MethodInvocation && expr.target == null) {
    final name = expr.methodName.name;
    if (name.isNotEmpty && name[0] == name[0].toUpperCase()) {
      rootIr = lowerWidgetInvocation(expr);
    } else {
      rootIr = lowerExpression(expr);
    }
  } else {
    rootIr = lowerExpression(expr);
  }

  final params = <({String name, String type})>[];
  for (final p in fn.functionExpression.parameters!.parameters) {
    final paramName = p.name!.lexeme;
    final paramType = 'dynamic';
    params.add((name: paramName, type: paramType));
  }

  final reactiveParams = <String>[];
  final widgetRefs = <String>{};
  final methodRefs = <String, List<String>>{};
  final fnRefs = <String>{};

  _collectRefs(rootIr, widgetRefs, methodRefs, fnRefs);

  return ScreenLowerResult(
    name: ann.name,
    root: rootIr,
    params: params,
    reactiveParams: reactiveParams,
    methodRefs: methodRefs,
    widgetRefs: widgetRefs,
    fnRefs: fnRefs,
  );
}

void _collectRefs(
  IrNode node,
  Set<String> widgetRefs,
  Map<String, List<String>> methodRefs,
  Set<String> fnRefs,
) {
  switch (node) {
    case WidgetNode():
      widgetRefs.add(node.name);
      for (final child in node.args.values) {
        _collectRefs(child, widgetRefs, methodRefs, fnRefs);
      }
      if (node.key != null) {
        _collectRefs(node.key!, widgetRefs, methodRefs, fnRefs);
      }
    case BuiltinWidgetNode():
      for (final child in node.args.values) {
        _collectRefs(child, widgetRefs, methodRefs, fnRefs);
      }
      if (node.key != null) {
        _collectRefs(node.key!, widgetRefs, methodRefs, fnRefs);
      }
    case ListNode():
      for (final child in node.children) {
        _collectRefs(child, widgetRefs, methodRefs, fnRefs);
      }
    case MapNode():
      for (final entry in node.entries.entries) {
        _collectRefs(entry.key, widgetRefs, methodRefs, fnRefs);
        _collectRefs(entry.value, widgetRefs, methodRefs, fnRefs);
      }
    case RecordNode():
      for (final child in node.positional) {
        _collectRefs(child, widgetRefs, methodRefs, fnRefs);
      }
      for (final child in node.named.values) {
        _collectRefs(child, widgetRefs, methodRefs, fnRefs);
      }
    case ConditionalNode():
      _collectRefs(node.condition, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.thenBranch, widgetRefs, methodRefs, fnRefs);
      if (node.elseBranch != null) {
        _collectRefs(node.elseBranch!, widgetRefs, methodRefs, fnRefs);
      }
    case ForNode():
      _collectRefs(node.source, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.body, widgetRefs, methodRefs, fnRefs);
    case SpreadNode():
      _collectRefs(node.source, widgetRefs, methodRefs, fnRefs);
    case EventNode():
      if (node.target.length >= 2) {
        final inputName = node.target.first;
        final methodName = node.target.last;
        methodRefs.putIfAbsent(inputName, () => []);
        if (!methodRefs[inputName]!.contains(methodName)) {
          methodRefs[inputName]!.add(methodName);
        }
      }
      for (final arg in node.args.values) {
        _collectRefs(arg, widgetRefs, methodRefs, fnRefs);
      }
    case CompareOpNode():
      _collectRefs(node.left, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.right, widgetRefs, methodRefs, fnRefs);
    case ArithOpNode():
      _collectRefs(node.left, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.right, widgetRefs, methodRefs, fnRefs);
    case LogicOpNode():
      _collectRefs(node.left, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.right, widgetRefs, methodRefs, fnRefs);
    case NotOpNode():
      _collectRefs(node.operand, widgetRefs, methodRefs, fnRefs);
    case CoalesceOpNode():
      _collectRefs(node.left, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.right, widgetRefs, methodRefs, fnRefs);
    case GetterNode():
      _collectRefs(node.receiver, widgetRefs, methodRefs, fnRefs);
    case MemberAccessNode():
      _collectRefs(node.target, widgetRefs, methodRefs, fnRefs);
    case IndexAccessNode():
      _collectRefs(node.target, widgetRefs, methodRefs, fnRefs);
      _collectRefs(node.key, widgetRefs, methodRefs, fnRefs);
    case LengthOfNode():
      _collectRefs(node.target, widgetRefs, methodRefs, fnRefs);
    case IsNullCheckNode():
      _collectRefs(node.operand, widgetRefs, methodRefs, fnRefs);
    case StringInterpNode():
      for (final part in node.parts) {
        if (part is IrNode) {
          _collectRefs(part, widgetRefs, methodRefs, fnRefs);
        }
      }
    case MethodCallNode():
      if (node.receiver != null) {
        _collectRefs(node.receiver!, widgetRefs, methodRefs, fnRefs);
      }
      for (final arg in node.args) {
        _collectRefs(arg, widgetRefs, methodRefs, fnRefs);
      }
    case ValueCtorNode():
      for (final arg in node.args) {
        _collectRefs(arg, widgetRefs, methodRefs, fnRefs);
      }
    case LiteralNode():
    case ConstNode():
    case RefNode():
      break;
  }
}
