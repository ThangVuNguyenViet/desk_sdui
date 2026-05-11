// GENERATED CODE — DO NOT MODIFY BY HAND
import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:desk_sdui_demo/screens/chef.dart' show chefBinding, registerChefDependencies;

void registerSduiCoverage(Runtime rt) {
  rt.registerWidget('PageView', (args) => PageView(key: args['key'] as Key?, scrollDirection: args['scrollDirection'] as Axis? ?? Axis.horizontal, reverse: args['reverse'] as bool? ?? false, controller: args['controller'] as PageController?, physics: args['physics'] as ScrollPhysics?, pageSnapping: args['pageSnapping'] as bool? ?? true, onPageChanged: args['onPageChanged'] as void Function(int)?, children: (args['children'] as List?)?.cast<Widget>() ?? const [], dragStartBehavior: args['dragStartBehavior'] as DragStartBehavior? ?? DragStartBehavior.start, allowImplicitScrolling: args['allowImplicitScrolling'] as bool? ?? false, restorationId: args['restorationId'] as String?, clipBehavior: args['clipBehavior'] as Clip? ?? Clip.hardEdge, hitTestBehavior: args['hitTestBehavior'] as HitTestBehavior? ?? HitTestBehavior.opaque, scrollBehavior: args['scrollBehavior'] as ScrollBehavior?, padEnds: args['padEnds'] as bool? ?? true));
}
void registerAllScreens(Runtime rt) {
  rt.registerScreen(chefBinding);
  registerChefDependencies(rt);
  registerSduiCoverage(rt);
}
