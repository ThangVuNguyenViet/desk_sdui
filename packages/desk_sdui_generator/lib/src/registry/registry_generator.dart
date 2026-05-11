// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import '../registration_emitter.dart';
import '../type_collector.dart';
import '../screen_lowering/ast_to_ir.dart';

class _ScreenInfo {
  _ScreenInfo({
    required this.name,
    required this.bindingSymbol,
    required this.registrationFn,
    required this.sourceUri,
    this.referencedWidgetNames = const {},
    this.inputMethodRefs = const {},
    this.inputTypeNames = const {},
  });
  final String name;
  final String bindingSymbol;
  final String registrationFn;
  final Uri sourceUri;

  /// Widget type names referenced in this screen's body (simple class names).
  final Set<String> referencedWidgetNames;

  /// Method references indexed by input name.
  /// e.g. `{'vm': ['increment', 'decrement']}`
  final Map<String, List<String>> inputMethodRefs;

  /// Input parameter name → type name (simple class name).
  /// e.g. `{'vm': 'CounterController'}`
  final Map<String, String> inputTypeNames;
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
  static const _checker =
      TypeChecker.typeNamed(Screen, inPackage: 'desk_sdui_annotation');
  static const _catalogChecker =
      TypeChecker.typeNamed(Register, inPackage: 'desk_sdui_annotation');

  @override
  Map<String, List<String>> get buildExtensions => {
    r'$package$': ['lib/desk_sdui_setup.g.dart'],
  };

  @override
  Future<void> build(BuildStep step) async {
    final screens = <_ScreenInfo>[];
    final catalogTypes = CollectedTypes();

    await for (final input in step.findAssets(Glob('lib/**.dart'))) {
      if (input.path.endsWith('.sdui.g.dart')) continue;
      final lib = await step.resolver.libraryFor(input);
      final libReader = LibraryReader(lib);

      // Collect @Screen annotated functions.
      for (final annotated in libReader.annotatedWith(_checker)) {
        final el = annotated.element;
        final name = annotated.annotation.read('name').stringValue;
        final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
        if (el.name == null) continue;

        final capitalizedName = safeName.isEmpty
            ? safeName
            : safeName[0].toUpperCase() + safeName.substring(1);

        // Resolve the screen body to collect referenced widget types for
        // diagnostic comparison against the @Register registered set.
        // We must use the RESOLVED AST so that ClassElements are populated.
        var referencedWidgetNames = <String>{};
        var inputMethodRefs = <String, List<String>>{};
        var inputTypeNames = <String, String>{};
        if (el is TopLevelFunctionElement) {
          try {
            final session = el.session;
            if (session != null) {
              final resolvedLibResult =
                  await session.getResolvedLibraryByElement(el.library);
              if (resolvedLibResult is ResolvedLibraryResult) {
                final declResult = resolvedLibResult
                    .getFragmentDeclaration(el.firstFragment);
                final fnDecl = declResult?.node;
                if (fnDecl is FunctionDeclaration) {
                  final body = fnDecl.functionExpression.body;
                  if (body is ExpressionFunctionBody) {
                    final collected = collectTypes(fnDecl);
                    referencedWidgetNames = collected.widgets
                        .map((e) => e.name)
                        .whereType<String>()
                        .toSet();

                    // Collect param types.
                    for (final p
                        in fnDecl.functionExpression.parameters!.parameters) {
                      final paramName = p.name!.lexeme;
                      final typeAnnotation = p.type;
                      String paramType = 'dynamic';
                      if (typeAnnotation != null) {
                        final type = typeAnnotation.type;
                        if (type != null) {
                          paramType = type.getDisplayString();
                          // Strip nullability suffix for matching.
                          if (paramType.endsWith('?')) {
                            paramType = paramType.substring(0, paramType.length - 1);
                          }
                        }
                      }
                      inputTypeNames[paramName] = paramType;
                    }

                    // Lower the screen to collect method refs.
                    try {
                      final screenResult = lowerScreen(
                        fnDecl,
                        ScreenAnnotationData(name: name),
                      );
                      inputMethodRefs = screenResult.methodRefs;
                    } catch (_) {
                      // If lowering fails, skip method diagnostic for this
                      // screen.
                    }
                  }
                }
              }
            }
          } catch (e, st) {
            // If AST resolution fails for any reason, log and skip the
            // diagnostic for this screen rather than breaking the build.
            log.warning(
              'registration diagnostic: failed to resolve body for screen '
              '"$name" ($e). Skipping catalog check for this screen.\n$st',
            );
          }
        }

        screens.add(_ScreenInfo(
          name: name,
          bindingSymbol: '${safeName}Binding',
          registrationFn: 'register${capitalizedName}Dependencies',
          sourceUri: input.uri,
          referencedWidgetNames: referencedWidgetNames,
          inputMethodRefs: inputMethodRefs,
          inputTypeNames: inputTypeNames,
        ));
      }

      // Collect @Register annotated classes.
      for (final annotated in libReader.annotatedWith(_catalogChecker)) {
        final el = annotated.element;
        if (el is! ClassElement) continue;
        final annotation = annotated.annotation.objectValue;
        final partial = collectTypesFromAnnotation(el, annotation);
        catalogTypes.unionWith(partial);
      }

      // Collect library-level @Register (Dart 3.0+).
      for (final meta in lib.metadata.annotations) {
        final obj = meta.computeConstantValue();
        if (obj == null) continue;
        if (!_catalogChecker.isExactlyType(obj.type!)) continue;
        final partial = collectTypesFromAnnotation(lib, obj);
        catalogTypes.unionWith(partial);
      }
    }

    // Diagnostic: for each screen, fail the build if any widget type referenced
    // in its body is not listed in any @Register annotation.
    final registeredWidgetNames = catalogTypes.widgets
        .map((e) => e.name)
        .whereType<String>()
        .toSet();
    final allMissing = <String, List<String>>{};
    for (final screen in screens) {
      final missing =
          screen.referencedWidgetNames.difference(registeredWidgetNames);
      if (missing.isNotEmpty) {
        allMissing[screen.name] = missing.toList()..sort();
      }
    }
    if (allMissing.isNotEmpty) {
      final details = allMissing.entries.map((e) {
        final types = e.value.join(', ');
        return '  Screen "${e.key}" references unregistered widget(s): $types';
      }).join('\n');
      throw StateError(
        'desk_sdui registration diagnostic failed.\n'
        'The following widget types are referenced in @Screen bodies but are '
        'not listed in any @Register annotation.\n'
        'Add them to a @Register list or import one of the bundles '
        'from package:desk_sdui/widget_bundles.dart.\n'
        '$details',
      );
    }

    // Diagnostic: for each screen, check that input types with method refs
    // are registered and that their methods exist.
    final registeredValueTypeNames = catalogTypes.valueTypes
        .map((e) => e.name)
        .whereType<String>()
        .toSet();
    final registeredMethodMap = <String, Set<String>>{};
    for (final valueType in catalogTypes.valueTypes) {
      final methods = <String>{};
      final skippedNames = {
        'toString',
        'hashCode',
        'noSuchMethod',
        'runtimeType',
        '==',
        'dispose',
      };
      for (final method in valueType.methods) {
        if (method.isStatic) continue;
        if (method.isPrivate) continue;
        final methodName = method.name;
        if (methodName == null) continue;
        if (skippedNames.contains(methodName)) continue;
        if (methodName.startsWith('_')) continue;
        methods.add(methodName);
      }
      registeredMethodMap[valueType.name!] = methods;
    }

    final methodErrors = <String>[];
    for (final screen in screens) {
      for (final entry in screen.inputMethodRefs.entries) {
        final inputName = entry.key;
        final methodNames = entry.value;
        final typeName = screen.inputTypeNames[inputName];
        if (typeName == null) continue;

        if (!registeredValueTypeNames.contains(typeName)) {
          methodErrors.add(
            'Screen "${screen.name}" uses input "$inputName" of type '
            '$typeName but $typeName is not registered.\n'
            'Add $typeName to a @Register list.',
          );
          continue;
        }

        final availableMethods = registeredMethodMap[typeName] ?? const {};
        for (final methodName in methodNames) {
          if (!availableMethods.contains(methodName)) {
            final sorted = availableMethods.toList()..sort();
            methodErrors.add(
              'Screen "${screen.name}" references method "$inputName.$methodName" '
              'but $typeName has no public method "$methodName".\n'
              'Available methods on $typeName: ${sorted.join(', ')}.',
            );
          }
        }
      }
    }
    if (methodErrors.isNotEmpty) {
      throw StateError(
        'desk_sdui method registration diagnostic failed.\n'
        '${methodErrors.join('\n')}',
      );
    }

    final source = _emitRegistry(
      screens,
      step.inputId.package,
      catalogTypes: catalogTypes,
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
    CollectedTypes? catalogTypes,
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
      catalogTypes: catalogTypes,
    );
  }

  String _emitRegistry(
    List<_ScreenInfo> screens,
    String packageName, {
    CollectedTypes? catalogTypes,
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

    // Build optional registerSduiCatalog block.
    final catalogBlock = _emitCatalogBlock(catalogTypes);
    final catalogCall = catalogBlock.isNotEmpty ? '\n  registerSduiCatalog(rt);' : '';
    final flutterImport = catalogBlock.isNotEmpty
        ? "import 'package:flutter/gestures.dart';\nimport 'package:flutter/material.dart';\nimport 'package:flutter/rendering.dart';\n"
        : '';

    return '''
// GENERATED CODE — DO NOT MODIFY BY HAND
// ignore_for_file: cast_nullable_to_non_nullable, cascade_invocations, prefer_const_constructors, lines_longer_than_80_chars, unnecessary_const, unused_import, directives_ordering, always_use_package_imports
import 'package:desk_sdui/desk_sdui.dart';
$flutterImport$importLines
$catalogBlock
void registerAllScreens(Runtime rt) {
  registerCoreAccessors(rt);
$registrations$catalogCall
}
''';
  }

  /// Returns the `void registerSduiCatalog(Runtime rt) { ... }` source block
  /// when [ct] is non-null and non-empty, or an empty string otherwise.
  String _emitCatalogBlock(CollectedTypes? ct) {
    if (ct == null) return '';
    if (ct.widgets.isEmpty &&
        ct.valueTypes.isEmpty &&
        ct.constants.isEmpty &&
        ct.methods.isEmpty &&
        ct.subscriptables.isEmpty &&
        ct.functions.isEmpty) {
      return '';
    }
    final emitter = RegistrationEmitter();
    final registrations = emitter
        .emitAll(ct)
        .split('\n')
        .map((l) => '  $l')
        .join('\n');

    // Also emit methods for all registered non-Widget classes.
    final classMethodBlocks = <String>[];
    for (final valueType in ct.valueTypes) {
      classMethodBlocks.add(
        emitter
            .emitMethodsForClass(valueType)
            .split('\n')
            .map((l) => '  $l')
            .join('\n'),
      );
    }
    // Also emit methods for widget classes that might have callable methods
    // (though typically widgets don't, this handles edge cases).
    // Skip for now — only valueTypes need method emission per the plan.

    final allRegistrations = [registrations, ...classMethodBlocks].join('\n');
    return '\nvoid registerSduiCatalog(Runtime rt) {\n$allRegistrations\n}';
  }
}
