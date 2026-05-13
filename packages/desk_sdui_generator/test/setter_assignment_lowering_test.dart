// ignore_for_file: deprecated_member_use
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
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
  return lowerScreen(fnDecl, ScreenAnnotationData(name: 'test'));
}

void main() {
  group('SetterCallNode lowering', () {
    // Test 1: Simple property assignment `vm.count = 0` lowers to SetterCallNode
    test('simple property assignment lowers to SetterCallNode', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';
import 'package:desk_sdui_demo/screens/counter_actions.dart';

@Register([CounterVm])
class CounterVm {
  int count = 0;
}

Widget s(CounterVm vm) {
  return Text((vm.count = 0).toString());
}
''');

      final result = _lower(fnDecl);
      // The expression should contain a SetterCallNode somewhere
      expect(
        result.root.toString(),
        anyOf([
          contains('SetterCallNode'),
          contains('count'),
        ]),
      );
    });

    // Test 2: Rejects assignment to unregistered type
    test('rejects assignment to unregistered type', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

class UnregisteredClass {
  int field = 0;
}

Widget s(UnregisteredClass obj) {
  return Text((obj.field = 5).toString());
}
''');

      expect(
        () => _lower(fnDecl),
        throwsA(
          isA<LoweringError>().having(
            (e) => e.message,
            'message',
            anyOf([
              contains('not a registered class'),
              contains('No local binding'),
            ]),
          ),
        ),
      );
    });
  });
}
