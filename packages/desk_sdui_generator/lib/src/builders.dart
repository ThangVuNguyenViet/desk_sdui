import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';

import 'screen_lowering/screen_generator.dart';
import 'registry/registry_generator.dart';

Builder screenBuilder(BuilderOptions _) => _ScreenBuilder();

class _ScreenBuilder extends Builder {
  _ScreenBuilder();

  static const _checker =
      TypeChecker.typeNamed(Screen, inPackage: 'desk_sdui_annotation');

  @override
  Map<String, List<String>> get buildExtensions => const {
    '.dart': ['.sdui.g.dart', '.sdui.json', '.sdui_reg.g.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    final lib = await buildStep.resolver.libraryFor(inputId);
    final libReader = LibraryReader(lib);

    final annotatedElements = libReader.annotatedWith(_checker).toList();
    if (annotatedElements.isEmpty) return;

    final generator = ScreenGenerator();
    final dartParts = <String>[];

    for (final annotated in annotatedElements) {
      final dartCode = await generator.generateForAnnotatedElement(
        annotated.element,
        annotated.annotation,
        buildStep,
      );
      if (dartCode.isNotEmpty) {
        dartParts.add(dartCode);
      }
    }

    if (dartParts.isNotEmpty) {
      final partContent = dartParts.join('\n');
      await buildStep.writeAsString(
        inputId.changeExtension('.sdui.g.dart'),
        partContent,
      );
    }
  }
}

Builder registryBuilder(BuilderOptions _) => RegistryBuilder();
