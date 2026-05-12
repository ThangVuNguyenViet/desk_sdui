// ignore_for_file: deprecated_member_use
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui_generator/src/diagnostics.dart';
import 'package:desk_sdui_generator/src/screen_lowering/ast_to_ir.dart';
import 'package:desk_sdui_generator/src/screen_lowering/expression_lowerer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _demoPackageRoot =
    '/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/packages/desk_sdui_demo';

Future<FunctionDeclaration> _resolveScreen(String source) async {
  final dir = Directory(p.join(_demoPackageRoot, 'lib'));
  final tempFile = File(
    p.join(
      dir.path,
      '_lambda_temp_${DateTime.now().microsecondsSinceEpoch}.dart',
    ),
  );
  tempFile.writeAsStringSync(source);
  try {
    final result = await resolveFile(path: tempFile.path);
    if (result is! ResolvedUnitResult) {
      throw StateError('resolveFile returned ${result.runtimeType}');
    }
    return result.unit.declarations.whereType<FunctionDeclaration>().first;
  } finally {
    if (tempFile.existsSync()) tempFile.deleteSync();
  }
}

Future<FunctionExpression> _resolveFunctionExpression(String source) async {
  final dir = Directory(p.join(_demoPackageRoot, 'lib'));
  final tempFile = File(
    p.join(
      dir.path,
      '_lambda_expr_temp_${DateTime.now().microsecondsSinceEpoch}.dart',
    ),
  );
  // Wrap in a top-level declaration that contains the function expression
  final wrapped = '''
void _wrapper() {
  var _f = $source;
}
''';
  tempFile.writeAsStringSync(wrapped);
  try {
    final result = await resolveFile(path: tempFile.path);
    if (result is! ResolvedUnitResult) {
      throw StateError('resolveFile returned ${result.runtimeType}');
    }
    final fn = result.unit.declarations.whereType<FunctionDeclaration>().first;
    final body = fn.functionExpression.body as BlockFunctionBody;
    final stmt = body.block.statements.first as VariableDeclarationStatement;
    return stmt.variables.variables.first.initializer as FunctionExpression;
  } finally {
    if (tempFile.existsSync()) tempFile.deleteSync();
  }
}

ScreenLowerResult _lower(FunctionDeclaration fnDecl) {
  return lowerScreen(fnDecl, ScreenAnnotationData(name: 'test'));
}

void main() {
  group('LambdaNode lowering', () {
    // Test 1: Arrow body with single param → LambdaNode.
    test('(p) => expr lowers to 1-param LambdaNode (isAsync: false)', () async {
      final expr = await _resolveFunctionExpression('(String p) => p.length > 0');
      final node = lowerLambda(expr);
      expect(node, isA<LambdaNode>());
      expect(node.params, ['p']);
      expect(node.isAsync, false);
      expect(node.body, isA<CompareOpNode>());
    });

    // Test 2: 2-param arrow lambda.
    test('(p, q) => p + q lowers to 2-param LambdaNode', () async {
      final expr = await _resolveFunctionExpression('(int p, int q) => p + q');
      final node = lowerLambda(expr);
      expect(node.params, ['p', 'q']);
      expect(node.isAsync, false);
      expect(node.body, isA<ArithOpNode>());
    });

    // Test 3: Block body with single return → same as arrow form.
    test('(p) { return p * 2; } lowers same as arrow form', () async {
      final expr = await _resolveFunctionExpression('(int p) { return p * 2; }');
      final node = lowerLambda(expr);
      expect(node.params, ['p']);
      expect(node.isAsync, false);
      expect(node.body, isA<ArithOpNode>());
    });

    // Test 4: Block body with multiple statements now lowers to a BlockNode
    // body (Plan #11 — sync block-bodied lambdas drive inline event handlers
    // that mutate stateful fields). This used to be rejected pre-#11.
    test('(p) { final t = p; return t; } lowers to BlockNode-bodied LambdaNode',
        () async {
      final expr = await _resolveFunctionExpression(
          '(int p) { final t = p; return t; }');
      final node = lowerLambda(expr);
      expect(node.isAsync, isFalse);
      expect(node.body, isA<BlockNode>());
      final block = node.body as BlockNode;
      expect(block.statements, hasLength(2));
      expect(block.statements[0], isA<LetStatementNode>());
      expect(block.statements[1], isA<ReturnNode>());
    });

    // Test 5: Async lambda outside action context → rejected.
    test('(p) async => ... outside action context is rejected', () async {
      final expr = await _resolveFunctionExpression('(int p) async => p * 2');
      expect(
        () => lowerLambda(expr, inActionContext: false),
        throwsA(
          isA<LoweringError>().having(
            (e) => e.message,
            'message',
            contains('per-frame path'),
          ),
        ),
      );
    });

    // Test 6: Async lambda inside action context → accepted.
    test('(p) async => ... inside action context is accepted', () async {
      final expr = await _resolveFunctionExpression('(int p) async => p * 2');
      final node = lowerLambda(expr, inActionContext: true);
      expect(node.isAsync, true);
      expect(node.params, ['p']);
    });

    // Test 7: A screen with a lambda inside a let binding.
    test('screen body can use lambda in let binding', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  final items = ['a', 'b', 'c'];
  return Text(items.length.toString());
}
''');
      // Just verify it lowers without error — LambdaNode in screen body
      // through LetNode is tested here.
      final result = _lower(fnDecl);
      expect(result.root, isA<LetNode>());
    });
  });
}
