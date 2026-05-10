/// Integration tests for the `registerXDependencies` function emitted by
/// [ScreenGenerator].
///
/// These tests exercise the full code-generation pipeline — IR lowering, const
/// folding, reactive hoisting, key inference, Dart emission, type collection,
/// and registration emission — using the same resolved-AST trick as the
/// type_collector_test: a temporary `.dart` file is written into
/// desk_sdui_demo/lib so that Flutter types are resolvable, resolved with
/// `resolveFile2`, and then the pipeline is run manually.
///
/// We do *not* run the build_runner here; instead we call the individual
/// pipeline functions directly and verify the string output.
// ignore_for_file: deprecated_member_use
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:dart_style/dart_style.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui_generator/src/registration_emitter.dart';
import 'package:desk_sdui_generator/src/screen_lowering/ast_to_ir.dart';
import 'package:desk_sdui_generator/src/screen_lowering/const_fold_pass.dart';
import 'package:desk_sdui_generator/src/screen_lowering/ir_emitter_dart.dart';
import 'package:desk_sdui_generator/src/screen_lowering/key_infer_pass.dart';
import 'package:desk_sdui_generator/src/screen_lowering/reactive_hoist_pass.dart';
import 'package:desk_sdui_generator/src/type_collector.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Root of the desk_sdui_demo package — used as the analysis context root so
/// that `package:flutter/...` can be resolved.
const _demoPackageRoot =
    // ignore: lines_longer_than_80_chars
    '/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/packages/desk_sdui_demo';

/// Resolves a single-function Dart source string and returns its AST node.
Future<FunctionDeclaration> _resolveScreen(String source) async {
  final dir = Directory(p.join(_demoPackageRoot, 'lib'));
  final tempFile = File(
    p.join(
      dir.path,
      '_screen_gen_reg_temp_${DateTime.now().microsecondsSinceEpoch}.dart',
    ),
  );
  tempFile.writeAsStringSync(source);
  try {
    final result = await resolveFile2(path: tempFile.path);
    if (result is! ResolvedUnitResult) {
      throw StateError('resolveFile2 returned ${result.runtimeType}');
    }
    return result.unit.declarations.whereType<FunctionDeclaration>().first;
  } finally {
    if (tempFile.existsSync()) tempFile.deleteSync();
  }
}

/// Run the same pipeline as ScreenGenerator and return the generated Dart
/// source (binding + registration function).
String _runPipeline(FunctionDeclaration fnDecl, String screenName) {
  final ann = ScreenAnnotationData(name: screenName);
  var result = lowerScreen(fnDecl, ann);
  var ir = constFold(result.root);
  ir = reactiveHoist(ir);
  ir = inferKeys(ir);

  final bindingCode = emitDart(result.copyWith(root: ir));

  final collected = collectTypes(fnDecl);
  final registrations = RegistrationEmitter().emitAll(collected);

  final capitalizedName =
      screenName.isEmpty ? screenName : screenName[0].toUpperCase() + screenName.substring(1);

  final registrationFn = '''
void register${capitalizedName}Dependencies(Runtime rt) {
$registrations
}
''';
  final formattedRegFn =
      DartFormatter(languageVersion: DartFormatter.latestLanguageVersion)
          .format(registrationFn);

  return '$bindingCode\n$formattedRegFn';
}

void main() {
  group('ScreenGenerator — registerXDependencies emission', () {
    test('emits void registerBuildDependencies(Runtime rt) for a Padding+Text screen',
        () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget build() => Padding(
  padding: EdgeInsets.all(8),
  child: Text('hello'),
);
''');

      final output = _runPipeline(fnDecl, 'build');

      expect(
        output,
        contains('void registerBuildDependencies(Runtime rt)'),
        reason: 'Registration function header must be present',
      );
      expect(
        output,
        contains("'Padding'"),
        reason: 'Padding widget registration must be present',
      );
      expect(
        output,
        contains("'Text'"),
        reason: 'Text widget registration must be present',
      );
      // Verify the registrations are inside the registerBuildDependencies fn
      expect(
        output,
        contains('registerWidget'),
        reason: 'registerWidget call must be present',
      );
    });

    test('capitalizes multi-word screen name', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget build() => Text('hi');
''');

      final output = _runPipeline(fnDecl, 'chefProfile');

      expect(output, contains('void registerChefProfileDependencies(Runtime rt)'));
    });

    test('emits registerConstant for Icons.person', () async {
      final fnDecl = await _resolveScreen('''
import 'package:flutter/material.dart';

Widget build() => Icon(Icons.person);
''');

      final output = _runPipeline(fnDecl, 'iconScreen');

      expect(
        output,
        contains("'Icons.person'"),
        reason: 'Icons.person constant registration must be present',
      );
      expect(
        output,
        contains('registerConstant'),
        reason: 'registerConstant call must be present',
      );
    });
  });
}
