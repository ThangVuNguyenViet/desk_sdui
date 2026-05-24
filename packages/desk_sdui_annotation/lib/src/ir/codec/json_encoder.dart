import 'package:desk_sdui_annotation/src/ir/ir_node.dart';
import 'package:desk_sdui_annotation/src/ir/codec/ir_node_type.dart';

/// Encodes an IR tree to JSON-serializable maps. Every node carries a
/// `$type` discriminator. Constructors (e.g., `EdgeInsets.all(8)`) encoded
/// as `LiteralNode` values are NOT supported by this codec — only scalars
/// (bool/int/double/String/null). Constructed-value `LiteralNode`s and
/// `ConstNode`s use a stable string id resolved by the runtime registry.
class JsonIrEncoder {
  const JsonIrEncoder();

  Map<String, Object?> encode(IrNode node) => _encodeNode(node);

  Map<String, Object?> _encodeNode(IrNode node) {
    return switch (node) {
      LiteralNode() => {
          r'$type': IrNodeType.literal.wireName,
          'value': _encodeScalar(node.value),
        },
      ConstNode() => {
          r'$type': IrNodeType.constNode.wireName,
          'id': _requireConstId(node.value),
        },
      RefNode() => {
          r'$type': IrNodeType.ref.wireName,
          'path': node.path,
          if (node.reactive) 'reactive': true,
        },
      ActionSequenceNode() => {
          r'$type': IrNodeType.actionSequence.wireName,
          'steps': node.steps.map(_encodeActionStep).toList(),
        },
      ActionStepNode() => throw UnsupportedError(
          'ActionStepNode must be encoded via _encodeStep, not _encodeNode.',
        ),
      TryStepNode() => throw UnsupportedError(
          'TryStepNode must be encoded via _encodeActionStep, not _encodeNode.',
        ),
      EventNode() => {
          r'$type': IrNodeType.event.wireName,
          'target': node.target,
          if (node.args.isNotEmpty)
            'args': node.args.map((k, v) => MapEntry(k, _encodeNode(v))),
        },
      WidgetNode() => {
          r'$type': IrNodeType.widget.wireName,
          'name': node.name,
          'args': node.args.map((k, v) => MapEntry(k, _encodeNode(v))),
          if (node.key != null) 'key': _encodeNode(node.key!),
          if (node.listenablePaths.isNotEmpty)
            'listenablePaths': node.listenablePaths.toList(),
          if (node.typeArgs != null) 'typeArgs': node.typeArgs,
        },
      BuiltinWidgetNode() => {
          r'$type': IrNodeType.builtin.wireName,
          'name': node.name,
          'args': node.args.map((k, v) => MapEntry(k, _encodeNode(v))),
          if (node.key != null) 'key': _encodeNode(node.key!),
        },
      ListNode() => {
          r'$type': IrNodeType.list.wireName,
          'children': node.children.map(_encodeNode).toList(),
        },
      MapNode() => {
          r'$type': IrNodeType.map.wireName,
          'entries': node.entries.entries
              .map((e) => [_encodeNode(e.key), _encodeNode(e.value)])
              .toList(),
        },
      RecordNode() => {
          r'$type': IrNodeType.record.wireName,
          if (node.positional.isNotEmpty)
            'positional': node.positional.map(_encodeNode).toList(),
          if (node.named.isNotEmpty)
            'named': node.named.map((k, v) => MapEntry(k, _encodeNode(v))),
        },
      ConditionalNode() => {
          r'$type': IrNodeType.cond.wireName,
          'condition': _encodeNode(node.condition),
          'then': _encodeNode(node.thenBranch),
          if (node.elseBranch != null) 'else': _encodeNode(node.elseBranch!),
        },
      ForNode() => {
          r'$type': IrNodeType.forNode.wireName,
          if (node.variable != null) 'variable': node.variable,
          if (node.variables != null) 'variables': node.variables,
          'source': _encodeNode(node.source),
          'body': _encodeNode(node.body),
        },
      SpreadNode() => {
          r'$type': IrNodeType.spread.wireName,
          'source': _encodeNode(node.source),
        },
      CompareOpNode() => {
          r'$type': IrNodeType.cmp.wireName,
          'op': node.op.name,
          'left': _encodeNode(node.left),
          'right': _encodeNode(node.right),
        },
      ArithOpNode() => {
          r'$type': IrNodeType.arith.wireName,
          'op': node.op.name,
          'left': _encodeNode(node.left),
          'right': _encodeNode(node.right),
        },
      LogicOpNode() => {
          r'$type': IrNodeType.logic.wireName,
          'op': node.op.name,
          'left': _encodeNode(node.left),
          'right': _encodeNode(node.right),
        },
      NotOpNode() => {
          r'$type': IrNodeType.not.wireName,
          'operand': _encodeNode(node.operand),
        },
      CoalesceOpNode() => {
          r'$type': IrNodeType.coalesce.wireName,
          'left': _encodeNode(node.left),
          'right': _encodeNode(node.right),
        },
      GetterNode() => {
          r'$type': IrNodeType.getter.wireName,
          'receiver': _encodeNode(node.receiver),
          'name': node.name,
        },
      SetterCallNode() => {
          r'$type': IrNodeType.setterCall.wireName,
          'target': _encodeNode(node.target),
          'setterKey': node.setterKey,
          'value': _encodeNode(node.value),
        },
      LetNode() => {
          r'$type': IrNodeType.let.wireName,
          'name': node.name,
          'value': _encodeNode(node.value),
          'body': _encodeNode(node.body),
        },
      AssignNode() => {
          r'$type': IrNodeType.assign.wireName,
          'name': node.name,
          'value': _encodeNode(node.value),
        },
      SequenceNode() => {
          r'$type': IrNodeType.sequence.wireName,
          'steps': node.steps.map(_encodeNode).toList(),
          'returnExpr': _encodeNode(node.returnExpr),
        },
      LambdaNode() => {
          r'$type': IrNodeType.lambda.wireName,
          'params': node.params,
          'body': _encodeNode(node.body),
          if (node.isAsync) 'isAsync': true,
        },
      MemberAccessNode() => {
          r'$type': IrNodeType.member.wireName,
          'target': _encodeNode(node.target),
          'name': node.name,
        },
      IndexAccessNode() => {
          r'$type': IrNodeType.indexNode.wireName,
          'target': _encodeNode(node.target),
          'key': _encodeNode(node.key),
        },
      LengthOfNode() => {
          r'$type': IrNodeType.length.wireName,
          'target': _encodeNode(node.target),
        },
      IsNullCheckNode() => {
          r'$type': IrNodeType.isnull.wireName,
          'operand': _encodeNode(node.operand),
        },
      IsTypeNode() => {
          r'$type': IrNodeType.isType.wireName,
          'receiver': _encodeNode(node.receiver),
          'typeName': node.typeName,
        },
      AsTypeNode() => {
          r'$type': IrNodeType.asType.wireName,
          'operand': _encodeNode(node.operand),
          'typeName': node.typeName,
          'nullable': node.nullable,
        },
      RuntimeTypeRefNode() => {
          r'$type': IrNodeType.runtimeTypeRef.wireName,
          'operand': _encodeNode(node.operand),
        },
      StringInterpNode() => {
          r'$type': IrNodeType.interp.wireName,
          'parts': node.parts
              .map<Object?>(
                (p) => p is String ? p : _encodeNode(p as IrNode),
              )
              .toList(),
        },
      MethodCallNode() => {
          r'$type': IrNodeType.methodCall.wireName,
          if (node.receiver != null) 'receiver': _encodeNode(node.receiver!),
          'name': node.name,
          'args': node.args.map(_encodeNode).toList(),
          if (node.typeArgs != null) 'typeArgs': node.typeArgs,
        },
      ValueCtorNode() => {
          r'$type': IrNodeType.valueCtor.wireName,
          'name': node.name,
          'args': node.args.map(_encodeNode).toList(),
          if (node.typeArgs != null) 'typeArgs': node.typeArgs,
        },
      BlockNode() => {
          r'$type': IrNodeType.block.wireName,
          'statements': node.statements.map(_encodeNode).toList(),
        },
      IfStatementNode() => {
          r'$type': IrNodeType.ifStmt.wireName,
          'cond': _encodeNode(node.cond),
          'then': _encodeNode(node.then),
          if (node.else_ != null) 'else': _encodeNode(node.else_!),
        },
      BreakNode() => {r'$type': IrNodeType.breakNode.wireName},
      ContinueNode() => {r'$type': IrNodeType.continueNode.wireName},
      ReturnNode() => {
          r'$type': IrNodeType.returnStmt.wireName,
          if (node.value != null) 'value': _encodeNode(node.value!),
        },
      LetStatementNode() => {
          r'$type': IrNodeType.letStmt.wireName,
          'name': node.name,
          'value': _encodeNode(node.value),
          'isFinal': node.isFinal,
        },
      WhileNode() => {
          r'$type': IrNodeType.whileNode.wireName,
          'condition': _encodeNode(node.condition),
          'body': _encodeNode(node.body),
        },
      DoNode() => {
          r'$type': IrNodeType.doNode.wireName,
          'body': _encodeNode(node.body),
          'condition': _encodeNode(node.condition),
        },
      ImperativeForNode() => {
          r'$type': IrNodeType.imperativeFor.wireName,
          if (node.init != null) 'init': _encodeNode(node.init!),
          if (node.condition != null) 'condition': _encodeNode(node.condition!),
          if (node.update != null) 'update': _encodeNode(node.update!),
          'body': _encodeNode(node.body),
        },
      IrStatefulNode() => {
          r'$type': IrNodeType.stateful.wireName,
          if (node.id != null) 'id': node.id,
          'fields': node.fields.map(_encodeNode).toList(),
          'body': _encodeNode(node.body),
        },
      IrStatefulFieldNode() => {
          r'$type': IrNodeType.statefulField.wireName,
          'name': node.name,
          'initializer': _encodeNode(node.initializer),
          'isFinal': node.isFinal,
        },
      PayloadClassNode() => {
          r'$type': IrNodeType.payloadClass.wireName,
          'name': node.name,
          if (node.supertypeName != null) 'supertypeName': node.supertypeName,
          if (node.mixinNames.isNotEmpty) 'mixinNames': node.mixinNames,
          'fields': node.fields.map(_encodeNode).toList(),
          'ctors': node.ctors.map(_encodeNode).toList(),
          'methods': node.methods.map(_encodeNode).toList(),
        },
      PayloadFieldDeclNode() => {
          r'$type': IrNodeType.payloadField.wireName,
          'name': node.name,
          if (node.initializer != null) 'initializer': _encodeNode(node.initializer!),
          'isFinal': node.isFinal,
        },
      PayloadCtorNode() => {
          r'$type': IrNodeType.payloadCtor.wireName,
          'name': node.name,
          'params': node.params,
          'fieldInits': node.fieldInits.map(_encodeNode).toList(),
          if (node.body != null) 'body': _encodeNode(node.body!),
        },
      PayloadFieldInitNode() => {
          r'$type': IrNodeType.payloadFieldInit.wireName,
          'fieldName': node.fieldName,
          'value': _encodeNode(node.value),
        },
      PayloadInstanceCreationNode() => {
          r'$type': IrNodeType.payloadInstanceCreate.wireName,
          'className': node.className,
          if (node.ctorName.isNotEmpty) 'ctorName': node.ctorName,
          'args': node.args.map((k, v) => MapEntry(k, _encodeNode(v))),
        },
      PayloadMethodCallNode() => {
          r'$type': IrNodeType.payloadMethodCall.wireName,
          'receiver': _encodeNode(node.receiver),
          'methodName': node.methodName,
          'args': node.args.map((k, v) => MapEntry(k, _encodeNode(v))),
        },
      PayloadFieldRefNode() => {
          r'$type': IrNodeType.payloadFieldRef.wireName,
          'receiver': _encodeNode(node.receiver),
          'fieldName': node.fieldName,
        },
      PayloadFieldAssignNode() => {
          r'$type': IrNodeType.payloadFieldAssign.wireName,
          'receiver': _encodeNode(node.receiver),
          'fieldName': node.fieldName,
          'value': _encodeNode(node.value),
        },
      ThisFieldRefNode() => {
          r'$type': IrNodeType.thisFieldRef.wireName,
          'fieldName': node.fieldName,
        },
      ThisRefNode() => {
          r'$type': IrNodeType.thisRef.wireName,
        },
      PayloadFunctionNode() => {
          r'$type': IrNodeType.payloadFn.wireName,
          'name': node.name,
          'params': node.params,
          'body': _encodeNode(node.body),
        },
      PayloadFunctionCallNode() => {
          r'$type': IrNodeType.payloadFnCall.wireName,
          'name': node.name,
          'args': node.args.map(_encodeNode).toList(),
        },
      PayloadMixinNode() => {
          r'$type': IrNodeType.payloadMixin.wireName,
          'name': node.name,
          if (node.onTypes.isNotEmpty) 'onTypes': node.onTypes,
          'fields': node.fields.map(_encodeNode).toList(),
          'methods': node.methods.map(_encodeNode).toList(),
        },
      PayloadExtensionNode() => {
          r'$type': IrNodeType.payloadExtension.wireName,
          'name': node.name,
          'targetTypeName': node.targetTypeName,
          'methods': node.methods.map(_encodeNode).toList(),
        },
      PayloadFunctionValueNode() => {
          r'$type': IrNodeType.payloadFnValue.wireName,
          if (node.functionName != null) 'functionName': node.functionName,
          if (node.lambda != null) 'lambda': _encodeNode(node.lambda!),
          if (node.methodTearoffReceiver != null)
            'methodTearoffReceiver': _encodeNode(node.methodTearoffReceiver!),
          if (node.methodTearoffName != null) 'methodTearoffName': node.methodTearoffName,
          if (node.capturedEnvKeys.isNotEmpty) 'capturedEnvKeys': node.capturedEnvKeys,
        },
      ScreenWithFunctionsNode() => {
          r'$type': IrNodeType.screenWithFunctions.wireName,
          'functions': node.functions.map(_encodeNode).toList(),
          if (node.classes.isNotEmpty)
            'classes': node.classes.map(_encodeNode).toList(),
          if (node.mixins.isNotEmpty)
            'mixins': node.mixins.map(_encodeNode).toList(),
          if (node.extensions.isNotEmpty)
            'extensions': node.extensions.map(_encodeNode).toList(),
          'screenBody': _encodeNode(node.screenBody),
        },
    };
  }

  /// Encodes a step inside an `actionSequence.steps` array. Dispatches on
  /// the runtime type: either [ActionStepNode] or [TryStepNode].
  Map<String, Object?> _encodeActionStep(IrNode step) {
    if (step is TryStepNode) {
      return {
        r'$type': IrNodeType.tryStep.wireName,
        'trySteps': step.trySteps.map(_encodeStep).toList(),
        'catchSteps': step.catchSteps.map(_encodeStep).toList(),
        if (step.exceptionBind != null) 'exceptionBind': step.exceptionBind,
      };
    }
    return _encodeStep(step as ActionStepNode);
  }

  Map<String, Object?> _encodeStep(ActionStepNode step) => {
        r'$type': IrNodeType.actionStep.wireName,
        'call': _encodeNode(step.call),
        'awaitResult': step.awaitResult,
        if (step.bindResult != null) 'bindResult': step.bindResult,
      };

  Object? _encodeScalar(Object? value) {
    if (value == null) return null;
    if (value is bool || value is num || value is String) return value;
    throw UnsupportedError(
      'JsonIrEncoder only handles scalar LiteralNode values '
      '(bool/num/String/null). Use ConstNode for constructed values. '
      'Got: ${value.runtimeType}',
    );
  }

  String _requireConstId(Object? value) {
    throw UnimplementedError(
      'ConstNode JSON encoding requires a stable id resolved by the runtime '
      'registry. v1 const-fold pass uses Dart-literal output only; the wire '
      'format does not yet support ConstNode. Lower without const-folding '
      'when emitting .sdui.json until the const id system lands in Phase 2.',
    );
  }
}
