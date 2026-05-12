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

const _demoPackageRoot =
    '/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/packages/desk_sdui_demo';

Future<FunctionDeclaration> _resolveScreen(String source) async {
  final dir = Directory(p.join(_demoPackageRoot, 'lib'));
  final tempFile = File(
    p.join(
      dir.path,
      '_stateful_temp_${DateTime.now().microsecondsSinceEpoch}.dart',
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
  group('IrStatefulNode lowering', () {
    test('var counter = 0; return Text("\$counter") → IrStatefulNode with one field',
        () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  var counter = 0;
  return Text('\$counter');
}
''');
      final result = _lower(fnDecl);
      expect(result.root, isA<IrStatefulNode>());
      final stateful = result.root as IrStatefulNode;
      expect(stateful.fields, hasLength(1));
      expect(stateful.fields.single.name, 'counter');
      expect(stateful.fields.single.isFinal, isFalse);
      expect(stateful.fields.single.initializer, const LiteralNode(0));
      // Body is the lowered return-expr (a Widget at the top).
      expect(stateful.body, isA<WidgetNode>());
    });

    test('two var decls, second references first → two fields', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  var a = 0;
  var b = a + 1;
  return Text('\$b');
}
''');
      final result = _lower(fnDecl);
      expect(result.root, isA<IrStatefulNode>());
      final stateful = result.root as IrStatefulNode;
      expect(stateful.fields, hasLength(2));
      expect(stateful.fields[0].name, 'a');
      expect(stateful.fields[1].name, 'b');
      expect(stateful.fields[1].initializer, isA<ArithOpNode>());
    });

    test('final t = ...; return ... lowers to LetNode (not stateful)',
        () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  final t = 'hello';
  return Text(t);
}
''');
      final result = _lower(fnDecl);
      expect(result.root, isA<LetNode>());
      expect(result.root, isNot(isA<IrStatefulNode>()));
    });

    test('leading final breaks the field run — no IrStatefulNode emitted',
        () async {
      // Per the plan's decision rule: a leading `final` breaks the field
      // run, so the trailing `var x` is treated as a normal LetNode-bound
      // local rather than a stateful field.
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  final t = 'hi';
  var x = 0;
  return Text('\$t \$x');
}
''');
      final result = _lower(fnDecl);
      expect(result.root, isNot(isA<IrStatefulNode>()));
      expect(result.root, isA<LetNode>());
    });

    test('leading var run with trailing final still emits IrStatefulNode',
        () async {
      // `var a = 0; var b = 1; final c = a + b; return ...` → IrStatefulNode
      // with fields [a, b], body wraps a LetNode(c, ...).
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  var a = 0;
  var b = 1;
  final c = a + b;
  return Text('\$c');
}
''');
      final result = _lower(fnDecl);
      expect(result.root, isA<IrStatefulNode>());
      final stateful = result.root as IrStatefulNode;
      expect(stateful.fields.map((f) => f.name).toList(), ['a', 'b']);
      // The trailing `final c` becomes a LetNode inside the body.
      expect(stateful.body, isA<LetNode>());
      expect((stateful.body as LetNode).name, 'c');
    });
  });
}
