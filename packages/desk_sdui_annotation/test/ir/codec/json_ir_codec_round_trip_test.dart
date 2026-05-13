import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:test/test.dart';

void main() {
  const codec = JsonIrCodec();

  group('JsonIrCodec round-trip', () {
    test('LiteralNode', () {
      const node = LiteralNode(42);
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('LiteralNode with string', () {
      const node = LiteralNode('hello');
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('LiteralNode with null', () {
      const node = LiteralNode(null);
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('RefNode', () {
      const node = RefNode(['vm', 'flag'], reactive: true);
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('RefNode non-reactive', () {
      const node = RefNode(['x']);
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('EventNode', () {
      const node = EventNode(
        ['vm', 'submit'],
        args: {'id': LiteralNode(1)},
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('WidgetNode', () {
      const node = WidgetNode(
        name: 'Column',
        args: {
          'children': ListNode([
            LiteralNode('a'),
            LiteralNode('b'),
          ]),
        },
        key: LiteralNode('mykey'),
        listenablePaths: {'vm.flag'},
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('BuiltinWidgetNode', () {
      const node = BuiltinWidgetNode(
        name: 'Text',
        args: {'data': LiteralNode('hello')},
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('ListNode', () {
      const node = ListNode([
        LiteralNode(1),
        RefNode(['x']),
        LiteralNode('three'),
      ]);
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('MapNode', () {
      final node = MapNode({
        const LiteralNode('key'): const LiteralNode('value'),
      });
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('RecordNode', () {
      const node = RecordNode(
        positional: [LiteralNode(1), LiteralNode(2)],
        named: {'name': LiteralNode('test')},
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('ConditionalNode with else', () {
      const node = ConditionalNode(
        condition: RefNode(['flag']),
        thenBranch: LiteralNode('yes'),
        elseBranch: LiteralNode('no'),
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('ConditionalNode without else', () {
      const node = ConditionalNode(
        condition: RefNode(['flag']),
        thenBranch: LiteralNode('yes'),
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('ForNode single variable', () {
      const node = ForNode(
        variable: 'item',
        source: RefNode(['xs']),
        body: LiteralNode('x'),
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('ForNode destructured', () {
      const node = ForNode.destructured(
        variables: ['i', 'item'],
        source: RefNode(['xs']),
        body: LiteralNode('x'),
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('SpreadNode', () {
      const node = SpreadNode(RefNode(['xs']));
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('CompareOpNode', () {
      const node = CompareOpNode(
        op: CompareOp.gte,
        left: LiteralNode(50),
        right: LiteralNode(100),
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('ArithOpNode', () {
      const node = ArithOpNode(
        op: ArithOp.add,
        left: LiteralNode(1),
        right: LiteralNode(2),
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('LogicOpNode', () {
      const node = LogicOpNode(
        op: LogicOp.and,
        left: LiteralNode(true),
        right: LiteralNode(false),
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('NotOpNode', () {
      const node = NotOpNode(LiteralNode(true));
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('CoalesceOpNode', () {
      const node = CoalesceOpNode(
        left: RefNode(['x']),
        right: LiteralNode('default'),
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('MemberAccessNode', () {
      const node = MemberAccessNode(
        target: RefNode(['data']),
        name: 'title',
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('IndexAccessNode', () {
      const node = IndexAccessNode(
        target: RefNode(['xs']),
        key: LiteralNode(0),
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('LengthOfNode', () {
      const node = LengthOfNode(RefNode(['xs']));
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('IsNullCheckNode', () {
      const node = IsNullCheckNode(RefNode(['a']));
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('IsTypeNode', () {
      const node = IsTypeNode(
        receiver: RefNode(['vm', 'state']),
        typeName: 'PatternLoaded',
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('StringInterpNode', () {
      const node = StringInterpNode([
        'hello ',
        RefNode(['name']),
        '!',
      ]);
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('deeply nested structure', () {
      const node = WidgetNode(
        name: 'Column',
        args: {
          'children': ListNode([
            WidgetNode(
              name: 'Text',
              args: {
                'data': StringInterpNode([
                  'Count: ',
                  CompareOpNode(
                    op: CompareOp.gt,
                    left: RefNode(['count']),
                    right: LiteralNode(0),
                  ),
                ]),
              },
            ),
            ConditionalNode(
              condition: IsNullCheckNode(RefNode(['error'])),
              thenBranch: LiteralNode('All good'),
              elseBranch: RefNode(['error']),
            ),
          ]),
        },
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('IrStatefulFieldNode', () {
      const node = IrStatefulFieldNode(
        name: 'counter',
        initializer: LiteralNode(0),
        isFinal: false,
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('IrStatefulNode with one field', () {
      const node = IrStatefulNode(
        fields: [
          IrStatefulFieldNode(
            name: 'count',
            initializer: LiteralNode(0),
            isFinal: false,
          ),
        ],
        body: ReturnNode(value: RefNode(['count'])),
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('IrStatefulNode round-trips id field', () {
      // Locks down the encoder's `if (node.id != null)` guard and the
      // decoder's `String?` coercion. The runtime host uses node.id as the
      // ValueKey for the State<>, so this must survive serialization.
      const node = IrStatefulNode(
        id: 'my_screen',
        fields: [
          IrStatefulFieldNode(
            name: 'n',
            initializer: LiteralNode(0),
            isFinal: false,
          ),
        ],
        body: ReturnNode(value: RefNode(['n'])),
      );
      final encoded = codec.encode(node);
      expect(encoded['id'], 'my_screen');
      final decoded = codec.decode(encoded) as IrStatefulNode;
      expect(decoded.id, 'my_screen');
      expect(decoded, node);
    });

    test('IrStatefulNode with multiple fields referencing earlier ones', () {
      const node = IrStatefulNode(
        fields: [
          IrStatefulFieldNode(
            name: 'a',
            initializer: LiteralNode(1),
            isFinal: false,
          ),
          IrStatefulFieldNode(
            name: 'b',
            initializer: ArithOpNode(
              op: ArithOp.add,
              left: RefNode(['a']),
              right: LiteralNode(1),
            ),
            isFinal: false,
          ),
        ],
        body: ReturnNode(value: RefNode(['b'])),
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('PayloadFunctionNode with expression body', () {
      const node = PayloadFunctionNode(
        name: 'describe',
        params: ['count'],
        body: ConditionalNode(
          condition: CompareOpNode(
            op: CompareOp.eq,
            left: RefNode(['count']),
            right: LiteralNode(0),
          ),
          thenBranch: LiteralNode('No items'),
          elseBranch: LiteralNode('Some items'),
        ),
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('PayloadFunctionCallNode with args', () {
      const node = PayloadFunctionCallNode(
        name: 'describe',
        args: [LiteralNode(3)],
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });

    test('ScreenWithFunctionsNode round-trips', () {
      const node = ScreenWithFunctionsNode(
        functions: [
          PayloadFunctionNode(
            name: 'greet',
            params: ['name'],
            body: LiteralNode('hello'),
          ),
        ],
        screenBody: PayloadFunctionCallNode(
          name: 'greet',
          args: [LiteralNode('world')],
        ),
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, node);
    });
  });
}
