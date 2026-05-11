import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui_generator/src/screen_lowering/widget_lowerer.dart';
import 'package:path/path.dart' as p;
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

  /// Lowers a widget arg expression (a named-arg value in a widget call).
  IrNode lowerArg(String argSrc) {
    // Wrap in a Padding call so the arg is in an arg slot
    final result = parseString(
        content: 'Widget _() => Padding(padding: $argSrc, child: null);');
    final func = result.unit.declarations.single as FunctionDeclaration;
    final body = func.functionExpression.body as ExpressionFunctionBody;
    final expr = body.expression;
    if (expr is MethodInvocation) {
      // lowerWidgetInvocation lowers all args — extract the 'padding' one
      final ir = lowerWidgetInvocation(expr) as WidgetNode;
      return ir.args['padding']!;
    }
    if (expr is InstanceCreationExpression) {
      final ir = lowerWidgetInstance(expr) as WidgetNode;
      return ir.args['padding']!;
    }
    throw Exception('Expected MethodInvocation, got ${expr.runtimeType}');
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

  test('for-element with wildcard loop var → ForNode', () {
    final ir = lowerInList('for (final _ in items) Text("x")') as ForNode;
    expect(ir.variable, '_');
    expect((ir.source as RefNode).path, ['items']);
    expect(ir.body, isA<WidgetNode>());
  });

  test('for-element wildcard body ref → LiteralNode(null)', () {
    final ir = lowerInList('for (final _ in items) Text(_)') as ForNode;
    expect(ir.variable, '_');
    final body = ir.body as WidgetNode;
    expect((body.args['data']! as LiteralNode).value, isNull);
  });

  test('nested widget in args', () {
    final ir = lowerWidget("Column(children: [Text('hi')])") as WidgetNode;
    expect(ir.name, 'Column');
    final children = (ir.args['children']! as ListNode).children;
    expect(children.single, isA<WidgetNode>());
    expect((children.single as WidgetNode).name, 'Text');
  });

  // ── Value-constructor qualified-name tests ──────────────────────────────
  // Regression for: IR emitted unqualified `'only'` instead of `'EdgeInsets.only'`
  // which caused `Bad state: Widget "only" is not registered` at runtime.

  test('const EdgeInsets.only → WidgetNode with qualified name', () {
    final ir = lowerArg('const EdgeInsets.only(top: 8)') as WidgetNode;
    expect(ir.name, 'EdgeInsets.only',
        reason: 'Must use qualified name so the value-builder registry can find it');
    expect((ir.args['top']! as LiteralNode).value, 8);
  });

  test('const EdgeInsets.fromLTRB → WidgetNode with qualified name', () {
    final ir =
        lowerArg('const EdgeInsets.fromLTRB(24, 10, 24, 22)') as WidgetNode;
    expect(ir.name, 'EdgeInsets.fromLTRB');
    expect((ir.args['arg0']! as LiteralNode).value, 24);
    expect((ir.args['arg1']! as LiteralNode).value, 10);
  });

  test('const EdgeInsets.symmetric → WidgetNode with qualified name', () {
    final ir = lowerArg(
            'const EdgeInsets.symmetric(horizontal: 8, vertical: 3)')
        as WidgetNode;
    expect(ir.name, 'EdgeInsets.symmetric');
    expect((ir.args['horizontal']! as LiteralNode).value, 8);
    expect((ir.args['vertical']! as LiteralNode).value, 3);
  });

  test('const BorderRadius.circular → WidgetNode with qualified name', () {
    final ir = lowerArg('const BorderRadius.circular(26)') as WidgetNode;
    expect(ir.name, 'BorderRadius.circular');
    expect((ir.args['arg0']! as LiteralNode).value, 26);
  });

  test('BorderRadius.circular (no const) → WidgetNode with qualified name', () {
    final ir = lowerArg('BorderRadius.circular(26)') as WidgetNode;
    expect(ir.name, 'BorderRadius.circular');
    expect((ir.args['arg0']! as LiteralNode).value, 26);
  });

  test('simple widget stays unqualified', () {
    final ir = lowerWidget('Column(children: [])') as WidgetNode;
    expect(ir.name, 'Column', reason: 'Simple widgets must keep their plain name');
  });

  test('const Color stays unqualified', () {
    // Color is a simple class name (no dot), should remain 'Color'
    final ir = lowerArg('const Color(0xFF2D5F2D)') as WidgetNode;
    expect(ir.name, 'Color');
  });

  // ── Static method call tests ────────────────────────────────────────────
  // Regression for: Theme.of(context) lowered with context as receiver instead
  // of as a flat callable (receiver: null).

  test('Theme.of(context) → MethodCallNode with null receiver', () {
    final ir = lowerArg('Theme.of(context)') as MethodCallNode;
    expect(ir.name, 'Theme.of');
    expect(ir.receiver, isNull,
        reason: 'Static methods must have null receiver (flat callable)');
    expect(ir.args, hasLength(1));
    expect(ir.args.first, isA<RefNode>());
    expect((ir.args.first as RefNode).path, ['context']);
  });

  test('MediaQuery.sizeOf(context) → MethodCallNode with null receiver', () {
    final ir = lowerArg('MediaQuery.sizeOf(context)') as MethodCallNode;
    expect(ir.name, 'MediaQuery.sizeOf');
    expect(ir.receiver, isNull);
    expect(ir.args, hasLength(1));
    expect((ir.args.first as RefNode).path, ['context']);
  });

  // ── Dot-shorthand tests ─────────────────────────────────────────────────
  // These require full resolution (parseString won't produce DotShorthand* nodes).

  const _demoPackageRoot =
      '/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/packages/desk_sdui_demo';

  Future<ResolvedUnitResult> _resolveSource(String source) async {
    final dir = Directory(p.join(_demoPackageRoot, 'lib'));
    final tempFile = File(
      p.join(
        dir.path,
        '_wl_temp_${DateTime.now().microsecondsSinceEpoch}.dart',
      ),
    );
    tempFile.writeAsStringSync(source);
    try {
      final result = await resolveFile(path: tempFile.path);
      if (result is! ResolvedUnitResult) {
        throw StateError('resolveFile returned ${result.runtimeType}');
      }
      return result;
    } finally {
      if (tempFile.existsSync()) tempFile.deleteSync();
    }
  }

  test('dot-shorthand .all() lowers to EdgeInsetsGeometry.all', () async {
    final result = await _resolveSource('''
import 'package:flutter/material.dart';
Widget s() => Padding(padding: .all(8), child: SizedBox());
''');
    final func = result.unit.declarations.whereType<FunctionDeclaration>().first;
    final body = func.functionExpression.body as ExpressionFunctionBody;
    final expr = body.expression;
    final WidgetNode ir;
    if (expr is InstanceCreationExpression) {
      ir = lowerWidgetInstance(expr) as WidgetNode;
    } else if (expr is MethodInvocation) {
      ir = lowerWidgetInvocation(expr) as WidgetNode;
    } else {
      throw Exception('Expected widget expression, got ${expr.runtimeType}');
    }
    final paddingArg = ir.args['padding'];
    expect(paddingArg, isA<WidgetNode>());
    expect((paddingArg as WidgetNode).name, 'EdgeInsetsGeometry.all',
        reason:
            'Dot-shorthand .all() in an EdgeInsetsGeometry slot must lower to '
            'EdgeInsetsGeometry.all (the analyzer\'s resolved element)');
    expect((paddingArg.args['arg0'] as LiteralNode).value, 8);
  });
}
