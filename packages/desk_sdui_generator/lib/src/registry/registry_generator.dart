import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import '../registration_emitter.dart';
import '../type_collector.dart';

class _ScreenInfo {
  _ScreenInfo({
    required this.name,
    required this.bindingSymbol,
    required this.registrationFn,
    required this.sourceUri,
  });
  final String name;
  final String bindingSymbol;
  final String registrationFn;
  final Uri sourceUri;
}

/// Public test-surface data class that mirrors [_ScreenInfo].
/// Exposed so that unit tests can call [RegistryBuilder.emitRegistryForTest]
/// without depending on build infrastructure.
class ScreenInfoForTest {
  ScreenInfoForTest({
    required this.name,
    required this.bindingSymbol,
    required this.registrationFn,
    required this.sourceUri,
  });
  final String name;
  final String bindingSymbol;
  final String registrationFn;
  final Uri sourceUri;
}

class RegistryBuilder implements Builder {
  static const _checker = TypeChecker.fromRuntime(Screen);
  static const _coverageChecker = TypeChecker.fromRuntime(RegisterForSdui);

  @override
  Map<String, List<String>> get buildExtensions => {
    r'$package$': ['lib/desk_sdui_setup.g.dart'],
  };

  @override
  Future<void> build(BuildStep step) async {
    final screens = <_ScreenInfo>[];
    final coverageTypes = CollectedTypes();

    await for (final input in step.findAssets(Glob('lib/**.dart'))) {
      if (input.path.endsWith('.sdui.g.dart')) continue;
      final lib = await step.resolver.libraryFor(input);
      final libReader = LibraryReader(lib);

      // Collect @Screen annotated functions.
      for (final annotated in libReader.annotatedWith(_checker)) {
        final el = annotated.element;
        final name = annotated.annotation.read('name').stringValue;
        final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
        if (el.name != null) {
          final capitalizedName = safeName.isEmpty
              ? safeName
              : safeName[0].toUpperCase() + safeName.substring(1);
          screens.add(_ScreenInfo(
            name: name,
            bindingSymbol: '${safeName}Binding',
            registrationFn: 'register${capitalizedName}Dependencies',
            sourceUri: input.uri,
          ));
        }
      }

      // Collect @RegisterForSdui annotated classes.
      for (final annotated in libReader.annotatedWith(_coverageChecker)) {
        final el = annotated.element;
        if (el is! ClassElement) continue;
        final annotation = annotated.annotation.objectValue;
        final partial = collectTypesFromAnnotation(el, annotation);
        coverageTypes.unionWith(partial);
      }
    }

    final source = _emitRegistry(
      screens,
      step.inputId.package,
      coverageTypes: coverageTypes,
    );
    await step.writeAsString(
      AssetId(step.inputId.package, 'lib/desk_sdui_setup.g.dart'),
      source,
    );
  }

  /// Test-only entry point — converts [ScreenInfoForTest] records into the
  /// same output as the private [_emitRegistry] without requiring a
  /// [BuildStep].
  String emitRegistryForTest({
    required List<ScreenInfoForTest> screens,
    required String packageName,
    CollectedTypes? coverageTypes,
  }) {
    return _emitRegistry(
      screens
          .map(
            (s) => _ScreenInfo(
              name: s.name,
              bindingSymbol: s.bindingSymbol,
              registrationFn: s.registrationFn,
              sourceUri: s.sourceUri,
            ),
          )
          .toList(),
      packageName,
      coverageTypes: coverageTypes,
    );
  }

  String _emitRegistry(
    List<_ScreenInfo> screens,
    String packageName, {
    CollectedTypes? coverageTypes,
  }) {
    // Build two separate import maps:
    //  1. Source URI → binding symbol (the ScreenBinding getter lives in the
    //     part-of file, accessed via the parent source library).
    //  2. Reg URI → registration function (lives in the standalone _reg.g.dart
    //     file so it can carry its own imports).
    final bindingImports = <String, List<String>>{};
    final regImports = <String, List<String>>{};

    for (final s in screens) {
      var sourceUri = s.sourceUri.toString();
      if (sourceUri.startsWith('package:$packageName/')) {
        sourceUri = sourceUri.substring('package:$packageName/'.length);
      }
      // Derive the _reg.g.dart URI by replacing .dart extension.
      final regUri = sourceUri.endsWith('.dart')
          ? '${sourceUri.substring(0, sourceUri.length - '.dart'.length)}.sdui_reg.g.dart'
          : '$sourceUri.sdui_reg.g.dart';

      bindingImports.putIfAbsent(sourceUri, () => []).add(s.bindingSymbol);
      regImports.putIfAbsent(regUri, () => []).add(s.registrationFn);
    }

    final bindingImportLines = bindingImports.entries.map((e) {
      final symbols = e.value.join(', ');
      return "import 'package:$packageName/${e.key}' show $symbols;";
    });
    final regImportLines = regImports.entries.map((e) {
      final symbols = e.value.join(', ');
      return "import 'package:$packageName/${e.key}' show $symbols;";
    });
    final importLines = [...bindingImportLines, ...regImportLines].join('\n');

    final registrations = screens.map((s) {
      return '  rt.registerScreen(${s.bindingSymbol});\n  ${s.registrationFn}(rt);';
    }).join('\n');

    // Build optional registerSduiCoverage block.
    final coverageBlock = _emitCoverageBlock(coverageTypes);
    final coverageCall = coverageBlock.isNotEmpty ? '\n  registerSduiCoverage(rt);' : '';
    final flutterImport = coverageBlock.isNotEmpty
        ? "import 'package:flutter/gestures.dart';\nimport 'package:flutter/material.dart';\nimport 'package:flutter/rendering.dart';\n"
        : '';

    return '''
// GENERATED CODE — DO NOT MODIFY BY HAND
// ignore_for_file: cast_nullable_to_non_nullable, cascade_invocations, prefer_const_constructors, lines_longer_than_80_chars, unnecessary_const, unused_import, directives_ordering, always_use_package_imports
import 'package:desk_sdui/desk_sdui.dart';
$flutterImport$importLines
$coverageBlock
void registerAllScreens(Runtime rt) {
$registrations$coverageCall
}
''';
  }

  /// Returns the `void registerSduiCoverage(Runtime rt) { ... }` source block
  /// when [ct] is non-null and non-empty, or an empty string otherwise.
  String _emitCoverageBlock(CollectedTypes? ct) {
    if (ct == null) return '';
    if (ct.widgets.isEmpty &&
        ct.valueTypes.isEmpty &&
        ct.constants.isEmpty &&
        ct.methods.isEmpty &&
        ct.subscriptables.isEmpty &&
        ct.functions.isEmpty) {
      return '';
    }
    final registrations = RegistrationEmitter()
        .emitAll(ct)
        .split('\n')
        .map((l) => '  $l')
        .join('\n');
    return '\nvoid registerSduiCoverage(Runtime rt) {\n$registrations\n}';
  }
}
