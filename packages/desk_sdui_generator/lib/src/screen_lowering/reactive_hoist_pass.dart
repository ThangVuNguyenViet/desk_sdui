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

    case LetNode():
      final (value, valuePaths) = _hoist(node.value);
      final (body, bodyPaths) = _hoist(node.body);
      return (
        LetNode(name: node.name, value: value, body: body),
        {...valuePaths, ...bodyPaths},
      );
    case AssignNode():
      final (value, valuePaths) = _hoist(node.value);
      return (AssignNode(name: node.name, value: value), valuePaths);

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

    case IsTypeNode():
      final (receiver, paths) = _hoist(node.receiver);
      return (IsTypeNode(receiver: receiver, typeName: node.typeName), paths);

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
      final (receiver, receiverPaths) = node.receiver != null ? _hoist(node.receiver!) : (null, <String>{});
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
    case LambdaNode():
      // Lambda bodies capture env at resolve time; we don't hoist reactive
      // paths out of them (they're invoked on demand, not per-frame).
      return (node, <String>{});
    case LiteralNode():
    case ConstNode():
    case EventNode():
      return (node, <String>{});
    case SequenceNode():
      final allStepPaths = <String>{};
      final newSteps = <IrNode>[];
      for (final step in node.steps) {
        final (hoisted, paths) = _hoist(step);
        newSteps.add(hoisted);
        allStepPaths.addAll(paths);
      }
      final (returnExpr, returnPaths) = _hoist(node.returnExpr);
      return (
        SequenceNode(steps: newSteps, returnExpr: returnExpr),
        {...allStepPaths, ...returnPaths},
      );
    case ActionSequenceNode():
      // ActionSequenceNode steps run at event time, not during build —
      // no reactive paths to hoist from them.
      return (node, <String>{});
    case ActionStepNode():
      return (node, <String>{});
    case TryStepNode():
      return (node, <String>{});
    case BlockNode():
      final allPaths = <String>{};
      final newStmts = <IrNode>[];
      for (final s in node.statements) {
        final (rewritten, paths) = _hoist(s);
        newStmts.add(rewritten);
        allPaths.addAll(paths);
      }
      return (BlockNode(statements: newStmts), allPaths);
    case IfStatementNode():
      final (cond, condPaths) = _hoist(node.cond);
      final (then, thenPaths) = _hoist(node.then);
      final (else_, elsePaths) = node.else_ != null
          ? _hoist(node.else_!)
          : (null as IrNode?, <String>{});
      return (
        IfStatementNode(cond: cond, then: then, else_: else_),
        {...condPaths, ...thenPaths, ...elsePaths},
      );
    case BreakNode():
    case ContinueNode():
      return (node, <String>{});
    case ReturnNode():
      if (node.value != null) {
        final (val, paths) = _hoist(node.value!);
        return (ReturnNode(value: val), paths);
      }
      return (node, <String>{});
    case LetStatementNode():
      final (val, paths) = _hoist(node.value);
      return (
        LetStatementNode(name: node.name, value: val, isFinal: node.isFinal),
        paths,
      );
    case WhileNode():
      final (cond, condPaths) = _hoist(node.condition);
      final (body, bodyPaths) = _hoist(node.body);
      return (
        WhileNode(condition: cond, body: body),
        {...condPaths, ...bodyPaths},
      );
    case DoNode():
      final (body, bodyPaths) = _hoist(node.body);
      final (cond, condPaths) = _hoist(node.condition);
      return (
        DoNode(body: body, condition: cond),
        {...bodyPaths, ...condPaths},
      );
    case ImperativeForNode():
      final (init, initPaths) = node.init != null
          ? _hoist(node.init!)
          : (null as IrNode?, <String>{});
      final (cond, condPaths) = node.condition != null
          ? _hoist(node.condition!)
          : (null as IrNode?, <String>{});
      final (upd, updPaths) = node.update != null
          ? _hoist(node.update!)
          : (null as IrNode?, <String>{});
      final (body, bodyPaths) = _hoist(node.body);
      return (
        ImperativeForNode(
          init: init,
          condition: cond,
          update: upd,
          body: body,
        ),
        {...initPaths, ...condPaths, ...updPaths, ...bodyPaths},
      );
    case IrStatefulNode():
      // Field initializers run once in initState; no reactive hoisting needed
      // (rebuild on signal change is driven by the body, not the fields).
      final newFields = <IrStatefulFieldNode>[];
      for (final f in node.fields) {
        final (initRewritten, _) = _hoist(f.initializer);
        newFields.add(IrStatefulFieldNode(
          name: f.name,
          initializer: initRewritten,
          isFinal: f.isFinal,
        ));
      }
      final (body, bodyPaths) = _hoist(node.body);
      return (
        IrStatefulNode(fields: newFields, body: body),
        bodyPaths,
      );
    case IrStatefulFieldNode():
      final (initRewritten, paths) = _hoist(node.initializer);
      return (
        IrStatefulFieldNode(
          name: node.name,
          initializer: initRewritten,
          isFinal: node.isFinal,
        ),
        paths,
      );
  }
}
