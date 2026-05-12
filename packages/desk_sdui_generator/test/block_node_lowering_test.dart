// ignore_for_file: deprecated_member_use
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui_generator/src/diagnostics.dart';
import 'package:desk_sdui_generator/src/screen_lowering/ast_to_ir.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _demoPackageRoot =
    '/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/packages/desk_sdui_demo';

Future<FunctionDeclaration> _resolveScreen(String source) async {
  final dir = Directory(p.join(_demoPackageRoot, 'lib'));
  final tempFile = File(
    p.join(
      dir.path,
      '_block_node_temp_${DateTime.now().microsecondsSinceEpoch}.dart',
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

ScreenLowerResult _lower(FunctionDeclaration fnDecl) {
  return lowerScreen(fnDecl, ScreenAnnotationData(name: 'test'));
}

void main() {
  group('BlockNode lowering', () {
    // Test 1: block body with var decl + if + return lowers to BlockNode
    // containing LetStatementNode + IfStatementNode + ReturnNode.
    test('var x = 0; if (x < 1) { x = x + 1; } return x → BlockNode', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  var x = 0;
  if (x < 1) {
    x = x + 1;
  }
  return Text('\$x');
}
''');
      final result = _lower(fnDecl);
      expect(result.root, isA<BlockNode>());
      final block = result.root as BlockNode;
      expect(block.statements, hasLength(3));

      // First statement: LetStatementNode (var x = 0)
      expect(block.statements[0], isA<LetStatementNode>());
      final letStmt = block.statements[0] as LetStatementNode;
      expect(letStmt.name, 'x');
      expect(letStmt.isFinal, isFalse);
      expect(letStmt.value, const LiteralNode(0));

      // Second statement: IfStatementNode
      expect(block.statements[1], isA<IfStatementNode>());
      final ifStmt = block.statements[1] as IfStatementNode;
      expect(ifStmt.cond, isA<CompareOpNode>());

      // Then-branch: BlockNode containing AssignNode
      expect(ifStmt.then, isA<BlockNode>());
      final thenBlock = ifStmt.then as BlockNode;
      expect(thenBlock.statements, hasLength(1));
      expect(thenBlock.statements[0], isA<AssignNode>());

      // No else branch
      expect(ifStmt.else_, isNull);

      // Third statement: ReturnNode
      expect(block.statements[2], isA<ReturnNode>());
      final ret = block.statements[2] as ReturnNode;
      expect(ret.value, isNotNull);
    });

    // Test 2: a multi-statement screen body with early-return inside an if
    // branch lowers to BlockNode([IfStatementNode, ReturnNode]).
    //
    // NOTE: bare `return;` (no value) is unreachable from @Screen bodies
    // because every screen path must return a Widget. It will be exercised
    // when Plan #12 (payload functions with imperative bodies) lands.
    // The `value: null` constructor and FlowReturn(null) shape are covered
    // directly in block_node_eval_test.dart by constructing IR nodes.
    test('if-with-return + trailing return → BlockNode([If, Return])', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  if (true) {
    return const Text('a');
  }
  return const Text('b');
}
''');
      final result = _lower(fnDecl);
      expect(result.root, isA<BlockNode>());
      final block = result.root as BlockNode;
      // The if + final return
      expect(block.statements, hasLength(2));
      expect(block.statements[0], isA<IfStatementNode>());
      expect(block.statements[1], isA<ReturnNode>());
      // Trailing return has a non-null value.
      expect((block.statements[1] as ReturnNode).value, isNotNull);
    });

    // Test 3: labeled break should throw a LoweringError.
    test('labeled break is rejected with LoweringError', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  outer: {
    break outer;
  }
  return const Text('x');
}
''');
      expect(
        () => _lower(fnDecl),
        throwsA(isA<LoweringError>()),
      );
    });

    // Test 4: labeled statements are rejected with a user-actionable
    // LoweringError naming the offending label.
    test('labeled statements rejected with named LoweringError', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  myLabel: {}
  return const Text('x');
}
''');
      expect(
        () => _lower(fnDecl),
        throwsA(
          isA<LoweringError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Labeled statements are not supported'),
              contains('myLabel'),
            ),
          ),
        ),
      );
    });

    // Test 5: if/else lowers correctly with both branches.
    test('if/else lowers to IfStatementNode with both branches', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  if (true) {
    return const Text('yes');
  } else {
    return const Text('no');
  }
}
''');
      final result = _lower(fnDecl);
      expect(result.root, isA<BlockNode>());
      final block = result.root as BlockNode;
      expect(block.statements, hasLength(1));
      final ifStmt = block.statements[0] as IfStatementNode;
      expect(ifStmt.then, isA<BlockNode>());
      expect(ifStmt.else_, isA<BlockNode>());
    });
  });
}
