// GENERATED CODE — DO NOT MODIFY BY HAND
// ignore_for_file: cast_nullable_to_non_nullable, cascade_invocations, prefer_const_constructors, lines_longer_than_80_chars, unnecessary_const, unused_import, directives_ordering, always_use_package_imports
import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:desk_sdui_demo/screens/chef.dart' show chefBinding;
import 'package:desk_sdui_demo/screens/counter_bouncy.dart' show counter_bouncyBinding;
import 'package:desk_sdui_demo/screens/counter_burst.dart' show counter_burstBinding;
import 'package:desk_sdui_demo/screens/counter_minimal.dart' show counter_minimalBinding;
import 'package:desk_sdui_demo/screens/counter_stress.dart' show counter_stressBinding;
import 'package:desk_sdui_demo/screens/chef.sdui_reg.g.dart' show registerChefDependencies;
import 'package:desk_sdui_demo/screens/counter_bouncy.sdui_reg.g.dart' show registerCounter_bouncyDependencies;
import 'package:desk_sdui_demo/screens/counter_burst.sdui_reg.g.dart' show registerCounter_burstDependencies;
import 'package:desk_sdui_demo/screens/counter_minimal.sdui_reg.g.dart' show registerCounter_minimalDependencies;
import 'package:desk_sdui_demo/screens/counter_stress.sdui_reg.g.dart' show registerCounter_stressDependencies;

void registerSduiCoverage(Runtime rt) {
  rt.registerWidget('PageView', (args) => PageView(key: args['key'] as Key?, scrollDirection: args['scrollDirection'] as Axis? ?? Axis.horizontal, reverse: args['reverse'] as bool? ?? false, controller: args['controller'] as PageController?, physics: args['physics'] as ScrollPhysics?, pageSnapping: args['pageSnapping'] as bool? ?? true, onPageChanged: args['onPageChanged'] as void Function(int)?, children: (args['children'] as List?)?.cast<Widget>() ?? const [], dragStartBehavior: args['dragStartBehavior'] as DragStartBehavior? ?? DragStartBehavior.start, allowImplicitScrolling: args['allowImplicitScrolling'] as bool? ?? false, restorationId: args['restorationId'] as String?, clipBehavior: args['clipBehavior'] as Clip? ?? Clip.hardEdge, hitTestBehavior: args['hitTestBehavior'] as HitTestBehavior? ?? HitTestBehavior.opaque, scrollBehavior: args['scrollBehavior'] as ScrollBehavior?, padEnds: args['padEnds'] as bool? ?? true));
}
void registerAllScreens(Runtime rt) {
  registerCoreAccessors(rt);
  rt.registerScreen(chefBinding);
  registerChefDependencies(rt);
  rt.registerScreen(counter_bouncyBinding);
  registerCounter_bouncyDependencies(rt);
  rt.registerScreen(counter_burstBinding);
  registerCounter_burstDependencies(rt);
  rt.registerScreen(counter_minimalBinding);
  registerCounter_minimalDependencies(rt);
  rt.registerScreen(counter_stressBinding);
  registerCounter_stressDependencies(rt);
  registerSduiCoverage(rt);
}
