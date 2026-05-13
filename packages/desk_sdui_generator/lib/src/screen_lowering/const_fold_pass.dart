import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

IrNode constFold(IrNode node) {
  final folded = _foldChildren(node);
  if (folded is LiteralNode) {
    return ConstNode(folded.value);
  }
  if (_isPureLiteral(folded)) {
    return folded;
  }
  return folded;
}

IrNode _foldChildren(IrNode node) {
  switch (node) {
    case WidgetNode():
      final newArgs = <String, IrNode>{};
      for (final entry in node.args.entries) {
        newArgs[entry.key] = constFold(entry.value);
      }
      final newKey = node.key != null ? constFold(node.key!) : null;
      return WidgetNode(
        name: node.name,
        args: newArgs,
        key: newKey,
        listenablePaths: node.listenablePaths,
      );
    case BuiltinWidgetNode():
      final newArgs = <String, IrNode>{};
      for (final entry in node.args.entries) {
        newArgs[entry.key] = constFold(entry.value);
      }
      final newKey = node.key != null ? constFold(node.key!) : null;
      return BuiltinWidgetNode(
        name: node.name,
        args: newArgs,
        key: newKey,
      );
    case ListNode():
      return ListNode(
        node.children.map(constFold).toList(),
      );
    case MapNode():
      final newEntries = <IrNode, IrNode>{};
      for (final entry in node.entries.entries) {
        newEntries[constFold(entry.key)] = constFold(entry.value);
      }
      return MapNode(newEntries);
    case RecordNode():
      return RecordNode(
        positional: node.positional.map(constFold).toList(),
        named: node.named.map((k, v) => MapEntry(k, constFold(v))),
      );
    case ConditionalNode():
      return ConditionalNode(
        condition: constFold(node.condition),
        thenBranch: constFold(node.thenBranch),
        elseBranch: node.elseBranch != null ? constFold(node.elseBranch!) : null,
      );
    case ForNode():
      if (node.variable != null) {
        return ForNode(
          variable: node.variable!,
          source: constFold(node.source),
          body: constFold(node.body),
        );
      }
      return ForNode.destructured(
        variables: node.variables!,
        source: constFold(node.source),
        body: constFold(node.body),
      );
    case SpreadNode():
      return SpreadNode(constFold(node.source));
    case CompareOpNode():
      return CompareOpNode(
        op: node.op,
        left: constFold(node.left),
        right: constFold(node.right),
      );
    case ArithOpNode():
      return ArithOpNode(
        op: node.op,
        left: constFold(node.left),
        right: constFold(node.right),
      );
    case LogicOpNode():
      return LogicOpNode(
        op: node.op,
        left: constFold(node.left),
        right: constFold(node.right),
      );
    case NotOpNode():
      return NotOpNode(constFold(node.operand));
    case CoalesceOpNode():
      return CoalesceOpNode(
        left: constFold(node.left),
        right: constFold(node.right),
      );
    case GetterNode():
      return GetterNode(
        receiver: constFold(node.receiver),
        name: node.name,
      );
    case SetterCallNode():
      return SetterCallNode(
        target: constFold(node.target),
        setterKey: node.setterKey,
        value: constFold(node.value),
      );
    case LetNode():
      return LetNode(
        name: node.name,
        value: constFold(node.value),
        body: constFold(node.body),
      );
    case AssignNode():
      return AssignNode(name: node.name, value: constFold(node.value));
    case MemberAccessNode():
      return MemberAccessNode(
        target: constFold(node.target),
        name: node.name,
      );
    case IndexAccessNode():
      return IndexAccessNode(
        target: constFold(node.target),
        key: constFold(node.key),
      );
    case LengthOfNode():
      return LengthOfNode(constFold(node.target));
    case IsNullCheckNode():
      return IsNullCheckNode(constFold(node.operand));
    case IsTypeNode():
      return IsTypeNode(receiver: constFold(node.receiver), typeName: node.typeName);
    case StringInterpNode():
      final newParts = <Object>[];
      for (final part in node.parts) {
        if (part is IrNode) {
          newParts.add(constFold(part));
        } else {
          newParts.add(part);
        }
      }
      return StringInterpNode(newParts);
    case MethodCallNode():
      return MethodCallNode(
        receiver: node.receiver != null ? constFold(node.receiver!) : null,
        name: node.name,
        args: node.args.map(constFold).toList(),
      );
    case ValueCtorNode():
      return ValueCtorNode(
        name: node.name,
        args: node.args.map(constFold).toList(),
      );
    case LambdaNode():
      // Lambda bodies are not const-folded (they capture env at resolve time).
      return node;
    case LiteralNode():
    case ConstNode():
    case RefNode():
    case EventNode():
      return node;
    case SequenceNode():
      return SequenceNode(
        steps: node.steps.map(constFold).toList(),
        returnExpr: constFold(node.returnExpr),
      );
    case ActionSequenceNode():
      return ActionSequenceNode(
        steps: node.steps.map(constFold).toList(),
      );
    case ActionStepNode():
      return ActionStepNode(
        call: constFold(node.call),
        awaitResult: node.awaitResult,
        bindResult: node.bindResult,
      );
    case TryStepNode():
      return TryStepNode(
        trySteps: node.trySteps
            .map((s) => ActionStepNode(
                  call: constFold(s.call),
                  awaitResult: s.awaitResult,
                  bindResult: s.bindResult,
                ))
            .toList(),
        catchSteps: node.catchSteps
            .map((s) => ActionStepNode(
                  call: constFold(s.call),
                  awaitResult: s.awaitResult,
                  bindResult: s.bindResult,
                ))
            .toList(),
        exceptionBind: node.exceptionBind,
      );
    case BlockNode():
      return BlockNode(
        statements: node.statements.map(constFold).toList(),
      );
    case IfStatementNode():
      return IfStatementNode(
        cond: constFold(node.cond),
        then: constFold(node.then),
        else_: node.else_ != null ? constFold(node.else_!) : null,
      );
    case BreakNode():
    case ContinueNode():
      return node;
    case ReturnNode():
      return ReturnNode(
        value: node.value != null ? constFold(node.value!) : null,
      );
    case LetStatementNode():
      return LetStatementNode(
        name: node.name,
        value: constFold(node.value),
        isFinal: node.isFinal,
      );
    case WhileNode():
      return WhileNode(
        condition: constFold(node.condition),
        body: constFold(node.body),
      );
    case DoNode():
      return DoNode(
        body: constFold(node.body),
        condition: constFold(node.condition),
      );
    case ImperativeForNode():
      return ImperativeForNode(
        init: node.init != null ? constFold(node.init!) : null,
        condition: node.condition != null ? constFold(node.condition!) : null,
        update: node.update != null ? constFold(node.update!) : null,
        body: constFold(node.body),
      );
    case IrStatefulNode():
      return IrStatefulNode(
        id: node.id,
        fields: node.fields
            .map((f) => IrStatefulFieldNode(
                  name: f.name,
                  initializer: constFold(f.initializer),
                  isFinal: f.isFinal,
                ))
            .toList(),
        body: constFold(node.body),
      );
    case IrStatefulFieldNode():
      return IrStatefulFieldNode(
        name: node.name,
        initializer: constFold(node.initializer),
        isFinal: node.isFinal,
      );
    case PayloadFunctionNode():
      return PayloadFunctionNode(
        name: node.name,
        params: node.params,
        body: constFold(node.body),
      );
    case PayloadFunctionCallNode():
      return PayloadFunctionCallNode(
        name: node.name,
        args: node.args.map(constFold).toList(),
      );
    case ScreenWithFunctionsNode():
      return ScreenWithFunctionsNode(
        functions: node.functions
            .map((f) => PayloadFunctionNode(
                  name: f.name,
                  params: f.params,
                  body: constFold(f.body),
                ))
            .toList(),
        screenBody: constFold(node.screenBody),
      );
  }
}

bool _isPureLiteral(IrNode node) {
  switch (node) {
    case LiteralNode():
    case ConstNode():
      return true;
    case WidgetNode():
    case BuiltinWidgetNode():
    case ListNode():
    case MapNode():
    case RecordNode():
    case ConditionalNode():
    case ForNode():
    case SpreadNode():
    case CompareOpNode():
    case ArithOpNode():
    case LogicOpNode():
    case NotOpNode():
    case CoalesceOpNode():
    case GetterNode():
    case SetterCallNode():
    case LetNode():
    case AssignNode():
    case MemberAccessNode():
    case IndexAccessNode():
    case LengthOfNode():
    case IsNullCheckNode():
    case IsTypeNode():
    case StringInterpNode():
    case LambdaNode():
    case MethodCallNode():
    case ValueCtorNode():
    case SequenceNode():
    case ActionSequenceNode():
    case ActionStepNode():
    case TryStepNode():
    case BlockNode():
    case IfStatementNode():
    case BreakNode():
    case ContinueNode():
    case ReturnNode():
    case LetStatementNode():
    case WhileNode():
    case DoNode():
    case ImperativeForNode():
    case IrStatefulNode():
    case IrStatefulFieldNode():
    case PayloadFunctionNode():
    case PayloadFunctionCallNode():
    case ScreenWithFunctionsNode():
      return false;
    case RefNode():
    case EventNode():
      return false;
  }
}
