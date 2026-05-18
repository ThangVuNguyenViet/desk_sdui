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
    case SetterCallNode():
      return 'SetterCallNode(target: ${_emitNode(node.target)}, setterKey: ${_dartString(node.setterKey)}, value: ${_emitNode(node.value)})';
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
    case AsTypeNode():
      return 'AsTypeNode(operand: ${_emitNode(node.operand)}, typeName: ${_dartString(node.typeName)}, nullable: ${node.nullable})';
    case RuntimeTypeRefNode():
      return 'RuntimeTypeRefNode(operand: ${_emitNode(node.operand)})';
    case PayloadMethodCallNode():
      final args = node.args.entries.map((e) => '${_dartString(e.key)}: ${_emitNode(e.value)}').join(', ');
      return 'PayloadMethodCallNode(receiver: ${_emitNode(node.receiver)}, methodName: ${_dartString(node.methodName)}, args: {$args})';
    case PayloadFieldRefNode():
      return 'PayloadFieldRefNode(receiver: ${_emitNode(node.receiver)}, fieldName: ${_dartString(node.fieldName)})';
    case PayloadFieldAssignNode():
      return 'PayloadFieldAssignNode(receiver: ${_emitNode(node.receiver)}, fieldName: ${_dartString(node.fieldName)}, value: ${_emitNode(node.value)})';
    case ThisFieldRefNode():
      return 'ThisFieldRefNode(fieldName: ${_dartString(node.fieldName)})';
    case ThisRefNode():
      return 'const ThisRefNode()';
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
    case PayloadFunctionNode():
      final params = _dartList(node.params.map(_dartString));
      return 'PayloadFunctionNode(name: ${_dartString(node.name)}, params: $params, body: ${_emitNode(node.body)})';
    case PayloadFunctionCallNode():
      final args = node.args.map(_emitNode).join(', ');
      return 'PayloadFunctionCallNode(name: ${_dartString(node.name)}, args: [$args])';
    case ScreenWithFunctionsNode():
      final fns = node.functions.map(_emitNode).join(', ');
      final classes = node.classes.map(_emitNode).join(', ');
      final mixins = node.mixins.map(_emitNode).join(', ');
      final extensions = node.extensions.map(_emitNode).join(', ');
      final classesStr = node.classes.isEmpty ? '' : ', classes: [$classes]';
      final mixinsStr = node.mixins.isEmpty ? '' : ', mixins: [$mixins]';
      final extensionsStr = node.extensions.isEmpty ? '' : ', extensions: [$extensions]';
      return 'ScreenWithFunctionsNode(functions: [$fns]$classesStr$mixinsStr$extensionsStr, screenBody: ${_emitNode(node.screenBody)})';
    case PayloadFunctionValueNode():
      final fnName = node.functionName != null ? 'functionName: ${_dartString(node.functionName!)}' : '';
      final lambdaStr = node.lambda != null ? ', lambda: ${_emitNode(node.lambda!)}' : '';
      final tearoffReceiver = node.methodTearoffReceiver != null ? ', methodTearoffReceiver: ${_emitNode(node.methodTearoffReceiver!)}' : '';
      final tearoffName = node.methodTearoffName != null ? ', methodTearoffName: ${_dartString(node.methodTearoffName!)}' : '';
      final captured = node.capturedEnvKeys.isNotEmpty ? ', capturedEnvKeys: ${_dartList(node.capturedEnvKeys.map(_dartString))}' : '';
      return 'PayloadFunctionValueNode($fnName$lambdaStr$tearoffReceiver$tearoffName$captured)';
    case PayloadExtensionNode():
      final methods = node.methods.map(_emitNode).join(', ');
      return 'PayloadExtensionNode(name: ${_dartString(node.name)}, targetTypeName: ${_dartString(node.targetTypeName)}, methods: [$methods])';
    case PayloadMixinNode():
      final onTypes = _dartList(node.onTypes.map(_dartString));
      final fields = node.fields.map(_emitNode).join(', ');
      final methods = node.methods.map(_emitNode).join(', ');
      return 'PayloadMixinNode(name: ${_dartString(node.name)}, onTypes: $onTypes, fields: [$fields], methods: [$methods])';
    case PayloadClassNode():
      final supertypeStr = node.supertypeName != null ? ', supertypeName: ${_dartString(node.supertypeName!)}' : '';
      final mixins = _dartList(node.mixinNames.map(_dartString));
      final fields = node.fields.map(_emitNode).join(', ');
      final ctors = node.ctors.map(_emitNode).join(', ');
      final methods = node.methods.map(_emitNode).join(', ');
      return 'PayloadClassNode(name: ${_dartString(node.name)}$supertypeStr, mixinNames: $mixins, fields: [$fields], ctors: [$ctors], methods: [$methods])';
    case PayloadInstanceCreationNode():
      final args = _dartMap(node.args.entries.map((e) => MapEntry(_dartString(e.key), _emitNode(e.value))));
      return 'PayloadInstanceCreationNode(className: ${_dartString(node.className)}, ctorName: ${_dartString(node.ctorName)}, args: $args)';
    case PayloadFieldDeclNode():
      final initStr = node.initializer != null ? ', initializer: ${_emitNode(node.initializer!)}' : '';
      return 'PayloadFieldDeclNode(name: ${_dartString(node.name)}$initStr, isFinal: ${node.isFinal})';
    case PayloadCtorNode():
      final params = _dartList(node.params.map(_dartString));
      final fieldInits = node.fieldInits.map(_emitNode).join(', ');
      final bodyStr = node.body != null ? ', body: ${_emitNode(node.body!)}' : '';
      return 'PayloadCtorNode(name: ${_dartString(node.name)}, params: $params, fieldInits: [$fieldInits]$bodyStr)';
    case PayloadFieldInitNode():
      return 'PayloadFieldInitNode(fieldName: ${_dartString(node.fieldName)}, value: ${_emitNode(node.value)})';
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

String _dartMap(Iterable<MapEntry<String, String>> entries) =>
    '{${entries.map((e) => '${e.key}: ${e.value}').join(', ')}}';

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
