import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui_generator/src/screen_lowering/widget_lowerer.dart';
import 'package:test/test.dart';

void main() {
  IrNode lowerWidget(String src) {
    final result = parseString(content: 'Widget _() => $src;');
    final func = result.unit.declarations.single as FunctionDeclaration;
    final body = func.functionExpression.body as ExpressionFunctionBody;
    final expr = body.expression;
    if (expr is InstanceCreationExpression) {
      return lowerWidgetInstance(expr);
    }
    if (expr is MethodInvocation && expr.target == null) {
      return lowerWidgetInvocation(expr);
    }
    throw Exception('Expected widget expression, got ${expr.runtimeType}');
  }

  IrNode lowerInList(String src) {
    final result = parseString(content: 'final _ = [$src];');
    final decl = result.unit.declarations.single as TopLevelVariableDeclaration;
    final init = decl.variables.variables.single.initializer! as ListLiteral;
    final element = init.elements.first;
    if (element is IfElement) {
      return lowerListElement(element);
    }
    if (element is ForElement) {
      return lowerListElement(element);
    }
    throw Exception('Expected IfElement or ForElement');
  }

  test('Column with empty children → WidgetNode', () {
    final ir = lowerWidget('Column(children: [])') as WidgetNode;
    expect(ir.name, 'Column');
    expect((ir.args['children']! as ListNode).children, isEmpty);
  });

  test('Text with positional arg → args.data', () {
    final ir = lowerWidget("Text('hello')") as WidgetNode;
    expect(ir.name, 'Text');
    expect((ir.args['data']! as LiteralNode).value, 'hello');
  });

  test('if-element in list → ConditionalNode', () {
    final ir = lowerInList('if (cond) Text("yes")') as ConditionalNode;
    expect((ir.condition as RefNode).path, ['cond']);
    expect(ir.thenBranch, isA<WidgetNode>());
  });

  test('for-element in list → ForNode', () {
    final ir = lowerInList('for (final x in items) Text(x)') as ForNode;
    expect(ir.variable, 'x');
    expect((ir.source as RefNode).path, ['items']);
    expect(ir.body, isA<WidgetNode>());
  });

  test('nested widget in args', () {
    final ir = lowerWidget("Column(children: [Text('hi')])") as WidgetNode;
    expect(ir.name, 'Column');
    final children = (ir.args['children']! as ListNode).children;
    expect(children.single, isA<WidgetNode>());
    expect((children.single as WidgetNode).name, 'Text');
  });
}
