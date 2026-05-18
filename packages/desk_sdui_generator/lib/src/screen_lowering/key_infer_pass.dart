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

      if (node.variable != null) {
        return ForNode(variable: node.variable!, source: newSource, body: newBody);
      } else {
        return ForNode.destructured(variables: node.variables!, source: newSource, body: newBody);
      }

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

    case SetterCallNode():
      return SetterCallNode(
        target: inferKeys(node.target, lookupType: lookupType),
        setterKey: node.setterKey,
        value: inferKeys(node.value, lookupType: lookupType),
      );

    case LetNode():
      return LetNode(
        name: node.name,
        value: inferKeys(node.value, lookupType: lookupType),
        body: inferKeys(node.body, lookupType: lookupType),
      );
    case AssignNode():
      return AssignNode(
        name: node.name,
        value: inferKeys(node.value, lookupType: lookupType),
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

    case IsTypeNode():
      return IsTypeNode(
        receiver: inferKeys(node.receiver, lookupType: lookupType),
        typeName: node.typeName,
      );

    case AsTypeNode():
      return node;
    case ThisFieldRefNode():
    case ThisRefNode():
      return node;
    case PayloadFieldAssignNode():
      return PayloadFieldAssignNode(
        receiver: inferKeys(node.receiver, lookupType: lookupType),
        fieldName: node.fieldName,
        value: inferKeys(node.value, lookupType: lookupType),
      );
    case PayloadFieldRefNode():
      return PayloadFieldRefNode(
        receiver: inferKeys(node.receiver, lookupType: lookupType),
        fieldName: node.fieldName,
      );
    case PayloadMethodCallNode():
      return PayloadMethodCallNode(
        receiver: inferKeys(node.receiver, lookupType: lookupType),
        methodName: node.methodName,
        args: node.args.map((k, v) => MapEntry(k, inferKeys(v, lookupType: lookupType))),
      );
    case RuntimeTypeRefNode():
      return RuntimeTypeRefNode(
        operand: inferKeys(node.operand, lookupType: lookupType),
      );

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
        typeArgs: node.typeArgs,
      );
    case ValueCtorNode():
      return ValueCtorNode(
        name: node.name,
        args: node.args.map((a) => inferKeys(a, lookupType: lookupType)).toList(),
        typeArgs: node.typeArgs,
      );
    case SequenceNode():
      return SequenceNode(
        steps: node.steps.map((s) => inferKeys(s, lookupType: lookupType)).toList(),
        returnExpr: inferKeys(node.returnExpr, lookupType: lookupType),
      );
    case LambdaNode():
      // Lambda bodies are not traversed for key inference — the body is
      // evaluated at invocation time, not in a for-loop context.
      return node;
    case LiteralNode():
    case ConstNode():
    case RefNode():
    case EventNode():
      return node;
    case ActionSequenceNode():
      return ActionSequenceNode(
        steps: node.steps
            .map((s) => inferKeys(s, lookupType: lookupType))
            .toList(),
      );
    case ActionStepNode():
      return ActionStepNode(
        call: inferKeys(node.call, lookupType: lookupType),
        awaitResult: node.awaitResult,
        bindResult: node.bindResult,
      );
    case TryStepNode():
      return TryStepNode(
        trySteps: node.trySteps
            .map((s) => ActionStepNode(
                  call: inferKeys(s.call, lookupType: lookupType),
                  awaitResult: s.awaitResult,
                  bindResult: s.bindResult,
                ))
            .toList(),
        catchSteps: node.catchSteps
            .map((s) => ActionStepNode(
                  call: inferKeys(s.call, lookupType: lookupType),
                  awaitResult: s.awaitResult,
                  bindResult: s.bindResult,
                ))
            .toList(),
        exceptionBind: node.exceptionBind,
      );
    case BlockNode():
      return BlockNode(
        statements: node.statements
            .map((s) => inferKeys(s, lookupType: lookupType))
            .toList(),
      );
    case IfStatementNode():
      return IfStatementNode(
        cond: inferKeys(node.cond, lookupType: lookupType),
        then: inferKeys(node.then, lookupType: lookupType),
        else_: node.else_ != null
            ? inferKeys(node.else_!, lookupType: lookupType)
            : null,
      );
    case BreakNode():
    case ContinueNode():
      return node;
    case ReturnNode():
      return ReturnNode(
        value: node.value != null
            ? inferKeys(node.value!, lookupType: lookupType)
            : null,
      );
    case LetStatementNode():
      return LetStatementNode(
        name: node.name,
        value: inferKeys(node.value, lookupType: lookupType),
        isFinal: node.isFinal,
      );
    case WhileNode():
      return WhileNode(
        condition: inferKeys(node.condition, lookupType: lookupType),
        body: inferKeys(node.body, lookupType: lookupType),
      );
    case DoNode():
      return DoNode(
        body: inferKeys(node.body, lookupType: lookupType),
        condition: inferKeys(node.condition, lookupType: lookupType),
      );
    case ImperativeForNode():
      return ImperativeForNode(
        init: node.init != null
            ? inferKeys(node.init!, lookupType: lookupType)
            : null,
        condition: node.condition != null
            ? inferKeys(node.condition!, lookupType: lookupType)
            : null,
        update: node.update != null
            ? inferKeys(node.update!, lookupType: lookupType)
            : null,
        body: inferKeys(node.body, lookupType: lookupType),
      );
    case IrStatefulNode():
      return IrStatefulNode(
        id: node.id,
        fields: node.fields
            .map((f) => IrStatefulFieldNode(
                  name: f.name,
                  initializer: inferKeys(f.initializer, lookupType: lookupType),
                  isFinal: f.isFinal,
                ))
            .toList(),
        body: inferKeys(node.body, lookupType: lookupType),
      );
    case IrStatefulFieldNode():
      return IrStatefulFieldNode(
        name: node.name,
        initializer: inferKeys(node.initializer, lookupType: lookupType),
        isFinal: node.isFinal,
      );
    case PayloadFunctionNode():
      return PayloadFunctionNode(
        name: node.name,
        params: node.params,
        body: inferKeys(node.body, lookupType: lookupType),
      );
    case PayloadFunctionCallNode():
      return PayloadFunctionCallNode(
        name: node.name,
        args: node.args.map((a) => inferKeys(a, lookupType: lookupType)).toList(),
      );
    case ScreenWithFunctionsNode():
      return ScreenWithFunctionsNode(
        functions: node.functions
            .map((f) => PayloadFunctionNode(
                  name: f.name,
                  params: f.params,
                  body: inferKeys(f.body, lookupType: lookupType),
                ))
            .toList(),
        classes: node.classes,
        screenBody: inferKeys(node.screenBody, lookupType: lookupType),
      );
    case PayloadFunctionValueNode():
      // Function values are metadata; treated like extension declarations.
      return node;
    case PayloadExtensionNode():
      // Extension declarations are metadata; treated like mixin declarations.
      return node;
    case PayloadMixinNode():
      // Mixin declarations are metadata; treated like class declarations.
      return node;
    case PayloadClassNode():
      // Payload class declarations are metadata; not transformed.
      return node;
    case PayloadInstanceCreationNode():
      return PayloadInstanceCreationNode(
        className: node.className,
        ctorName: node.ctorName,
        args: node.args.map((k, v) => MapEntry(k, inferKeys(v, lookupType: lookupType))),
      );
    case PayloadFieldDeclNode():
      return PayloadFieldDeclNode(
        name: node.name,
        initializer: node.initializer != null ? inferKeys(node.initializer!, lookupType: lookupType) : null,
        isFinal: node.isFinal,
      );
    case PayloadCtorNode():
      return PayloadCtorNode(
        name: node.name,
        params: node.params,
        fieldInits: node.fieldInits.map((f) => PayloadFieldInitNode(
          fieldName: f.fieldName,
          value: inferKeys(f.value, lookupType: lookupType),
        )).toList(),
        body: node.body != null ? inferKeys(node.body!, lookupType: lookupType) : null,
      );
    case PayloadFieldInitNode():
      return PayloadFieldInitNode(
        fieldName: node.fieldName,
        value: inferKeys(node.value, lookupType: lookupType),
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
