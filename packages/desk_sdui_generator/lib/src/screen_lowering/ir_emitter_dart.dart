import 'package:dart_style/dart_style.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'ast_to_ir.dart';

String emitDart(ScreenLowerResult result, {String? partOfUri}) {
  final safeName = result.name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  final partOf = partOfUri != null ? "part of '$partOfUri';" : "part of '';";
  final source = '''
$partOf

ScreenBinding get ${safeName}Binding => ScreenBinding(
  name: ${_dartString(result.name)},
  ir: IrTree(
    name: ${_dartString(result.name)},
    version: 1,
    root: ${_emitNode(result.root)},
  ),
  inputs: ${_buildInputs(result)},
  methodRefs: ${_buildMethodRefs(result)},
  reactives: ${_buildReactives(result)},
);
''';
  return DartFormatter(languageVersion: DartFormatter.latestLanguageVersion).format(source);
}

String _emitNode(IrNode node) {
  switch (node) {
    case LiteralNode():
      return 'LiteralNode(${_dartValue(node.value)})';
    case ConstNode():
      return 'ConstNode(${_dartValue(node.value)})';
    case RefNode():
      final path = _dartList(node.path.map(_dartString));
      return 'RefNode($path${node.reactive ? ', reactive: true' : ''})';
    case EventNode():
      final target = _dartList(node.target.map(_dartString));
      final args = node.args.isEmpty
          ? ''
          : ', args: {${node.args.entries.map((e) => '${_dartString(e.key)}: ${_emitNode(e.value)}').join(', ')}}';
      return 'EventNode($target$args)';
    case WidgetNode():
      final args = '{${node.args.entries.map((e) => '${_dartString(e.key)}: ${_emitNode(e.value)}').join(', ')}}';
      final key = node.key != null ? ', key: ${_emitNode(node.key!)}' : '';
      final listenablePaths = node.listenablePaths.isEmpty
          ? ''
          : ', listenablePaths: {${node.listenablePaths.map(_dartString).join(', ')}}';
      final typeArgs = node.typeArgs != null
          ? ', typeArgs: ${_emitStringList(node.typeArgs!)}'
          : '';
      return 'WidgetNode(name: ${_dartString(node.name)}, args: $args$key$listenablePaths$typeArgs)';
    case BuiltinWidgetNode():
      final args = '{${node.args.entries.map((e) => '${_dartString(e.key)}: ${_emitNode(e.value)}').join(', ')}}';
      final key = node.key != null ? ', key: ${_emitNode(node.key!)}' : '';
      return 'BuiltinWidgetNode(name: ${_dartString(node.name)}, args: $args$key)';
    case ListNode():
      return 'ListNode([${node.children.map(_emitNode).join(', ')}])';
    case MapNode():
      final entries = node.entries.entries
          .map((e) => '${_emitNode(e.key)}: ${_emitNode(e.value)}')
          .join(', ');
      return 'MapNode({$entries})';
    case RecordNode():
      final pos = node.positional.map(_emitNode).join(', ');
      final named = node.named.entries
          .map((e) => '${_dartString(e.key)}: ${_emitNode(e.value)}')
          .join(', ');
      return 'RecordNode(positional: [$pos], named: {$named})';
    case ConditionalNode():
      final elseBranch = node.elseBranch != null ? ', elseBranch: ${_emitNode(node.elseBranch!)}' : '';
      return 'ConditionalNode(condition: ${_emitNode(node.condition)}, thenBranch: ${_emitNode(node.thenBranch)}$elseBranch)';
    case ForNode():
      if (node.variable != null) {
        return 'ForNode(variable: ${_dartString(node.variable!)}, source: ${_emitNode(node.source)}, body: ${_emitNode(node.body)})';
      }
      return 'ForNode.destructured(variables: ${_dartList(node.variables!.map(_dartString))}, source: ${_emitNode(node.source)}, body: ${_emitNode(node.body)})';
    case SpreadNode():
      return 'SpreadNode(${_emitNode(node.source)})';
    case CompareOpNode():
      return 'CompareOpNode(op: CompareOp.${node.op.name}, left: ${_emitNode(node.left)}, right: ${_emitNode(node.right)})';
    case ArithOpNode():
      return 'ArithOpNode(op: ArithOp.${node.op.name}, left: ${_emitNode(node.left)}, right: ${_emitNode(node.right)})';
    case LogicOpNode():
      return 'LogicOpNode(op: LogicOp.${node.op.name}, left: ${_emitNode(node.left)}, right: ${_emitNode(node.right)})';
    case NotOpNode():
      return 'NotOpNode(${_emitNode(node.operand)})';
    case CoalesceOpNode():
      return 'CoalesceOpNode(left: ${_emitNode(node.left)}, right: ${_emitNode(node.right)})';
    case GetterNode():
      return 'GetterNode(receiver: ${_emitNode(node.receiver)}, name: ${_dartString(node.name)})';
    case LetNode():
      return 'LetNode(name: ${_dartString(node.name)}, value: ${_emitNode(node.value)}, body: ${_emitNode(node.body)})';
    case AssignNode():
      return 'AssignNode(name: ${_dartString(node.name)}, value: ${_emitNode(node.value)})';
    case MemberAccessNode():
      return 'MemberAccessNode(target: ${_emitNode(node.target)}, name: ${_dartString(node.name)})';
    case IndexAccessNode():
      return 'IndexAccessNode(target: ${_emitNode(node.target)}, key: ${_emitNode(node.key)})';
    case LengthOfNode():
      return 'LengthOfNode(${_emitNode(node.target)})';
    case IsNullCheckNode():
      return 'IsNullCheckNode(${_emitNode(node.operand)})';
    case IsTypeNode():
      return 'IsTypeNode(receiver: ${_emitNode(node.receiver)}, typeName: ${_dartString(node.typeName)})';
    case StringInterpNode():
      final parts = node.parts.map((p) {
        if (p is IrNode) return _emitNode(p);
        if (p is String) return _dartString(p);
        return p.toString();
      }).join(', ');
      return 'StringInterpNode([$parts])';
    case MethodCallNode():
      final args = node.args.map(_emitNode).join(', ');
      final receiver = node.receiver != null ? _emitNode(node.receiver!) : 'null';
      final typeArgs = node.typeArgs != null
          ? ', typeArgs: ${_emitStringList(node.typeArgs!)}'
          : '';
      return 'MethodCallNode(receiver: $receiver, name: ${_dartString(node.name)}, args: [$args]$typeArgs)';
    case ValueCtorNode():
      final args = node.args.map(_emitNode).join(', ');
      final typeArgs = node.typeArgs != null
          ? ', typeArgs: ${_emitStringList(node.typeArgs!)}'
          : '';
      return 'ValueCtorNode(name: ${_dartString(node.name)}, args: [$args]$typeArgs)';
    case SequenceNode():
      final steps = node.steps.map(_emitNode).join(', ');
      return 'SequenceNode(steps: [$steps], returnExpr: ${_emitNode(node.returnExpr)})';
    case LambdaNode():
      final params = _dartList(node.params.map(_dartString));
      final isAsync = node.isAsync ? ', isAsync: true' : '';
      return 'LambdaNode(params: $params, body: ${_emitNode(node.body)}$isAsync)';
    case ActionSequenceNode():
      final steps = node.steps.map(_emitNode).join(', ');
      return 'ActionSequenceNode(steps: [$steps])';
    case ActionStepNode():
      final bind = node.bindResult != null ? ', bindResult: ${_dartString(node.bindResult!)}' : '';
      return 'ActionStepNode(call: ${_emitNode(node.call)}, awaitResult: ${node.awaitResult}$bind)';
    case TryStepNode():
      final trySteps = node.trySteps.map(_emitNode).join(', ');
      final catchSteps = node.catchSteps.map(_emitNode).join(', ');
      final excBind = node.exceptionBind != null
          ? ', exceptionBind: ${_dartString(node.exceptionBind!)}'
          : '';
      return 'TryStepNode(trySteps: [$trySteps], catchSteps: [$catchSteps]$excBind)';
    case BlockNode():
      final stmts = node.statements.map(_emitNode).join(', ');
      return 'BlockNode(statements: [$stmts])';
    case IfStatementNode():
      final else_ = node.else_ != null ? ', else_: ${_emitNode(node.else_!)}' : '';
      return 'IfStatementNode(cond: ${_emitNode(node.cond)}, then: ${_emitNode(node.then)}$else_)';
    case BreakNode():
      return 'BreakNode()';
    case ContinueNode():
      return 'ContinueNode()';
    case ReturnNode():
      final val = node.value != null ? 'value: ${_emitNode(node.value!)}' : '';
      return 'ReturnNode($val)';
    case LetStatementNode():
      return 'LetStatementNode(name: ${_dartString(node.name)}, value: ${_emitNode(node.value)}, isFinal: ${node.isFinal})';
    case WhileNode():
      return 'WhileNode(condition: ${_emitNode(node.condition)}, body: ${_emitNode(node.body)})';
    case DoNode():
      return 'DoNode(body: ${_emitNode(node.body)}, condition: ${_emitNode(node.condition)})';
    case ImperativeForNode():
      final init = node.init != null ? 'init: ${_emitNode(node.init!)}, ' : '';
      final cond = node.condition != null ? 'condition: ${_emitNode(node.condition!)}, ' : '';
      final upd = node.update != null ? 'update: ${_emitNode(node.update!)}, ' : '';
      return 'ImperativeForNode(${init}${cond}${upd}body: ${_emitNode(node.body)})';
    case IrStatefulNode():
      final fields = node.fields.map(_emitNode).join(', ');
      final id = node.id != null ? 'id: ${_dartString(node.id!)}, ' : '';
      return 'IrStatefulNode(${id}fields: [$fields], body: ${_emitNode(node.body)})';
    case IrStatefulFieldNode():
      return 'IrStatefulFieldNode(name: ${_dartString(node.name)}, initializer: ${_emitNode(node.initializer)}, isFinal: ${node.isFinal})';
  }
}

String _dartString(String s) => "'${s.replaceAll("'", "\\'")}'";

String _dartValue(Object? v) {
  if (v == null) return 'null';
  if (v is String) return _dartString(v);
  if (v is bool) return v.toString();
  if (v is num) return v.toString();
  return v.toString();
}

String _dartList(Iterable<String> items) => '[${items.join(', ')}]';

String _emitStringList(List<String> items) =>
    '[${items.map(_dartString).join(', ')}]';

String _buildInputs(ScreenLowerResult result) {
  if (result.params.isEmpty) return 'const []';
  return '[${result.params.map((p) => 'InputBinding(name: ${_dartString(p.name)}, read: (v) => v as ${p.type})').join(', ')}]';
}

String _buildMethodRefs(ScreenLowerResult result) {
  if (result.methodRefs.isEmpty) return 'const {}';
  final entries = result.methodRefs.entries.map((e) {
    final methods = e.value.map(_dartString).join(', ');
    return '${_dartString(e.key)}: [$methods]';
  }).join(', ');
  return '{$entries}';
}

String _buildReactives(ScreenLowerResult result) {
  if (result.reactiveParams.isEmpty) return 'const []';
  return '[${result.reactiveParams.map((p) => 'ReactiveBinding(path: [$p], read: (input) => throw UnimplementedError())').join(', ')}]';
}
