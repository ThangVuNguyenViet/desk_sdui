import 'package:flutter_test/flutter_test.dart';
import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui/src/expression_eval.dart';

class _Foo {}

class _Bar {}

void main() {
  group('IsTypeNode eval', () {
    late Runtime rt;

    setUp(() {
      rt = Runtime();
      rt.registerTypeCheck('_Foo', (v) => v is _Foo);
      rt.registerTypeCheck('_Bar', (v) => v is _Bar);
    });

    test('returns true when receiver is the registered type', () {
      final foo = _Foo();
      final node = IsTypeNode(
        receiver: RefNode(['val']),
        typeName: '_Foo',
      );
      expect(evalExpression(node, {'val': foo}, rt), isTrue);
    });

    test('returns false when receiver is a different type', () {
      final bar = _Bar();
      final node = IsTypeNode(
        receiver: RefNode(['val']),
        typeName: '_Foo',
      );
      expect(evalExpression(node, {'val': bar}, rt), isFalse);
    });

    test('returns false when receiver is null', () {
      final node = IsTypeNode(
        receiver: RefNode(['val']),
        typeName: '_Foo',
      );
      expect(evalExpression(node, {'val': null}, rt), isFalse);
    });

    test('throws StateError for unregistered type name', () {
      final node = IsTypeNode(
        receiver: RefNode(['val']),
        typeName: 'UnknownType',
      );
      expect(
        () => evalExpression(node, {'val': _Foo()}, rt),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('No type check registered'),
        )),
      );
    });

    test('type check works with LetNode scrutinee hoist', () {
      final foo = _Foo();
      // Let's verify IsTypeNode in a LetNode value context (common switch lowering pattern).
      // LetNode(name='s', value=RefNode(['val']), body=IsTypeNode(RefNode(['s']), '_Foo'))
      final node = LetNode(
        name: 's',
        value: RefNode(['val']),
        body: IsTypeNode(
          receiver: RefNode(['s']),
          typeName: '_Foo',
        ),
      );
      expect(evalExpression(node, {'val': foo}, rt), isTrue);
      expect(evalExpression(node, {'val': _Bar()}, rt), isFalse);
    });
  });
}
