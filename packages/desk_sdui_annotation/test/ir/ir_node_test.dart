import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:test/test.dart';

void main() {
  const codec = JsonIrCodec();

  group('MethodCallNode', () {
    test('round-trips through JSON codec', () {
      final node = MethodCallNode(
        receiver: const RefNode(['data', 'title']),
        name: 'String.toUpperCase',
        args: const [],
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, isA<MethodCallNode>());
      expect((decoded as MethodCallNode).name, 'String.toUpperCase');
      expect(decoded.receiver, isA<RefNode>());
      expect(decoded.args, isEmpty);
    });

    test('round-trips with args through JSON codec', () {
      final node = MethodCallNode(
        receiver: const RefNode(['data', 'items']),
        name: 'List.join',
        args: const [LiteralNode(', ')],
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, isA<MethodCallNode>());
      expect((decoded as MethodCallNode).args, hasLength(1));
    });
  });

  group('ValueCtorNode', () {
    test('round-trips through JSON codec', () {
      final node = ValueCtorNode(
        name: 'EdgeInsets.all',
        args: const [LiteralNode(8.0)],
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, isA<ValueCtorNode>());
      expect((decoded as ValueCtorNode).name, 'EdgeInsets.all');
      expect(decoded.args, hasLength(1));
    });

    test('round-trips with no args through JSON codec', () {
      final node = ValueCtorNode(name: 'BoxDecoration', args: const []);
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, isA<ValueCtorNode>());
      expect((decoded as ValueCtorNode).args, isEmpty);
    });
  });


  group('LiteralNode', () {
    test('equality by value', () {
      expect(const LiteralNode(42), const LiteralNode(42));
      expect(const LiteralNode('a') == const LiteralNode('b'), isFalse);
    });

    test('hashCode by value', () {
      expect(
        const LiteralNode(true).hashCode,
        const LiteralNode(true).hashCode,
      );
    });

    test('toString includes value', () {
      expect(const LiteralNode(42).toString(), contains('42'));
    });
  });

  group('RefNode', () {
    test('equality by path and reactive flag', () {
      expect(
        const RefNode(['vm', 'flag']),
        const RefNode(['vm', 'flag']),
      );
      expect(
        const RefNode(['vm', 'flag']) ==
            const RefNode(['vm', 'flag'], reactive: true),
        isFalse,
      );
    });

    test('default reactive is false', () {
      expect(const RefNode(['x']).reactive, isFalse);
    });
  });

  group('EventNode', () {
    test('equality by target and args', () {
      expect(
        const EventNode(['vm', 'foo']),
        const EventNode(['vm', 'foo']),
      );
    });

    test('args defaults to empty', () {
      expect(const EventNode(['vm', 'foo']).args, isEmpty);
    });
  });

  group('WidgetNode', () {
    test('stores name and args', () {
      const node = WidgetNode(name: 'Column', args: {});
      expect(node.name, 'Column');
      expect(node.args, isEmpty);
      expect(node.key, isNull);
    });

    test('listenablePaths defaults to empty set', () {
      expect(const WidgetNode(name: 'X', args: {}).listenablePaths, isEmpty);
    });
  });

  group('ConditionalNode', () {
    test('elseBranch is optional', () {
      const node = ConditionalNode(
        condition: LiteralNode(true),
        thenBranch: LiteralNode('y'),
      );
      expect(node.elseBranch, isNull);
    });
  });

  group('ForNode', () {
    test('stores variable, source, body', () {
      const node = ForNode(
        variable: 'item',
        source: RefNode(['xs']),
        body: LiteralNode('x'),
      );
      expect(node.variable, 'item');
    });

    test('destructured form supports two variable names', () {
      const node = ForNode.destructured(
        variables: ['i', 'item'],
        source: RefNode(['xs']),
        body: LiteralNode('x'),
      );
      expect(node.variables, ['i', 'item']);
    });
  });

  group('ListNode and SpreadNode', () {
    test('ListNode equality by children', () {
      expect(
        const ListNode([LiteralNode(1), LiteralNode(2)]),
        const ListNode([LiteralNode(1), LiteralNode(2)]),
      );
    });

    test('SpreadNode wraps a source', () {
      const node = SpreadNode(RefNode(['xs']));
      expect(node.source, isA<RefNode>());
    });
  });
}
