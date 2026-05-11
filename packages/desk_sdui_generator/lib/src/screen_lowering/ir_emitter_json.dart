import 'dart:convert';

import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

List<int> emitJson(IrTree tree) {
  final codec = const JsonIrCodec();
  final demotedRoot = _demoteAllConst(tree.root);
  final map = <String, Object?>{
    'name': tree.name,
    'version': tree.version,
    'root': codec.encode(demotedRoot),
  };
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
    case RefNode():
    case LiteralNode():
    case EventNode():
      return node;
  }
}
