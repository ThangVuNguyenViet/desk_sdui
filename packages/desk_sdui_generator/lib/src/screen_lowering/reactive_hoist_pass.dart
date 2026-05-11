import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

IrNode reactiveHoist(IrNode node) {
  final (result, _) = _hoist(node);
  return result;
}

(IrNode, Set<String>) _hoist(IrNode node) {
  switch (node) {
    case WidgetNode():
      final newArgs = <String, IrNode>{};
      final allPaths = <String>{};
      for (final entry in node.args.entries) {
        final (child, childPaths) = _hoist(entry.value);
        newArgs[entry.key] = child;
        allPaths.addAll(childPaths);
      }
      final newKey = node.key != null ? _hoist(node.key!).$1 : null;
      final mergedPaths = {...node.listenablePaths, ...allPaths};
      return (
        WidgetNode(
          name: node.name,
          args: newArgs,
          key: newKey,
          listenablePaths: mergedPaths,
        ),
        <String>{},
      );

    case BuiltinWidgetNode():
      final newArgs = <String, IrNode>{};
      for (final entry in node.args.entries) {
        final (child, _) = _hoist(entry.value);
        newArgs[entry.key] = child;
      }
      final newKey = node.key != null ? _hoist(node.key!).$1 : null;
      return (
        BuiltinWidgetNode(name: node.name, args: newArgs, key: newKey),
        <String>{},
      );

    case ListNode():
      final newChildren = <IrNode>[];
      final allPaths = <String>{};
      for (final child in node.children) {
        final (rewritten, paths) = _hoist(child);
        newChildren.add(rewritten);
        allPaths.addAll(paths);
      }
      return (ListNode(newChildren), allPaths);

    case MapNode():
      final newEntries = <IrNode, IrNode>{};
      final allPaths = <String>{};
      for (final entry in node.entries.entries) {
        final (k, kPaths) = _hoist(entry.key);
        final (v, vPaths) = _hoist(entry.value);
        newEntries[k] = v;
        allPaths.addAll(kPaths);
        allPaths.addAll(vPaths);
      }
      return (MapNode(newEntries), allPaths);

    case RecordNode():
      final newPos = <IrNode>[];
      final newNamed = <String, IrNode>{};
      final allPaths = <String>{};
      for (final child in node.positional) {
        final (rewritten, paths) = _hoist(child);
        newPos.add(rewritten);
        allPaths.addAll(paths);
      }
      for (final entry in node.named.entries) {
        final (rewritten, paths) = _hoist(entry.value);
        newNamed[entry.key] = rewritten;
        allPaths.addAll(paths);
      }
      return (RecordNode(positional: newPos, named: newNamed), allPaths);

    case ConditionalNode():
      final (cond, condPaths) = _hoist(node.condition);
      final (then, thenPaths) = _hoist(node.thenBranch);
      final (elseNode, elsePaths) = node.elseBranch != null
          ? _hoist(node.elseBranch!)
          : (null, <String>{});
      final allPaths = {...condPaths, ...thenPaths, ...elsePaths};
      return (
        ConditionalNode(
          condition: cond,
          thenBranch: then,
          elseBranch: elseNode,
        ),
        allPaths,
      );

    case ForNode():
      final (source, sourcePaths) = _hoist(node.source);
      final (body, bodyPaths) = _hoist(node.body);
      if (node.variable != null) {
        return (
          ForNode(
            variable: node.variable!,
            source: source,
            body: body,
          ),
          {...sourcePaths, ...bodyPaths},
        );
      }
      return (
        ForNode.destructured(
          variables: node.variables!,
          source: source,
          body: body,
        ),
        {...sourcePaths, ...bodyPaths},
      );

    case SpreadNode():
      final (source, paths) = _hoist(node.source);
      return (SpreadNode(source), paths);

    case CompareOpNode():
      final (left, leftPaths) = _hoist(node.left);
      final (right, rightPaths) = _hoist(node.right);
      return (
        CompareOpNode(op: node.op, left: left, right: right),
        {...leftPaths, ...rightPaths},
      );

    case ArithOpNode():
      final (left, leftPaths) = _hoist(node.left);
      final (right, rightPaths) = _hoist(node.right);
      return (
        ArithOpNode(op: node.op, left: left, right: right),
        {...leftPaths, ...rightPaths},
      );

    case LogicOpNode():
      final (left, leftPaths) = _hoist(node.left);
      final (right, rightPaths) = _hoist(node.right);
      return (
        LogicOpNode(op: node.op, left: left, right: right),
        {...leftPaths, ...rightPaths},
      );

    case NotOpNode():
      final (operand, paths) = _hoist(node.operand);
      return (NotOpNode(operand), paths);

    case CoalesceOpNode():
      final (left, leftPaths) = _hoist(node.left);
      final (right, rightPaths) = _hoist(node.right);
      return (
        CoalesceOpNode(left: left, right: right),
        {...leftPaths, ...rightPaths},
      );

    case GetterNode():
      final (receiver, paths) = _hoist(node.receiver);
      return (GetterNode(receiver: receiver, name: node.name), paths);

    case MemberAccessNode():
      final (target, paths) = _hoist(node.target);
      return (MemberAccessNode(target: target, name: node.name), paths);

    case IndexAccessNode():
      final (target, targetPaths) = _hoist(node.target);
      final (key, keyPaths) = _hoist(node.key);
      return (
        IndexAccessNode(target: target, key: key),
        {...targetPaths, ...keyPaths},
      );

    case LengthOfNode():
      final (target, paths) = _hoist(node.target);
      return (LengthOfNode(target), paths);

    case IsNullCheckNode():
      final (operand, paths) = _hoist(node.operand);
      return (IsNullCheckNode(operand), paths);

    case StringInterpNode():
      final newParts = <Object>[];
      final allPaths = <String>{};
      for (final part in node.parts) {
        if (part is IrNode) {
          final (rewritten, paths) = _hoist(part);
          newParts.add(rewritten);
          allPaths.addAll(paths);
        } else {
          newParts.add(part);
        }
      }
      return (StringInterpNode(newParts), allPaths);

    case RefNode():
      if (node.reactive) {
        return (node, {node.path.join('.')});
      }
      return (node, <String>{});

    case MethodCallNode():
      final (receiver, receiverPaths) = _hoist(node.receiver);
      final allArgPaths = <String>{};
      final newArgs = <IrNode>[];
      for (final arg in node.args) {
        final (hoisted, paths) = _hoist(arg);
        newArgs.add(hoisted);
        allArgPaths.addAll(paths);
      }
      return (
        MethodCallNode(receiver: receiver, name: node.name, args: newArgs),
        {...receiverPaths, ...allArgPaths},
      );
    case ValueCtorNode():
      final allArgPaths = <String>{};
      final newArgs = <IrNode>[];
      for (final arg in node.args) {
        final (hoisted, paths) = _hoist(arg);
        newArgs.add(hoisted);
        allArgPaths.addAll(paths);
      }
      return (
        ValueCtorNode(name: node.name, args: newArgs),
        allArgPaths,
      );
    case LiteralNode():
    case ConstNode():
    case EventNode():
      return (node, <String>{});
  }
}
