import 'package:desk_sdui_annotation/src/ir/ir_node.dart';

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
          r'$type': 'literal',
          'value': _encodeScalar(node.value),
        },
      ConstNode() => {
          r'$type': 'const',
          'id': _requireConstId(node.value),
        },
      RefNode() => {
          r'$type': 'ref',
          'path': node.path,
          if (node.reactive) 'reactive': true,
        },
      ActionSequenceNode() => {
          r'$type': 'actionSequence',
          'steps': node.steps.map(_encodeActionStep).toList(),
        },
      ActionStepNode() => throw UnsupportedError(
          'ActionStepNode must be encoded via _encodeStep, not _encodeNode.',
        ),
      TryStepNode() => throw UnsupportedError(
          'TryStepNode must be encoded via _encodeActionStep, not _encodeNode.',
        ),
      EventNode() => {
          r'$type': 'event',
          'target': node.target,
          if (node.args.isNotEmpty)
            'args': node.args.map((k, v) => MapEntry(k, _encodeNode(v))),
        },
      WidgetNode() => {
          r'$type': 'widget',
          'name': node.name,
          'args': node.args.map((k, v) => MapEntry(k, _encodeNode(v))),
          if (node.key != null) 'key': _encodeNode(node.key!),
          if (node.listenablePaths.isNotEmpty)
            'listenablePaths': node.listenablePaths.toList(),
          if (node.typeArgs != null) 'typeArgs': node.typeArgs,
        },
      BuiltinWidgetNode() => {
          r'$type': 'builtin',
          'name': node.name,
          'args': node.args.map((k, v) => MapEntry(k, _encodeNode(v))),
          if (node.key != null) 'key': _encodeNode(node.key!),
        },
      ListNode() => {
          r'$type': 'list',
          'children': node.children.map(_encodeNode).toList(),
        },
      MapNode() => {
          r'$type': 'map',
          'entries': node.entries.entries
              .map((e) => [_encodeNode(e.key), _encodeNode(e.value)])
              .toList(),
        },
      RecordNode() => {
          r'$type': 'record',
          if (node.positional.isNotEmpty)
            'positional': node.positional.map(_encodeNode).toList(),
          if (node.named.isNotEmpty)
            'named': node.named.map((k, v) => MapEntry(k, _encodeNode(v))),
        },
      ConditionalNode() => {
          r'$type': 'cond',
          'condition': _encodeNode(node.condition),
          'then': _encodeNode(node.thenBranch),
          if (node.elseBranch != null) 'else': _encodeNode(node.elseBranch!),
        },
      ForNode() => {
          r'$type': 'for',
          if (node.variable != null) 'variable': node.variable,
          if (node.variables != null) 'variables': node.variables,
          'source': _encodeNode(node.source),
          'body': _encodeNode(node.body),
        },
      SpreadNode() => {
          r'$type': 'spread',
          'source': _encodeNode(node.source),
        },
      CompareOpNode() => {
          r'$type': 'cmp',
          'op': node.op.name,
          'left': _encodeNode(node.left),
          'right': _encodeNode(node.right),
        },
      ArithOpNode() => {
          r'$type': 'arith',
          'op': node.op.name,
          'left': _encodeNode(node.left),
          'right': _encodeNode(node.right),
        },
      LogicOpNode() => {
          r'$type': 'logic',
          'op': node.op.name,
          'left': _encodeNode(node.left),
          'right': _encodeNode(node.right),
        },
      NotOpNode() => {
          r'$type': 'not',
          'operand': _encodeNode(node.operand),
        },
      CoalesceOpNode() => {
          r'$type': 'coalesce',
          'left': _encodeNode(node.left),
          'right': _encodeNode(node.right),
        },
      GetterNode() => {
          r'$type': 'getter',
          'receiver': _encodeNode(node.receiver),
          'name': node.name,
        },
      LetNode() => {
          r'$type': 'let',
          'name': node.name,
          'value': _encodeNode(node.value),
          'body': _encodeNode(node.body),
        },
      AssignNode() => {
          r'$type': 'assign',
          'name': node.name,
          'value': _encodeNode(node.value),
        },
      SequenceNode() => {
          r'$type': 'sequence',
          'steps': node.steps.map(_encodeNode).toList(),
          'returnExpr': _encodeNode(node.returnExpr),
        },
      LambdaNode() => {
          r'$type': 'lambda',
          'params': node.params,
          'body': _encodeNode(node.body),
          if (node.isAsync) 'isAsync': true,
        },
      MemberAccessNode() => {
          r'$type': 'member',
          'target': _encodeNode(node.target),
          'name': node.name,
        },
      IndexAccessNode() => {
          r'$type': 'index',
          'target': _encodeNode(node.target),
          'key': _encodeNode(node.key),
        },
      LengthOfNode() => {
          r'$type': 'length',
          'target': _encodeNode(node.target),
        },
      IsNullCheckNode() => {
          r'$type': 'isnull',
          'operand': _encodeNode(node.operand),
        },
      IsTypeNode() => {
          r'$type': 'isType',
          'receiver': _encodeNode(node.receiver),
          'typeName': node.typeName,
        },
      StringInterpNode() => {
          r'$type': 'interp',
          'parts': node.parts
              .map<Object?>(
                (p) => p is String ? p : _encodeNode(p as IrNode),
              )
              .toList(),
        },
      MethodCallNode() => {
          r'$type': 'MethodCall',
          if (node.receiver != null) 'receiver': _encodeNode(node.receiver!),
          'name': node.name,
          'args': node.args.map(_encodeNode).toList(),
          if (node.typeArgs != null) 'typeArgs': node.typeArgs,
        },
      ValueCtorNode() => {
          r'$type': 'ValueCtor',
          'name': node.name,
          'args': node.args.map(_encodeNode).toList(),
          if (node.typeArgs != null) 'typeArgs': node.typeArgs,
        },
      BlockNode() => {
          r'$type': 'block',
          'statements': node.statements.map(_encodeNode).toList(),
        },
      IfStatementNode() => {
          r'$type': 'ifStmt',
          'cond': _encodeNode(node.cond),
          'then': _encodeNode(node.then),
          if (node.else_ != null) 'else': _encodeNode(node.else_!),
        },
      BreakNode() => {r'$type': 'break'},
      ContinueNode() => {r'$type': 'continue'},
      ReturnNode() => {
          r'$type': 'returnStmt',
          if (node.value != null) 'value': _encodeNode(node.value!),
        },
      LetStatementNode() => {
          r'$type': 'letStmt',
          'name': node.name,
          'value': _encodeNode(node.value),
          'isFinal': node.isFinal,
        },
      WhileNode() => {
          r'$type': 'while',
          'condition': _encodeNode(node.condition),
          'body': _encodeNode(node.body),
        },
      DoNode() => {
          r'$type': 'do',
          'body': _encodeNode(node.body),
          'condition': _encodeNode(node.condition),
        },
      ImperativeForNode() => {
          r'$type': 'imperativeFor',
          if (node.init != null) 'init': _encodeNode(node.init!),
          if (node.condition != null) 'condition': _encodeNode(node.condition!),
          if (node.update != null) 'update': _encodeNode(node.update!),
          'body': _encodeNode(node.body),
        },
    };
  }

  /// Encodes a step inside an `actionSequence.steps` array. Dispatches on
  /// the runtime type: either [ActionStepNode] or [TryStepNode].
  Map<String, Object?> _encodeActionStep(IrNode step) {
    if (step is TryStepNode) {
      return {
        r'$type': 'tryStep',
        'trySteps': step.trySteps.map(_encodeStep).toList(),
        'catchSteps': step.catchSteps.map(_encodeStep).toList(),
        if (step.exceptionBind != null) 'exceptionBind': step.exceptionBind,
      };
    }
    return _encodeStep(step as ActionStepNode);
  }

  Map<String, Object?> _encodeStep(ActionStepNode step) => {
        r'$type': 'actionStep',
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
