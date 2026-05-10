import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

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

  @override
  Map<String, List<String>> get buildExtensions => {
    r'$package$': ['lib/desk_sdui_setup.g.dart'],
  };

  @override
  Future<void> build(BuildStep step) async {
    final screens = <_ScreenInfo>[];
    await for (final input in step.findAssets(Glob('lib/**.dart'))) {
      if (input.path.endsWith('.sdui.g.dart')) continue;
      final lib = await step.resolver.libraryFor(input);
      final libReader = LibraryReader(lib);
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
    }

    final source = _emitRegistry(screens, step.inputId.package);
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
    );
  }

  String _emitRegistry(List<_ScreenInfo> screens, String packageName) {
    final imports = <String, List<String>>{};
    for (final s in screens) {
      var uri = s.sourceUri.toString();
      if (uri.startsWith('package:$packageName/')) {
        uri = uri.substring('package:$packageName/'.length);
      }
      imports.putIfAbsent(uri, () => [])
        ..add(s.bindingSymbol)
        ..add(s.registrationFn);
    }

    final importLines = imports.entries.map((e) {
      final symbols = e.value.join(', ');
      return "import 'package:$packageName/${e.key}' show $symbols;";
    }).join('\n');

    final registrations = screens.map((s) {
      return '  rt.registerScreen(${s.bindingSymbol});\n  ${s.registrationFn}(rt);';
    }).join('\n');

    return '''
// GENERATED CODE — DO NOT MODIFY BY HAND
import 'package:desk_sdui/desk_sdui.dart';
$importLines

void registerAllScreens(Runtime rt) {
$registrations
}
''';
  }
}
