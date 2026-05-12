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
              .map(_decodeStep)
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
        ),
      'ValueCtor' => ValueCtorNode(
          name: map['name']! as String,
          args: ((map['args']! as List).cast<Map<String, Object?>>())
              .map(_decodeNode)
              .toList(),
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

  ActionStepNode _decodeStep(Map<String, Object?> map) {
    return ActionStepNode(
      call: _decodeNode(map['call']! as Map<String, Object?>),
      awaitResult: map['awaitResult']! as bool,
      bindResult: map['bindResult'] as String?,
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
