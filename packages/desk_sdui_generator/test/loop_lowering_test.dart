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
      '_loop_lowering_temp_${DateTime.now().microsecondsSinceEpoch}.dart',
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
  group('Loop lowering', () {
    // Test 1: while(cond) { body } lowers to WhileNode.
    test('while loop lowers to WhileNode', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  var x = 0;
  while (x < 3) {
    x = x + 1;
  }
  return Text('\$x');
}
''');
      final result = _lower(fnDecl);
      expect(result.root, isA<BlockNode>());
      final block = result.root as BlockNode;
      // statements: LetStatementNode(x), WhileNode, ReturnNode
      expect(block.statements, hasLength(3));
      expect(block.statements[0], isA<LetStatementNode>());
      expect(block.statements[1], isA<WhileNode>());
      final whileNode = block.statements[1] as WhileNode;
      expect(whileNode.condition, isA<CompareOpNode>());
      expect(block.statements[2], isA<ReturnNode>());
    });

    // Test 2: do { body } while(cond); lowers to DoNode.
    test('do-while loop lowers to DoNode', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  var x = 0;
  do {
    x = x + 1;
  } while (x < 3);
  return Text('\$x');
}
''');
      final result = _lower(fnDecl);
      expect(result.root, isA<BlockNode>());
      final block = result.root as BlockNode;
      expect(block.statements[1], isA<DoNode>());
      final doNode = block.statements[1] as DoNode;
      expect(doNode.condition, isA<CompareOpNode>());
      expect(doNode.body, isA<BlockNode>());
    });

    // Test 3: for(int i=0; i<n; i++) lowers to ImperativeForNode with all parts.
    test('C-style for loop lowers to ImperativeForNode', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  var sum = 0;
  for (var i = 0; i < 5; i = i + 1) {
    sum = sum + i;
  }
  return Text('\$sum');
}
''');
      final result = _lower(fnDecl);
      expect(result.root, isA<BlockNode>());
      final block = result.root as BlockNode;
      expect(block.statements[1], isA<ImperativeForNode>());
      final forNode = block.statements[1] as ImperativeForNode;
      expect(forNode.init, isA<LetStatementNode>());
      expect(forNode.condition, isA<CompareOpNode>());
      expect(forNode.update, isNotNull); // i = i + 1
      expect(forNode.body, isA<BlockNode>());
    });

    // Test 4: for(;;) lowers to ImperativeForNode with init/cond/update all null.
    test('for(;;) lowers to ImperativeForNode with null init/cond/update', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  for (;;) {
    return const Text('x');
  }
}
''');
      final result = _lower(fnDecl);
      expect(result.root, isA<BlockNode>());
      final block = result.root as BlockNode;
      expect(block.statements[0], isA<ImperativeForNode>());
      final forNode = block.statements[0] as ImperativeForNode;
      expect(forNode.init, isNull);
      expect(forNode.condition, isNull);
      expect(forNode.update, isNull);
    });

    // Test 5: for(var item in items) delegates to collection-for (ForNode).
    test('for-in loop lowers to ForNode (collection-for), not ImperativeForNode',
        () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s(List<String> items) {
  for (final item in items) {
    return Text(item);
  }
  return const Text('empty');
}
''');
      final result = _lower(fnDecl);
      expect(result.root, isA<BlockNode>());
      final block = result.root as BlockNode;
      expect(block.statements[0], isA<ForNode>());
      expect(block.statements[0], isNot(isA<ImperativeForNode>()));
    });

    // Multiple updaters → BlockNode of expression-statements. Mirrors
    // `for (var i=0, j=0; i<3; i = i+1, j = j+2)`.
    test('multiple for-updaters lower to BlockNode of assignments', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  for (var i = 0, j = 0; i < 3; i = i + 1, j = j + 2) {
  }
  return const Text('x');
}
''');
      final result = _lower(fnDecl);
      expect(result.root, isA<BlockNode>());
      final block = result.root as BlockNode;
      expect(block.statements[0], isA<ImperativeForNode>());
      final forNode = block.statements[0] as ImperativeForNode;
      // init is a BlockNode containing two LetStatementNodes (i, j).
      expect(forNode.init, isA<BlockNode>());
      final initBlock = forNode.init! as BlockNode;
      expect(initBlock.statements, hasLength(2));
      expect(initBlock.statements[0], isA<LetStatementNode>());
      expect((initBlock.statements[0] as LetStatementNode).name, 'i');
      expect((initBlock.statements[1] as LetStatementNode).name, 'j');
      // update is a BlockNode wrapping both assignments.
      expect(forNode.update, isA<BlockNode>());
      final updBlock = forNode.update! as BlockNode;
      expect(updBlock.statements, hasLength(2));
      expect(updBlock.statements[0], isA<AssignNode>());
      expect((updBlock.statements[0] as AssignNode).name, 'i');
      expect(updBlock.statements[1], isA<AssignNode>());
      expect((updBlock.statements[1] as AssignNode).name, 'j');
    });

    // Test 6: Labeled loop is rejected with LoweringError.
    test('labeled loop inside LabeledStatement is rejected', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  outer: while (true) {
    break outer;
  }
  return const Text('x');
}
''');
      expect(
        () => _lower(fnDecl),
        throwsA(isA<LoweringError>().having(
          (e) => e.message,
          'message',
          contains('Labeled'),
        )),
      );
    });
  });
}
