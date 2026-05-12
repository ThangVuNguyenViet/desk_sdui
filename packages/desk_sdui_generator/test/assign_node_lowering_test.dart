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
      '_assign_node_temp_${DateTime.now().microsecondsSinceEpoch}.dart',
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
  group('AssignNode lowering', () {
    // Test 1: `var x = 0; final t = (x = x + 1); return Text(t);`
    // Should lower to LetNode(x, 0, LetNode(t, AssignNode(x, +(x, 1)), Widget)).
    test('var + assignment-as-expression in final init', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  var x = 0;
  final t = (x = x + 1);
  return Text('\$t');
}
''');
      final result = _lower(fnDecl);
      // Plan #11 (IrStatefulNode): leading `var x = 0` lowers to a stateful
      // field, not a LetNode. The trailing `final t = ...` becomes a LetNode
      // inside the IrStatefulNode body.
      expect(result.root, isA<IrStatefulNode>());
      final stateful = result.root as IrStatefulNode;
      expect(stateful.fields, hasLength(1));
      expect(stateful.fields.single.name, 'x');
      expect(stateful.fields.single.initializer, const LiteralNode(0));

      // Body: LetNode(t, AssignNode(x, +(x, 1)), Widget).
      expect(stateful.body, isA<LetNode>());
      final innerLet = stateful.body as LetNode;
      expect(innerLet.name, 't');
      expect(innerLet.value, isA<AssignNode>());
      final assign = innerLet.value as AssignNode;
      expect(assign.name, 'x');
      expect(assign.value, isA<ArithOpNode>());
      final arith = assign.value as ArithOpNode;
      expect(arith.op, ArithOp.add);
      expect(arith.left, const RefNode(['x']));
      expect(arith.right, const LiteralNode(1));
    });

    // Test 2: `final y = 5; y = 6;` should be rejected — y is final.
    test('rejects assignment to final binding', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  final y = 5;
  y = 6;
  return Text('\$y');
}
''');
      expect(
        () => _lower(fnDecl),
        throwsA(
          isA<LoweringError>().having(
            (e) => e.message,
            'message',
            contains('Cannot assign to final local "y"'),
          ),
        ),
      );
    });

    // Test 3: `x = 0;` without prior declaration should be rejected.
    test('rejects assignment to undeclared name', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  x = 0;
  return Text('hi');
}
''');
      expect(
        () => _lower(fnDecl),
        throwsA(
          isA<LoweringError>().having(
            (e) => e.message,
            'message',
            contains('no local binding visible'),
          ),
        ),
      );
    });

    // Test 4: compound assignment `x += 3` lowers to AssignNode(x, +(x, 3)).
    test('compound assignment += lowers to AssignNode with ArithOpNode', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  var x = 0;
  final t = (x += 3);
  return Text('\$t');
}
''');
      final result = _lower(fnDecl);
      // `var x = 0` is a stateful field; trailing `final t = (x += 3)` is a
      // LetNode in the body.
      final stateful = result.root as IrStatefulNode;
      expect(stateful.fields.single.name, 'x');
      final innerLet = stateful.body as LetNode;
      expect(innerLet.name, 't');
      final assign = innerLet.value as AssignNode;
      expect(assign.name, 'x');
      final arith = assign.value as ArithOpNode;
      expect(arith.op, ArithOp.add);
      expect(arith.left, const RefNode(['x']));
      expect(arith.right, const LiteralNode(3));
    });

    // Test 5: postfix increment `x++` as statement lowers to AssignNode.
    test('postfix increment as statement lowers to AssignNode', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  var x = 0;
  x++;
  return Text('\$x');
}
''');
      final result = _lower(fnDecl);
      // `var x = 0` → stateful field; statement `x++` → __stmt__ LetNode in
      // the body wrapping AssignNode(x, x + 1).
      final stateful = result.root as IrStatefulNode;
      expect(stateful.fields.single.name, 'x');
      expect(stateful.body, isA<LetNode>());
      final stmtLet = stateful.body as LetNode;
      expect(stmtLet.name, '__stmt__');
      expect(stmtLet.value, isA<AssignNode>());
      final assign = stmtLet.value as AssignNode;
      expect(assign.name, 'x');
      final arith = assign.value as ArithOpNode;
      expect(arith.op, ArithOp.add);
      expect(arith.left, const RefNode(['x']));
      expect(arith.right, const LiteralNode(1));
    });

    // Test 5b: postfix decrement `x--` as statement lowers to AssignNode
    // with ArithOp.sub and LiteralNode(1). Regression lock for the prior
    // `LiteralNode(-1)` bug that produced `x + (-1)` ≡ `x - 1` only when
    // op was sub — silently wrong if anyone ever read RefNode +/-/sub +/-1.
    test('postfix decrement as statement uses ArithOp.sub with LiteralNode(1)',
        () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  var x = 5;
  x--;
  return Text('\$x');
}
''');
      final result = _lower(fnDecl);
      final stateful = result.root as IrStatefulNode;
      expect(stateful.fields.single.name, 'x');
      final stmtLet = stateful.body as LetNode;
      expect(stmtLet.name, '__stmt__');
      final assign = stmtLet.value as AssignNode;
      expect(assign.name, 'x');
      final arith = assign.value as ArithOpNode;
      expect(arith.op, ArithOp.sub);
      expect(arith.left, const RefNode(['x']));
      expect(arith.right, const LiteralNode(1));
    });

    // Test 6: post-increment as expression (final t = x++) is rejected.
    test('rejects post-increment as expression', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  var x = 0;
  final t = x++;
  return Text('\$t');
}
''');
      expect(
        () => _lower(fnDecl),
        throwsA(
          isA<LoweringError>().having(
            (e) => e.message,
            'message',
            contains('Pre/post increment as an expression is not supported'),
          ),
        ),
      );
    });

    // Test 7: explicitly-typed declaration `int x = 0;` is treated as mutable.
    test('explicitly-typed declaration treated as mutable (var-like)', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  int x = 0;
  final t = (x = x + 1);
  return Text('\$t');
}
''');
      // Should not throw — typed-decl is mutable by default. Per Plan #11,
      // a leading mutable decl becomes a stateful field; the trailing
      // `final t = ...` becomes a LetNode in the body.
      final result = _lower(fnDecl);
      expect(result.root, isA<IrStatefulNode>());
      final stateful = result.root as IrStatefulNode;
      expect(stateful.fields.single.name, 'x');
      expect(stateful.body, isA<LetNode>());
    });
  });
}
