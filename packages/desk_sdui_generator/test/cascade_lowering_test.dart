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
      '_cascade_temp_${DateTime.now().microsecondsSinceEpoch}.dart',
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
  group('Cascade lowering', () {
    test('obj..a()..b() lowers to LetNode wrapping SequenceNode with 2 steps',
        () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s(TextEditingController c) {
  return TextField(
    controller: c..clear()..clear(),
  );
}
''');
      final result = _lower(fnDecl);
      // The TextField's controller arg should contain a LetNode wrapping a SequenceNode.
      final root = result.root as WidgetNode;
      final controllerNode = root.args['controller']!;
      expect(controllerNode, isA<LetNode>());
      final let = controllerNode as LetNode;
      expect(let.name, startsWith('__cas'));
      expect(let.value, isA<RefNode>());
      expect((let.value as RefNode).path, ['c']);
      expect(let.body, isA<SequenceNode>());
      final seq = let.body as SequenceNode;
      expect(seq.steps.length, 2);
      // Steps should be MethodCallNode with the receiver being the let-bound ref.
      final step0 = seq.steps[0] as MethodCallNode;
      expect(step0.receiver, isA<RefNode>());
      expect((step0.receiver as RefNode).path, [let.name]);
      expect(step0.name, 'clear');
      final step1 = seq.steps[1] as MethodCallNode;
      expect(step1.name, 'clear');
      // returnExpr is the let-bound ref.
      expect(seq.returnExpr, isA<RefNode>());
      expect((seq.returnExpr as RefNode).path, [let.name]);
    });

    test('cascade returns the receiver, not the last step value', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s(TextEditingController c) {
  return TextField(
    controller: c..clear()..clear(),
  );
}
''');
      final result = _lower(fnDecl);
      final root = result.root as WidgetNode;
      final let = root.args['controller']! as LetNode;
      final seq = let.body as SequenceNode;
      // returnExpr must reference the cascade receiver, not any step's result.
      final returnRef = seq.returnExpr as RefNode;
      expect(returnRef.path, [let.name]);
    });

    test(
        'setter cascade ..text = x lowers with MethodCallNode named "text="',
        () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s(TextEditingController c) {
  return TextField(
    controller: c..text = 'hi',
  );
}
''');
      final result = _lower(fnDecl);
      final root = result.root as WidgetNode;
      final let = root.args['controller']! as LetNode;
      final seq = let.body as SequenceNode;
      expect(seq.steps.length, 1);
      final step = seq.steps[0] as MethodCallNode;
      expect(step.name, 'text=');
      expect(step.args.length, 1);
      expect(step.args[0], isA<LiteralNode>());
      expect((step.args[0] as LiteralNode).value, 'hi');
    });

    test('null-aware cascade ?..a() rejects with diagnostic', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s(TextEditingController? c) {
  return TextField(
    controller: c?..clear(),
  );
}
''');
      expect(
        () => _lower(fnDecl),
        throwsA(
          isA<LoweringError>().having(
            (e) => e.message,
            'message',
            contains('Null-aware cascades'),
          ),
        ),
      );
    });
  });
}
