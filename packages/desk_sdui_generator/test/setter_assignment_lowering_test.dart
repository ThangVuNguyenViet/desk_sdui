// ignore_for_file: deprecated_member_use
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui_generator/src/screen_lowering/ast_to_ir.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final _demoPackageRoot = p.normalize(
  p.join(Directory.current.path, '..', 'desk_sdui_demo'),
);

/// Resolve [source] inside the demo package context (so `package:` imports
/// resolve) and return the first @Screen-shaped top-level FunctionDeclaration.
Future<FunctionDeclaration> _resolveScreen(String source) async {
  final dir = Directory(p.join(_demoPackageRoot, 'lib'));
  final tempFile = File(
    p.join(
      dir.path,
      '_setter_lowering_temp_${DateTime.now().microsecondsSinceEpoch}.dart',
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
  return lowerScreen(fnDecl, ScreenAnnotationData(name: 's'));
}

/// Find the first [SetterCallNode] inside [root] via a structural walk over the
/// statement-level constructors used by the simple-block lowering path
/// (LetNode/__stmt__ chain, plus a few common containers).
SetterCallNode? _findSetterCall(IrNode root) {
  if (root is SetterCallNode) return root;
  if (root is LetNode) {
    final inValue = _findSetterCall(root.value);
    if (inValue != null) return inValue;
    return _findSetterCall(root.body);
  }
  if (root is BlockNode) {
    for (final s in root.statements) {
      final hit = _findSetterCall(s);
      if (hit != null) return hit;
    }
  }
  if (root is IrStatefulNode) {
    return _findSetterCall(root.body);
  }
  if (root is SequenceNode) {
    for (final s in root.steps) {
      final hit = _findSetterCall(s);
      if (hit != null) return hit;
    }
    return _findSetterCall(root.returnExpr);
  }
  return null;
}

void main() {
  group('SetterCallNode lowering', () {
    // Test 1 — successful lowering of `vm.field = literal` inside a screen
    // body. The expression statement is wrapped in a `LetNode(__stmt__, ...)`
    // by the simple-block path. The wrapped value must be a SetterCallNode
    // with the expected setterKey and a literal RHS.
    test('simple property assignment lowers to SetterCallNode', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

@Register([CounterVm])
class CounterVm {
  int count = 0;
}

@Screen('s')
Widget s(CounterVm vm) {
  vm.count = 5;
  return Text('hi');
}
''');

      final result = _lower(fnDecl);
      final setter = _findSetterCall(result.root);
      expect(setter, isNotNull,
          reason: 'Expected a SetterCallNode in the screen body, '
              'got: ${result.root}');
      expect(setter!.setterKey, equals('CounterVm.count'));
      expect(setter.value, isA<LiteralNode>());
      expect((setter.value as LiteralNode).value, equals(5));
      expect(setter.target, isA<RefNode>());
      expect((setter.target as RefNode).path, equals(['vm']));
    });

    // Test 2 — lowering of `vm.field = expr` on a NON-@Register class. Per
    // the lowerer's design, type registry membership is not enforced at
    // lowering time: the receiver type's simple class name is taken
    // verbatim as the setter key prefix, and any "this type isn't actually
    // registered" failure surfaces at runtime in `Runtime.invokeSetter`.
    // Therefore lowering MUST succeed and produce a SetterCallNode whose
    // setterKey reflects the (unregistered) class name.
    test('unregistered class still lowers (runtime checks registration)',
        () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

class UnregisteredVm {
  int field = 0;
}

Widget s(UnregisteredVm vm) {
  vm.field = 5;
  return Text('hi');
}
''');

      final result = _lower(fnDecl);
      final setter = _findSetterCall(result.root);
      expect(setter, isNotNull);
      expect(setter!.setterKey, equals('UnregisteredVm.field'));
      expect(setter.value, isA<LiteralNode>());
      expect((setter.value as LiteralNode).value, equals(5));
    });

    // Test 3 — compound assignment `vm.count += 5` reads the current value
    // via GetterNode (using the same setterKey as the field's qualified
    // identifier) and stores `current + 5` back via SetterCallNode.
    test('compound assignment lowers to SetterCallNode with arith value',
        () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

@Register([CounterVm])
class CounterVm {
  int count = 0;
}

@Screen('s')
Widget s(CounterVm vm) {
  vm.count += 5;
  return Text('hi');
}
''');

      final result = _lower(fnDecl);
      final setter = _findSetterCall(result.root);
      expect(setter, isNotNull);
      expect(setter!.setterKey, equals('CounterVm.count'));
      expect(setter.target, isA<RefNode>());
      expect((setter.target as RefNode).path, equals(['vm']));

      final value = setter.value;
      expect(value, isA<ArithOpNode>());
      final arith = value as ArithOpNode;
      expect(arith.op, equals(ArithOp.add));
      expect(arith.left, isA<GetterNode>());
      final getter = arith.left as GetterNode;
      expect(getter.name, equals('CounterVm.count'));
      expect(getter.receiver, isA<RefNode>());
      expect((getter.receiver as RefNode).path, equals(['vm']));
      expect(arith.right, isA<LiteralNode>());
      expect((arith.right as LiteralNode).value, equals(5));
    });
  });
}
