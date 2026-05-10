import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui_demo/desk_sdui_setup.g.dart';

late final Runtime sduiRuntime;

void initSdui() {
  sduiRuntime = Runtime();
  registerBuiltinWidgets(sduiRuntime);
  registerAllScreens(sduiRuntime);
}
