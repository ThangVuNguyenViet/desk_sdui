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
      '_let_node_temp_${DateTime.now().microsecondsSinceEpoch}.dart',
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
  group('LetNode lowering', () {
    test('single final binding before return → one LetNode', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  final t = 'hello';
  return Text(t);
}
''');
      final result = _lower(fnDecl);
      expect(result.root, isA<LetNode>());
      final let = result.root as LetNode;
      expect(let.name, 't');
      expect(let.value, isA<LiteralNode>());
      expect(let.body, isA<WidgetNode>());
    });

    test('two sequential final bindings → nested LetNodes', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  final a = 'a';
  final b = 'b';
  return Text(a);
}
''');
      final result = _lower(fnDecl);
      expect(result.root, isA<LetNode>());
      final outer = result.root as LetNode;
      expect(outer.name, 'a');
      expect(outer.body, isA<LetNode>());
      final inner = outer.body as LetNode;
      expect(inner.name, 'b');
      expect(inner.body, isA<WidgetNode>());
    });

    test('reference to let-bound name in body → RefNode inside LetNode',
        () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  final t = 'hello';
  return Text(t);
}
''');
      final result = _lower(fnDecl);
      final let = result.root as LetNode;
      final widget = let.body as WidgetNode;
      expect(widget.args['data'], isA<RefNode>());
      expect((widget.args['data']! as RefNode).path, ['t']);
    });

    test(
        'reference to outer let in inner let value → inner value is RefNode',
        () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  final a = 'hello';
  final b = a;
  return Text(b);
}
''');
      final result = _lower(fnDecl);
      final outer = result.root as LetNode;
      expect(outer.name, 'a');
      final inner = outer.body as LetNode;
      expect(inner.name, 'b');
      expect(inner.value, isA<RefNode>());
      expect((inner.value as RefNode).path, ['a']);
    });

    test('reject var t = ...', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  var t = 1;
  return Text('hi');
}
''');
      expect(
        () => _lower(fnDecl),
        throwsA(
          isA<LoweringError>().having(
            (e) => e.message,
            'message',
            contains("must be 'final'"),
          ),
        ),
      );
    });

    test('reject uninitialized final', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  final a;
  return Text('hi');
}
''');
      expect(
        () => _lower(fnDecl),
        throwsA(
          isA<LoweringError>().having(
            (e) => e.message,
            'message',
            contains('must have an initializer'),
          ),
        ),
      );
    });

    test('reject split-declaration final a = 1, b = 2', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  final a = 1, b = 2;
  return Text('hi');
}
''');
      expect(
        () => _lower(fnDecl),
        throwsA(
          isA<LoweringError>().having(
            (e) => e.message,
            'message',
            contains('one variable per statement'),
          ),
        ),
      );
    });

    test('reject non-declaration statement before return', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget s() {
  foo();
  return Text('hi');
}
''');
      expect(
        () => _lower(fnDecl),
        throwsA(
          isA<LoweringError>().having(
            (e) => e.message,
            'message',
            contains('may only contain final locals'),
          ),
        ),
      );
    });
  });
}
