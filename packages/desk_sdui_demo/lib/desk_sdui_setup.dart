import 'package:desk_sdui/desk_sdui.dart';

part 'desk_sdui_setup.sdui.g.dart';

late final Runtime sduiRuntime;

void initSdui() {
  sduiRuntime = Runtime();
  registerBuiltinWidgets(sduiRuntime);
  _registerAll(sduiRuntime);
}
