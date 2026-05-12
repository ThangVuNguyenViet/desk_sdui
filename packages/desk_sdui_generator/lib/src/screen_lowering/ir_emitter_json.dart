import 'dart:convert';

import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

Map<String, Object?> emitJsonMap(IrTree tree) {
  final codec = const JsonIrCodec();
  final demotedRoot = _demoteAllConst(tree.root);
  return <String, Object?>{
    'name': tree.name,
    'version': tree.version,
    'root': codec.encode(demotedRoot),
  };
}

List<int> emitJson(IrTree tree) {
  final map = emitJsonMap(tree);
  return utf8.encode(jsonEncode(map));
}

IrNode _demoteAllConst(IrNode node) {
  switch (node) {
    case ConstNode():
      final value = node.value;
      if (value == null || value is bool || value is num || value is String) {
        return LiteralNode(value);
      }
      return LiteralNode('const:${value.runtimeType}');
    case WidgetNode():
      return WidgetNode(
        name: node.name,
        args: node.args.map((k, v) => MapEntry(k, _demoteAllConst(v))),
        key: node.key != null ? _demoteAllConst(node.key!) : null,
        listenablePaths: node.listenablePaths,
      );
    case BuiltinWidgetNode():
      return BuiltinWidgetNode(
        name: node.name,
        args: node.args.map((k, v) => MapEntry(k, _demoteAllConst(v))),
        key: node.key != null ? _demoteAllConst(node.key!) : null,
      );
    case ListNode():
      return ListNode(node.children.map(_demoteAllConst).toList());
    case MapNode():
      return MapNode(
        node.entries.map((k, v) => MapEntry(_demoteAllConst(k), _demoteAllConst(v))),
      );
    case RecordNode():
      return RecordNode(
        positional: node.positional.map(_demoteAllConst).toList(),
        named: node.named.map((k, v) => MapEntry(k, _demoteAllConst(v))),
      );
    case ConditionalNode():
      return ConditionalNode(
        condition: _demoteAllConst(node.condition),
        thenBranch: _demoteAllConst(node.thenBranch),
        elseBranch: node.elseBranch != null ? _demoteAllConst(node.elseBranch!) : null,
      );
    case ForNode():
      if (node.variable != null) {
        return ForNode(
          variable: node.variable!,
          source: _demoteAllConst(node.source),
          body: _demoteAllConst(node.body),
        );
      }
      return ForNode.destructured(
        variables: node.variables!,
        source: _demoteAllConst(node.source),
        body: _demoteAllConst(node.body),
      );
    case SpreadNode():
      return SpreadNode(_demoteAllConst(node.source));
    case CompareOpNode():
      return CompareOpNode(
        op: node.op,
        left: _demoteAllConst(node.left),
        right: _demoteAllConst(node.right),
      );
    case ArithOpNode():
      return ArithOpNode(
        op: node.op,
        left: _demoteAllConst(node.left),
        right: _demoteAllConst(node.right),
      );
    case LogicOpNode():
      return LogicOpNode(
        op: node.op,
        left: _demoteAllConst(node.left),
        right: _demoteAllConst(node.right),
      );
    case NotOpNode():
      return NotOpNode(_demoteAllConst(node.operand));
    case CoalesceOpNode():
      return CoalesceOpNode(
        left: _demoteAllConst(node.left),
        right: _demoteAllConst(node.right),
      );
    case GetterNode():
      return GetterNode(
        receiver: _demoteAllConst(node.receiver),
        name: node.name,
      );
    case LetNode():
      return LetNode(
        name: node.name,
        value: _demoteAllConst(node.value),
        body: _demoteAllConst(node.body),
      );
    case AssignNode():
      return AssignNode(name: node.name, value: _demoteAllConst(node.value));
    case MemberAccessNode():
      return MemberAccessNode(
        target: _demoteAllConst(node.target),
        name: node.name,
      );
    case IndexAccessNode():
      return IndexAccessNode(
        target: _demoteAllConst(node.target),
        key: _demoteAllConst(node.key),
      );
    case LengthOfNode():
      return LengthOfNode(_demoteAllConst(node.target));
    case IsNullCheckNode():
      return IsNullCheckNode(_demoteAllConst(node.operand));
    case IsTypeNode():
      return IsTypeNode(receiver: _demoteAllConst(node.receiver), typeName: node.typeName);
    case StringInterpNode():
      return StringInterpNode(
        node.parts.map((p) => p is IrNode ? _demoteAllConst(p) : p).toList(),
      );
    case MethodCallNode():
      return MethodCallNode(
        receiver: node.receiver != null ? _demoteAllConst(node.receiver!) : null,
        name: node.name,
        args: node.args.map(_demoteAllConst).toList(),
      );
    case ValueCtorNode():
      return ValueCtorNode(
        name: node.name,
        args: node.args.map(_demoteAllConst).toList(),
      );
    case SequenceNode():
      return SequenceNode(
        steps: node.steps.map(_demoteAllConst).toList(),
        returnExpr: _demoteAllConst(node.returnExpr),
      );
    case LambdaNode():
      return LambdaNode(
        params: node.params,
        body: _demoteAllConst(node.body),
        isAsync: node.isAsync,
      );
    case RefNode():
    case LiteralNode():
    case EventNode():
      return node;
    case ActionSequenceNode():
      return ActionSequenceNode(
        steps: node.steps.map(_demoteAllConst).toList(),
      );
    case ActionStepNode():
      return ActionStepNode(
        call: _demoteAllConst(node.call),
        awaitResult: node.awaitResult,
        bindResult: node.bindResult,
      );
    case TryStepNode():
      return TryStepNode(
        trySteps: node.trySteps
            .map((s) => ActionStepNode(
                  call: _demoteAllConst(s.call),
                  awaitResult: s.awaitResult,
                  bindResult: s.bindResult,
                ))
            .toList(),
        catchSteps: node.catchSteps
            .map((s) => ActionStepNode(
                  call: _demoteAllConst(s.call),
                  awaitResult: s.awaitResult,
                  bindResult: s.bindResult,
                ))
            .toList(),
        exceptionBind: node.exceptionBind,
      );
    case BlockNode():
      return BlockNode(
        statements: node.statements.map(_demoteAllConst).toList(),
      );
    case IfStatementNode():
      return IfStatementNode(
        cond: _demoteAllConst(node.cond),
        then: _demoteAllConst(node.then),
        else_: node.else_ != null ? _demoteAllConst(node.else_!) : null,
      );
    case BreakNode():
    case ContinueNode():
      return node;
    case ReturnNode():
      return ReturnNode(
        value: node.value != null ? _demoteAllConst(node.value!) : null,
      );
    case LetStatementNode():
      return LetStatementNode(
        name: node.name,
        value: _demoteAllConst(node.value),
        isFinal: node.isFinal,
      );
    case WhileNode():
      return WhileNode(
        condition: _demoteAllConst(node.condition),
        body: _demoteAllConst(node.body),
      );
    case DoNode():
      return DoNode(
        body: _demoteAllConst(node.body),
        condition: _demoteAllConst(node.condition),
      );
    case ImperativeForNode():
      return ImperativeForNode(
        init: node.init != null ? _demoteAllConst(node.init!) : null,
        condition: node.condition != null ? _demoteAllConst(node.condition!) : null,
        update: node.update != null ? _demoteAllConst(node.update!) : null,
        body: _demoteAllConst(node.body),
      );
  }
}
