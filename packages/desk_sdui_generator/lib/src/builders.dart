import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'screen_lowering/screen_generator.dart';
import 'registry/registry_generator.dart';

Builder screenBuilder(BuilderOptions _) => PartBuilder(
  [ScreenGenerator()],
  '.sdui.g.dart',
  header: '// GENERATED CODE — DO NOT MODIFY BY HAND',
);

Builder registryBuilder(BuilderOptions _) => RegistryBuilder();
