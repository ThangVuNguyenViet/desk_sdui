import 'package:build/build.dart';

class RegistryBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => {
    r'$package$': ['lib/desk_sdui_setup.sdui.g.dart'],
  };

  @override
  Future<void> build(BuildStep step) async {
    await step.writeAsString(
      AssetId(step.inputId.package, 'lib/desk_sdui_setup.sdui.g.dart'),
      '// TODO: implement\n',
    );
  }
}
