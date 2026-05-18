import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui_annotation/src/ir/codec/json_ir_codec.dart';

void main() {
  group('Codec round-trip', () {
    const codec = JsonIrCodec();

    test('AsTypeNode round-trip', () {
      final node = AsTypeNode(
        operand: RefNode(['x']),
        typeName: 'Order',
        nullable: true,
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, equals(node));
    });

    test('RuntimeTypeRefNode round-trip', () {
      final node = RuntimeTypeRefNode(operand: RefNode(['obj']));
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, equals(node));
    });

    test('PayloadClassNode round-trip', () {
      final node = PayloadClassNode(
        name: 'Order',
        supertypeName: 'Base',
        mixinNames: ['M1', 'M2'],
        fields: [
          PayloadFieldDeclNode(name: 'id', isFinal: true),
          PayloadFieldDeclNode(name: 'total', initializer: LiteralNode(0.0), isFinal: false),
        ],
        ctors: [
          PayloadCtorNode(
            name: '',
            params: ['id', 'total'],
            fieldInits: [
              PayloadFieldInitNode(fieldName: 'id', value: RefNode(['id'])),
            ],
          ),
        ],
        methods: [
          PayloadFunctionNode(name: 'toString', params: [], body: LiteralNode('')),
        ],
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, equals(node));
    });

    test('PayloadInstanceCreationNode round-trip', () {
      final node = PayloadInstanceCreationNode(
        className: 'Order',
        ctorName: 'named',
        args: {
          'id': LiteralNode('abc'),
          'total': LiteralNode(9.99),
        },
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, equals(node));
    });

    test('ScreenWithFunctionsNode with classes round-trip', () {
      final node = ScreenWithFunctionsNode(
        functions: [],
        classes: [
          PayloadClassNode(
            name: 'Order',
            fields: [PayloadFieldDeclNode(name: 'id', isFinal: true)],
            ctors: [PayloadCtorNode(name: '', params: ['id'], fieldInits: [])],
            methods: [],
          ),
        ],
        screenBody: LiteralNode(null),
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, equals(node));
    });
  });
}
