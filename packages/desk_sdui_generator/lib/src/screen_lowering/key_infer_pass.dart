import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

typedef TypeLookup = List<String>? Function(String loopVar);

IrNode inferKeys(IrNode node, {TypeLookup? lookupType}) {
  switch (node) {
    case ForNode():
      final newBody = inferKeys(node.body, lookupType: lookupType);
      final newSource = inferKeys(node.source, lookupType: lookupType);

      if (node.variable != null && newBody is WidgetNode && newBody.key == null) {
        final loopVar = node.variable!;
        final keyNode = _synthesizeKey(loopVar, lookupType);
        if (keyNode != null) {
          return ForNode(
            variable: loopVar,
            source: newSource,
            body: WidgetNode(
              name: newBody.name,
              args: newBody.args,
              key: keyNode,
              listenablePaths: newBody.listenablePaths,
            ),
          );
        }
      }

      if (node.variables != null && newBody is WidgetNode && newBody.key == null) {
        final keyNode = _synthesizeDestructuredKey(node.variables!, lookupType);
        if (keyNode != null) {
          return ForNode.destructured(
            variables: node.variables!,
            source: newSource,
            body: WidgetNode(
              name: newBody.name,
              args: newBody.args,
              key: keyNode,
              listenablePaths: newBody.listenablePaths,
            ),
          );
        }
      }

      return ForNode(
        variable: node.variable!,
        source: newSource,
        body: newBody,
      );

    case WidgetNode():
      final newArgs = <String, IrNode>{};
      for (final entry in node.args.entries) {
        newArgs[entry.key] = inferKeys(entry.value, lookupType: lookupType);
      }
      final newKey = node.key != null ? inferKeys(node.key!, lookupType: lookupType) : null;
      return WidgetNode(
        name: node.name,
        args: newArgs,
        key: newKey,
        listenablePaths: node.listenablePaths,
      );

    case BuiltinWidgetNode():
      final newArgs = <String, IrNode>{};
      for (final entry in node.args.entries) {
        newArgs[entry.key] = inferKeys(entry.value, lookupType: lookupType);
      }
      final newKey = node.key != null ? inferKeys(node.key!, lookupType: lookupType) : null;
      return BuiltinWidgetNode(name: node.name, args: newArgs, key: newKey);

    case ListNode():
      return ListNode(node.children.map((c) => inferKeys(c, lookupType: lookupType)).toList());

    case MapNode():
      final newEntries = <IrNode, IrNode>{};
      for (final entry in node.entries.entries) {
        newEntries[inferKeys(entry.key, lookupType: lookupType)] =
            inferKeys(entry.value, lookupType: lookupType);
      }
      return MapNode(newEntries);

    case RecordNode():
      return RecordNode(
        positional: node.positional.map((c) => inferKeys(c, lookupType: lookupType)).toList(),
        named: node.named.map((k, v) => MapEntry(k, inferKeys(v, lookupType: lookupType))),
      );

    case ConditionalNode():
      return ConditionalNode(
        condition: inferKeys(node.condition, lookupType: lookupType),
        thenBranch: inferKeys(node.thenBranch, lookupType: lookupType),
        elseBranch: node.elseBranch != null
            ? inferKeys(node.elseBranch!, lookupType: lookupType)
            : null,
      );

    case SpreadNode():
      return SpreadNode(inferKeys(node.source, lookupType: lookupType));

    case CompareOpNode():
      return CompareOpNode(
        op: node.op,
        left: inferKeys(node.left, lookupType: lookupType),
        right: inferKeys(node.right, lookupType: lookupType),
      );

    case ArithOpNode():
      return ArithOpNode(
        op: node.op,
        left: inferKeys(node.left, lookupType: lookupType),
        right: inferKeys(node.right, lookupType: lookupType),
      );

    case LogicOpNode():
      return LogicOpNode(
        op: node.op,
        left: inferKeys(node.left, lookupType: lookupType),
        right: inferKeys(node.right, lookupType: lookupType),
      );

    case NotOpNode():
      return NotOpNode(inferKeys(node.operand, lookupType: lookupType));

    case CoalesceOpNode():
      return CoalesceOpNode(
        left: inferKeys(node.left, lookupType: lookupType),
        right: inferKeys(node.right, lookupType: lookupType),
      );

    case GetterNode():
      return GetterNode(
        receiver: inferKeys(node.receiver, lookupType: lookupType),
        name: node.name,
      );

    case MemberAccessNode():
      return MemberAccessNode(
        target: inferKeys(node.target, lookupType: lookupType),
        name: node.name,
      );

    case IndexAccessNode():
      return IndexAccessNode(
        target: inferKeys(node.target, lookupType: lookupType),
        key: inferKeys(node.key, lookupType: lookupType),
      );

    case LengthOfNode():
      return LengthOfNode(inferKeys(node.target, lookupType: lookupType));

    case IsNullCheckNode():
      return IsNullCheckNode(inferKeys(node.operand, lookupType: lookupType));

    case StringInterpNode():
      final newParts = <Object>[];
      for (final part in node.parts) {
        if (part is IrNode) {
          newParts.add(inferKeys(part, lookupType: lookupType));
        } else {
          newParts.add(part);
        }
      }
      return StringInterpNode(newParts);

    case MethodCallNode():
      return MethodCallNode(
        receiver: node.receiver != null ? inferKeys(node.receiver!, lookupType: lookupType) : null,
        name: node.name,
        args: node.args.map((a) => inferKeys(a, lookupType: lookupType)).toList(),
      );
    case ValueCtorNode():
      return ValueCtorNode(
        name: node.name,
        args: node.args.map((a) => inferKeys(a, lookupType: lookupType)).toList(),
      );
    case LiteralNode():
    case ConstNode():
    case RefNode():
    case EventNode():
      return node;
    case ActionSequenceNode():
      return ActionSequenceNode(
        steps: node.steps
            .map((s) => ActionStepNode(
                  call: inferKeys(s.call, lookupType: lookupType),
                  awaitResult: s.awaitResult,
                  bindResult: s.bindResult,
                ))
            .toList(),
      );
    case ActionStepNode():
      return ActionStepNode(
        call: inferKeys(node.call, lookupType: lookupType),
        awaitResult: node.awaitResult,
        bindResult: node.bindResult,
      );
  }
}

IrNode? _synthesizeKey(String loopVar, TypeLookup? lookupType) {
  final fields = lookupType?.call(loopVar);
  if (fields != null && (fields.contains('id') || fields.contains('uuid'))) {
    final idField = fields.contains('id') ? 'id' : 'uuid';
    return WidgetNode(
      name: 'ValueKey',
      args: {
        'arg0': RefNode([loopVar, idField]),
      },
    );
  }
  return null;
}

IrNode? _synthesizeDestructuredKey(List<String> variables, TypeLookup? lookupType) {
  for (final v in variables) {
    final key = _synthesizeKey(v, lookupType);
    if (key != null) return key;
  }
  return null;
}
