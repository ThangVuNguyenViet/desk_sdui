import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui_generator/src/screen_lowering/widget_lowerer.dart';
import 'package:test/test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Lowerer tests
  // ---------------------------------------------------------------------------

  IrNode lowerInstance(String src) {
    final result = parseString(content: 'dynamic _() => $src;');
    final func = result.unit.declarations.single as FunctionDeclaration;
    final body = func.functionExpression.body as ExpressionFunctionBody;
    final expr = body.expression;
    if (expr is InstanceCreationExpression) {
      return lowerWidgetInstance(expr);
    }
    throw Exception('Expected InstanceCreationExpression, got ${expr.runtimeType}');
  }

  group('Lowerer — typeArgs capture', () {
    /// Lowers a widget expression, which may be an InstanceCreationExpression
    /// or a MethodInvocation (the unresolved parser produces the latter for
    /// `MyType<GenericItem>()`).
    WidgetNode lowerWidgetExpr(String src) {
      final result = parseString(content: 'Widget _() => $src;');
      final func = result.unit.declarations.single as FunctionDeclaration;
      final body = func.functionExpression.body as ExpressionFunctionBody;
      final expr = body.expression;
      if (expr is InstanceCreationExpression) {
        return lowerWidgetInstance(expr) as WidgetNode;
      }
      if (expr is MethodInvocation) {
        return lowerWidgetInvocation(expr) as WidgetNode;
      }
      throw Exception('Unexpected expr type: ${expr.runtimeType}');
    }

    test('generic ctor with single type arg → typeArgs list', () {
      // The unresolved parser often produces a MethodInvocation for
      // `MyType<GenericItem>()`. lowerWidgetInvocation captures typeArguments.
      final ir = lowerWidgetExpr('MyType<GenericItem>()');
      expect(ir.typeArgs, equals(['GenericItem']));
    });

    test('two type args', () {
      final ir = lowerWidgetExpr('MapHolder<String, Int>()');
      expect(ir.typeArgs, equals(['String', 'Int']));
    });

    test('non-generic ctor → typeArgs is null', () {
      final ir = lowerWidgetExpr('Padding()');
      expect(ir.typeArgs, isNull);
    });

    test('WidgetNode with typeArgs preserves them in equality', () {
      const a = WidgetNode(name: 'List', args: {}, typeArgs: ['MyType']);
      const b = WidgetNode(name: 'List', args: {}, typeArgs: ['MyType']);
      const c = WidgetNode(name: 'List', args: {});
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  // ---------------------------------------------------------------------------
  // ValueCtorNode / MethodCallNode typeArgs equality tests
  // ---------------------------------------------------------------------------

  group('IR node typeArgs equality', () {
    test('ValueCtorNode with typeArgs', () {
      const a = ValueCtorNode(name: 'List', args: [], typeArgs: ['MyType']);
      const b = ValueCtorNode(name: 'List', args: [], typeArgs: ['MyType']);
      const c = ValueCtorNode(name: 'List', args: []);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('MethodCallNode with typeArgs', () {
      const a = MethodCallNode(receiver: null, name: 'fetch', args: [], typeArgs: ['MyType']);
      const b = MethodCallNode(receiver: null, name: 'fetch', args: [], typeArgs: ['MyType']);
      const c = MethodCallNode(receiver: null, name: 'fetch', args: []);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  // ---------------------------------------------------------------------------
  // JSON round-trip tests (via JsonIrCodec)
  // ---------------------------------------------------------------------------

  group('JSON round-trip — typeArgs', () {
    const codec = JsonIrCodec();

    test('WidgetNode with typeArgs round-trips', () {
      const node = WidgetNode(
        name: 'List',
        args: {},
        typeArgs: ['MyType'],
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, equals(node));
    });

    test('WidgetNode without typeArgs round-trips (null preserved)', () {
      const node = WidgetNode(name: 'Padding', args: {});
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, equals(node));
      expect((decoded as WidgetNode).typeArgs, isNull);
    });

    test('ValueCtorNode with typeArgs round-trips', () {
      const node = ValueCtorNode(name: 'List', args: [], typeArgs: ['String', 'int']);
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, equals(node));
    });

    test('MethodCallNode with typeArgs round-trips', () {
      const node = MethodCallNode(
        receiver: null,
        name: 'fetch',
        args: [],
        typeArgs: ['MyType'],
      );
      final encoded = codec.encode(node);
      final decoded = codec.decode(encoded);
      expect(decoded, equals(node));
    });
  });
}
