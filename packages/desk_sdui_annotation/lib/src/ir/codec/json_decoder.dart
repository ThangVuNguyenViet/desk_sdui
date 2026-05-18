import 'package:desk_sdui_annotation/src/ir/ir_node.dart';

import '../arith_op.dart';
import '../compare_op.dart';
import '../logic_op.dart';

class JsonIrDecoder {
  const JsonIrDecoder();

  IrNode decode(Map<String, Object?> map) => _decodeNode(map);

  IrNode _decodeNode(Map<String, Object?> map) {
    final type = map[r'$type'] as String?;
    if (type == null) {
      throw FormatException('IR node missing \$type discriminator: $map');
    }
    return switch (type) {
      'literal' => LiteralNode(map['value']),
      'const' => throw UnimplementedError(
          'ConstNode JSON decoding not supported in Phase 1; '
          'lower without const-folding for .sdui.json output.',
        ),
      'ref' => RefNode(
          (map['path']! as List).cast<String>(),
          reactive: map['reactive'] as bool? ?? false,
        ),
      'actionSequence' => ActionSequenceNode(
          steps: ((map['steps']! as List).cast<Map<String, Object?>>())
              .map(_decodeActionStep)
              .toList(),
        ),
      'event' => EventNode(
          (map['target']! as List).cast<String>(),
          args: _decodeNamedArgs(map['args']),
        ),
      'widget' => WidgetNode(
          name: map['name']! as String,
          args: _decodeNamedArgs(map['args']),
          key: _decodeOptional(map['key']),
          listenablePaths: ((map['listenablePaths'] as List?) ?? const [])
              .cast<String>()
              .toSet(),
          typeArgs: _decodeStringList(map['typeArgs']),
        ),
      'builtin' => BuiltinWidgetNode(
          name: map['name']! as String,
          args: _decodeNamedArgs(map['args']),
          key: _decodeOptional(map['key']),
        ),
      'list' => ListNode(
          ((map['children']! as List).cast<Map<String, Object?>>())
              .map(_decodeNode)
              .toList(),
        ),
      'map' => MapNode(
          {
            for (final entry in (map['entries']! as List).cast<List<Object?>>())
              _decodeNode(entry[0]! as Map<String, Object?>):
                  _decodeNode(entry[1]! as Map<String, Object?>),
          },
        ),
      'record' => RecordNode(
          positional: ((map['positional'] as List?) ?? const [])
              .cast<Map<String, Object?>>()
              .map(_decodeNode)
              .toList(),
          named: _decodeNamedArgs(map['named']),
        ),
      'cond' => ConditionalNode(
          condition: _decodeNode(map['condition']! as Map<String, Object?>),
          thenBranch: _decodeNode(map['then']! as Map<String, Object?>),
          elseBranch: _decodeOptional(map['else']),
        ),
      'for' => _decodeFor(map),
      'spread' => SpreadNode(
          _decodeNode(map['source']! as Map<String, Object?>),
        ),
      'cmp' => CompareOpNode(
          op: CompareOp.values.byName(map['op']! as String),
          left: _decodeNode(map['left']! as Map<String, Object?>),
          right: _decodeNode(map['right']! as Map<String, Object?>),
        ),
      'arith' => ArithOpNode(
          op: ArithOp.values.byName(map['op']! as String),
          left: _decodeNode(map['left']! as Map<String, Object?>),
          right: _decodeNode(map['right']! as Map<String, Object?>),
        ),
      'logic' => LogicOpNode(
          op: LogicOp.values.byName(map['op']! as String),
          left: _decodeNode(map['left']! as Map<String, Object?>),
          right: _decodeNode(map['right']! as Map<String, Object?>),
        ),
      'not' => NotOpNode(
          _decodeNode(map['operand']! as Map<String, Object?>),
        ),
      'coalesce' => CoalesceOpNode(
          left: _decodeNode(map['left']! as Map<String, Object?>),
          right: _decodeNode(map['right']! as Map<String, Object?>),
        ),
      'getter' => GetterNode(
          receiver: _decodeNode(map['receiver']! as Map<String, Object?>),
          name: map['name']! as String,
        ),
      'setterCall' => SetterCallNode(
          target: _decodeNode(map['target']! as Map<String, Object?>),
          setterKey: map['setterKey']! as String,
          value: _decodeNode(map['value']! as Map<String, Object?>),
        ),
      'let' => LetNode(
          name: map['name']! as String,
          value: _decodeNode(map['value']! as Map<String, Object?>),
          body: _decodeNode(map['body']! as Map<String, Object?>),
        ),
      'assign' => AssignNode(
          name: map['name']! as String,
          value: _decodeNode(map['value']! as Map<String, Object?>),
        ),
      'sequence' => SequenceNode(
          steps: ((map['steps']! as List).cast<Map<String, Object?>>())
              .map(_decodeNode)
              .toList(),
          returnExpr: _decodeNode(map['returnExpr']! as Map<String, Object?>),
        ),
      'lambda' => LambdaNode(
          params: (map['params']! as List).cast<String>(),
          body: _decodeNode(map['body']! as Map<String, Object?>),
          isAsync: map['isAsync'] as bool? ?? false,
        ),
      'member' => MemberAccessNode(
          target: _decodeNode(map['target']! as Map<String, Object?>),
          name: map['name']! as String,
        ),
      'index' => IndexAccessNode(
          target: _decodeNode(map['target']! as Map<String, Object?>),
          key: _decodeNode(map['key']! as Map<String, Object?>),
        ),
      'length' => LengthOfNode(
          _decodeNode(map['target']! as Map<String, Object?>),
        ),
      'isnull' => IsNullCheckNode(
          _decodeNode(map['operand']! as Map<String, Object?>),
        ),
      'isType' => IsTypeNode(
          receiver: _decodeNode(map['receiver']! as Map<String, Object?>),
          typeName: map['typeName']! as String,
        ),
      'asType' => AsTypeNode(
          operand: _decodeNode(map['operand']! as Map<String, Object?>),
          typeName: map['typeName']! as String,
          nullable: map['nullable'] as bool? ?? false,
        ),
      'runtimeTypeRef' => RuntimeTypeRefNode(
          operand: _decodeNode(map['operand']! as Map<String, Object?>),
        ),
      'interp' => StringInterpNode(
          (map['parts']! as List).map<Object>((p) {
            if (p is String) return p;
            return _decodeNode(p! as Map<String, Object?>);
          }).toList(),
        ),
      'MethodCall' => MethodCallNode(
          receiver: map['receiver'] != null
              ? _decodeNode(map['receiver']! as Map<String, Object?>)
              : null,
          name: map['name']! as String,
          args: ((map['args']! as List).cast<Map<String, Object?>>())
              .map(_decodeNode)
              .toList(),
          typeArgs: _decodeStringList(map['typeArgs']),
        ),
      'ValueCtor' => ValueCtorNode(
          name: map['name']! as String,
          args: ((map['args']! as List).cast<Map<String, Object?>>())
              .map(_decodeNode)
              .toList(),
          typeArgs: _decodeStringList(map['typeArgs']),
        ),
      'block' => BlockNode(
          statements: ((map['statements']! as List).cast<Map<String, Object?>>())
              .map(_decodeNode)
              .toList(),
        ),
      'ifStmt' => IfStatementNode(
          cond: _decodeNode(map['cond']! as Map<String, Object?>),
          then: _decodeNode(map['then']! as Map<String, Object?>),
          else_: _decodeOptional(map['else']),
        ),
      'break' => const BreakNode(),
      'continue' => const ContinueNode(),
      'returnStmt' => ReturnNode(
          value: _decodeOptional(map['value']),
        ),
      'letStmt' => LetStatementNode(
          name: map['name']! as String,
          value: _decodeNode(map['value']! as Map<String, Object?>),
          isFinal: map['isFinal']! as bool,
        ),
      'while' => WhileNode(
          condition: _decodeNode(map['condition']! as Map<String, Object?>),
          body: _decodeNode(map['body']! as Map<String, Object?>),
        ),
      'do' => DoNode(
          body: _decodeNode(map['body']! as Map<String, Object?>),
          condition: _decodeNode(map['condition']! as Map<String, Object?>),
        ),
      'imperativeFor' => ImperativeForNode(
          init: _decodeOptional(map['init']),
          condition: _decodeOptional(map['condition']),
          update: _decodeOptional(map['update']),
          body: _decodeNode(map['body']! as Map<String, Object?>),
        ),
      'stateful' => IrStatefulNode(
          id: map['id'] as String?,
          fields: ((map['fields']! as List).cast<Map<String, Object?>>())
              .map<IrStatefulFieldNode>(_decodeStatefulField)
              .toList(),
          body: _decodeNode(map['body']! as Map<String, Object?>),
        ),
      'statefulField' => IrStatefulFieldNode(
          name: map['name']! as String,
          initializer: _decodeNode(map['initializer']! as Map<String, Object?>),
          isFinal: map['isFinal']! as bool,
        ),
      'payloadClass' => PayloadClassNode(
          name: map['name']! as String,
          supertypeName: map['supertypeName'] as String?,
          mixinNames: ((map['mixinNames'] as List?) ?? const []).cast<String>(),
          fields: ((map['fields']! as List).cast<Map<String, Object?>>())
              .map(_decodePayloadField)
              .toList(),
          ctors: ((map['ctors']! as List).cast<Map<String, Object?>>())
              .map(_decodePayloadCtor)
              .toList(),
          methods: ((map['methods']! as List).cast<Map<String, Object?>>())
              .map<PayloadFunctionNode>(_decodePayloadFn)
              .toList(),
        ),
      'payloadField' => _decodePayloadField(map),
      'payloadCtor' => _decodePayloadCtor(map),
      'payloadFieldInit' => PayloadFieldInitNode(
          fieldName: map['fieldName']! as String,
          value: _decodeNode(map['value']! as Map<String, Object?>),
        ),
      'payloadInstanceCreate' => PayloadInstanceCreationNode(
          className: map['className']! as String,
          ctorName: map['ctorName'] as String? ?? '',
          args: _decodeNamedArgs(map['args']),
        ),
      'payloadFn' => _decodePayloadFn(map),
      'payloadFnCall' => PayloadFunctionCallNode(
          name: map['name']! as String,
          args: ((map['args']! as List).cast<Map<String, Object?>>())
              .map(_decodeNode)
              .toList(),
        ),
      'payloadMixin' => PayloadMixinNode(
          name: map['name']! as String,
          onTypes: ((map['onTypes'] as List?) ?? const []).cast<String>(),
          fields: ((map['fields']! as List).cast<Map<String, Object?>>())
              .map(_decodePayloadField)
              .toList(),
          methods: ((map['methods']! as List).cast<Map<String, Object?>>())
              .map<PayloadFunctionNode>(_decodePayloadFn)
              .toList(),
        ),
      'payloadExtension' => PayloadExtensionNode(
          name: map['name']! as String,
          targetTypeName: map['targetTypeName']! as String,
          methods: ((map['methods']! as List).cast<Map<String, Object?>>())
              .map<PayloadFunctionNode>(_decodePayloadFn)
              .toList(),
        ),
      'payloadFnValue' => PayloadFunctionValueNode(
          functionName: map['functionName'] as String?,
          lambda: map['lambda'] != null
              ? _decodeNode(map['lambda']! as Map<String, Object?>) as LambdaNode
              : null,
          methodTearoffReceiver: map['methodTearoffReceiver'] != null
              ? _decodeNode(map['methodTearoffReceiver']! as Map<String, Object?>)
              : null,
          methodTearoffName: map['methodTearoffName'] as String?,
          capturedEnvKeys: ((map['capturedEnvKeys'] as List?) ?? const [])
              .cast<String>()
              .toList(),
        ),
      'screenWithFunctions' => ScreenWithFunctionsNode(
          functions: ((map['functions']! as List).cast<Map<String, Object?>>())
              .map<PayloadFunctionNode>(_decodePayloadFn)
              .toList(),
          classes: ((map['classes'] as List?) ?? const [])
              .cast<Map<String, Object?>>()
              .map<PayloadClassNode>((m) => _decodeNode(m) as PayloadClassNode)
              .toList(),
          mixins: ((map['mixins'] as List?) ?? const [])
              .cast<Map<String, Object?>>()
              .map<PayloadMixinNode>((m) => _decodeNode(m) as PayloadMixinNode)
              .toList(),
          extensions: ((map['extensions'] as List?) ?? const [])
              .cast<Map<String, Object?>>()
              .map<PayloadExtensionNode>((m) => _decodeNode(m) as PayloadExtensionNode)
              .toList(),
          screenBody:
              _decodeNode(map['screenBody']! as Map<String, Object?>),
        ),
      _ => throw FormatException('Unknown IR node type: $type'),
    };
  }

  IrNode? _decodeOptional(Object? value) {
    if (value == null) return null;
    return _decodeNode(value as Map<String, Object?>);
  }

  Map<String, IrNode> _decodeNamedArgs(Object? value) {
    if (value == null) return {};
    final raw = (value as Map).cast<String, Map<String, Object?>>();
    return raw.map((k, v) => MapEntry(k, _decodeNode(v)));
  }

  /// Decodes a step inside an `actionSequence.steps` array. Dispatches on
  /// `$type`: either `'actionStep'` (default when tag absent) or `'tryStep'`.
  IrNode _decodeActionStep(Map<String, Object?> map) {
    final type = map[r'$type'] as String? ?? 'actionStep';
    if (type == 'tryStep') {
      return TryStepNode(
        trySteps: ((map['trySteps']! as List).cast<Map<String, Object?>>())
            .map(_decodeStep)
            .toList(),
        catchSteps: ((map['catchSteps']! as List).cast<Map<String, Object?>>())
            .map(_decodeStep)
            .toList(),
        exceptionBind: map['exceptionBind'] as String?,
      );
    }
    return _decodeStep(map);
  }

  ActionStepNode _decodeStep(Map<String, Object?> map) {
    return ActionStepNode(
      call: _decodeNode(map['call']! as Map<String, Object?>),
      awaitResult: map['awaitResult']! as bool,
      bindResult: map['bindResult'] as String?,
    );
  }

  /// Decodes an optional `List<String>` field. Returns `null` if absent or
  /// if the list is empty (treats empty as null per the IR semantics).
  List<String>? _decodeStringList(Object? value) {
    if (value == null) return null;
    final list = (value as List).cast<String>();
    return list.isEmpty ? null : list;
  }

  IrStatefulFieldNode _decodeStatefulField(Map<String, Object?> map) {
    return IrStatefulFieldNode(
      name: map['name']! as String,
      initializer: _decodeNode(map['initializer']! as Map<String, Object?>),
      isFinal: map['isFinal']! as bool,
    );
  }

  PayloadFieldDeclNode _decodePayloadField(Map<String, Object?> map) {
    return PayloadFieldDeclNode(
      name: map['name']! as String,
      initializer: _decodeOptional(map['initializer']),
      isFinal: map['isFinal']! as bool,
    );
  }

  PayloadCtorNode _decodePayloadCtor(Map<String, Object?> map) {
    return PayloadCtorNode(
      name: map['name']! as String,
      params: (map['params']! as List).cast<String>(),
      fieldInits: ((map['fieldInits']! as List).cast<Map<String, Object?>>())
          .map((m) => PayloadFieldInitNode(
                fieldName: m['fieldName']! as String,
                value: _decodeNode(m['value']! as Map<String, Object?>),
              ))
          .toList(),
      body: _decodeOptional(map['body']),
    );
  }

  PayloadFunctionNode _decodePayloadFn(Map<String, Object?> map) {
    return PayloadFunctionNode(
      name: map['name']! as String,
      params: (map['params']! as List).cast<String>(),
      body: _decodeNode(map['body']! as Map<String, Object?>),
    );
  }

  IrNode _decodeFor(Map<String, Object?> map) {
    final variable = map['variable'] as String?;
    final variables = (map['variables'] as List?)?.cast<String>();
    final source = _decodeNode(map['source']! as Map<String, Object?>);
    final body = _decodeNode(map['body']! as Map<String, Object?>);

    if (variable != null) {
      return ForNode(
        variable: variable,
        source: source,
        body: body,
      );
    }
    return ForNode.destructured(
      variables: variables!,
      source: source,
      body: body,
    );
  }
}
