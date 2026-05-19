// GENERATED CODE — DO NOT MODIFY BY HAND
// ignore_for_file: cast_nullable_to_non_nullable, cascade_invocations, prefer_const_constructors, lines_longer_than_80_chars, unnecessary_const, unused_import, directives_ordering, always_use_package_imports, instantiate_abstract_class
import 'dart:ui';
import 'package:desk_sdui_demo/screens/counter_demo.dart';
import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

void registerCounter_demoDependencies(Runtime rt) {
  rt.registerWidget(
    'Center',
    (args) => Center(
      key: args['key'] as Key?,
      widthFactor: (args['widthFactor'] as num?)?.toDouble(),
      heightFactor: (args['heightFactor'] as num?)?.toDouble(),
      child: args['child'] as Widget?,
    ),
  );
  rt.registerWidget(
    'SingleChildScrollView',
    (args) => SingleChildScrollView(
      key: args['key'] as Key?,
      scrollDirection: args['scrollDirection'] as Axis? ?? Axis.vertical,
      reverse: args['reverse'] as bool? ?? false,
      padding: args['padding'] as EdgeInsetsGeometry?,
      primary: args['primary'] as bool?,
      physics: args['physics'] as ScrollPhysics?,
      controller: args['controller'] as ScrollController?,
      child: args['child'] as Widget?,
      dragStartBehavior:
          args['dragStartBehavior'] as DragStartBehavior? ??
          DragStartBehavior.start,
      clipBehavior: args['clipBehavior'] as Clip? ?? Clip.hardEdge,
      hitTestBehavior:
          args['hitTestBehavior'] as HitTestBehavior? ?? HitTestBehavior.opaque,
      restorationId: args['restorationId'] as String?,
      keyboardDismissBehavior:
          args['keyboardDismissBehavior'] as ScrollViewKeyboardDismissBehavior?,
    ),
  );
  rt.registerWidget(
    'Column',
    (args) => Column(
      key: args['key'] as Key?,
      mainAxisAlignment:
          args['mainAxisAlignment'] as MainAxisAlignment? ??
          MainAxisAlignment.start,
      mainAxisSize: args['mainAxisSize'] as MainAxisSize? ?? MainAxisSize.max,
      crossAxisAlignment:
          args['crossAxisAlignment'] as CrossAxisAlignment? ??
          CrossAxisAlignment.center,
      textDirection: args['textDirection'] as TextDirection?,
      verticalDirection:
          args['verticalDirection'] as VerticalDirection? ??
          VerticalDirection.down,
      textBaseline: args['textBaseline'] as TextBaseline?,
      spacing: (args['spacing'] as num?)?.toDouble() ?? 0.0,
      children: (args['children'] as List?)?.cast<Widget>() ?? const [],
    ),
  );
  rt.registerWidget(
    'Text',
    (args) => Text(
      args['data'] as String,
      key: args['key'] as Key?,
      style: args['style'] as TextStyle?,
      strutStyle: args['strutStyle'] as StrutStyle?,
      textAlign: args['textAlign'] as TextAlign?,
      textDirection: args['textDirection'] as TextDirection?,
      locale: args['locale'] as Locale?,
      softWrap: args['softWrap'] as bool?,
      overflow: args['overflow'] as TextOverflow?,
      textScaleFactor: (args['textScaleFactor'] as num?)?.toDouble(),
      textScaler: args['textScaler'] as TextScaler?,
      maxLines: args['maxLines'] as int?,
      semanticsLabel: args['semanticsLabel'] as String?,
      semanticsIdentifier: args['semanticsIdentifier'] as String?,
      textWidthBasis: args['textWidthBasis'] as TextWidthBasis?,
      textHeightBehavior: args['textHeightBehavior'] as TextHeightBehavior?,
      selectionColor: args['selectionColor'] as Color?,
    ),
  );
  rt.registerWidget(
    'Text.rich',
    (args) => Text.rich(
      args['textSpan'] as InlineSpan,
      key: args['key'] as Key?,
      style: args['style'] as TextStyle?,
      strutStyle: args['strutStyle'] as StrutStyle?,
      textAlign: args['textAlign'] as TextAlign?,
      textDirection: args['textDirection'] as TextDirection?,
      locale: args['locale'] as Locale?,
      softWrap: args['softWrap'] as bool?,
      overflow: args['overflow'] as TextOverflow?,
      textScaleFactor: (args['textScaleFactor'] as num?)?.toDouble(),
      textScaler: args['textScaler'] as TextScaler?,
      maxLines: args['maxLines'] as int?,
      semanticsLabel: args['semanticsLabel'] as String?,
      semanticsIdentifier: args['semanticsIdentifier'] as String?,
      textWidthBasis: args['textWidthBasis'] as TextWidthBasis?,
      textHeightBehavior: args['textHeightBehavior'] as TextHeightBehavior?,
      selectionColor: args['selectionColor'] as Color?,
    ),
  );
  rt.registerWidget(
    'SizedBox',
    (args) => SizedBox(
      key: args['key'] as Key?,
      width: (args['width'] as num?)?.toDouble(),
      height: (args['height'] as num?)?.toDouble(),
      child: args['child'] as Widget?,
    ),
  );
  rt.registerWidget(
    'SizedBox.expand',
    (args) => SizedBox.expand(
      key: args['key'] as Key?,
      child: args['child'] as Widget?,
    ),
  );
  rt.registerWidget(
    'SizedBox.shrink',
    (args) => SizedBox.shrink(
      key: args['key'] as Key?,
      child: args['child'] as Widget?,
    ),
  );
  rt.registerWidget(
    'SizedBox.fromSize',
    (args) => SizedBox.fromSize(
      key: args['key'] as Key?,
      child: args['child'] as Widget?,
      size: args['size'] as Size?,
    ),
  );
  rt.registerWidget(
    'SizedBox.square',
    (args) => SizedBox.square(
      key: args['key'] as Key?,
      child: args['child'] as Widget?,
      dimension: (args['dimension'] as num?)?.toDouble(),
    ),
  );
  rt.registerWidget(
    'Row',
    (args) => Row(
      key: args['key'] as Key?,
      mainAxisAlignment:
          args['mainAxisAlignment'] as MainAxisAlignment? ??
          MainAxisAlignment.start,
      mainAxisSize: args['mainAxisSize'] as MainAxisSize? ?? MainAxisSize.max,
      crossAxisAlignment:
          args['crossAxisAlignment'] as CrossAxisAlignment? ??
          CrossAxisAlignment.center,
      textDirection: args['textDirection'] as TextDirection?,
      verticalDirection:
          args['verticalDirection'] as VerticalDirection? ??
          VerticalDirection.down,
      textBaseline: args['textBaseline'] as TextBaseline?,
      spacing: (args['spacing'] as num?)?.toDouble() ?? 0.0,
      children: (args['children'] as List?)?.cast<Widget>() ?? const [],
    ),
  );
  rt.registerWidget(
    'ElevatedButton',
    (args) => ElevatedButton(
      key: args['key'] as Key?,
      onPressed: args['onPressed'] as void Function()?,
      onLongPress: args['onLongPress'] as void Function()?,
      onHover: args['onHover'] as void Function(bool)?,
      onFocusChange: args['onFocusChange'] as void Function(bool)?,
      style: args['style'] as ButtonStyle?,
      focusNode: args['focusNode'] as FocusNode?,
      autofocus: args['autofocus'] as bool? ?? false,
      clipBehavior: args['clipBehavior'] as Clip?,
      statesController: args['statesController'] as WidgetStatesController?,
      child: args['child'] as Widget?,
    ),
  );
  rt.registerWidget(
    'ElevatedButton.icon',
    (args) => ElevatedButton.icon(
      key: args['key'] as Key?,
      onPressed: args['onPressed'] as void Function()?,
      onLongPress: args['onLongPress'] as void Function()?,
      onHover: args['onHover'] as void Function(bool)?,
      onFocusChange: args['onFocusChange'] as void Function(bool)?,
      style: args['style'] as ButtonStyle?,
      focusNode: args['focusNode'] as FocusNode?,
      autofocus: args['autofocus'] as bool? ?? false,
      clipBehavior: args['clipBehavior'] as Clip? ?? Clip.none,
      statesController: args['statesController'] as WidgetStatesController?,
      icon: args['icon'] as Widget?,
      label: args['label'] as Widget,
      iconAlignment: args['iconAlignment'] as IconAlignment?,
    ),
  );
  rt.registerConstant('MainAxisAlignment.center', MainAxisAlignment.center);
  rt.registerFunction(
    'Theme.of',
    (args) => Theme.of(args['arg0'] as BuildContext),
  );
  rt.registerMethod(
    'CounterActions.decrementCount',
    (recv, args) =>
        (recv as CounterActions).decrementCount(args['arg0'] as Counter),
  );
  rt.registerMethod(
    'CounterActions.incrementCount',
    (recv, args) =>
        (recv as CounterActions).incrementCount(args['arg0'] as Counter),
  );
  rt.registerMethod(
    'CounterActions.setStep',
    (recv, args) => (recv as CounterActions).setStep(
      args['arg0'] as Counter,
      args['arg1'] as int,
    ),
  );
  rt.registerMethod(
    'CounterActions.setMode',
    (recv, args) => (recv as CounterActions).setMode(
      args['arg0'] as Counter,
      args['arg1'] as String,
    ),
  );
  rt.registerMethod(
    'CounterActions.save',
    (recv, args) => (recv as CounterActions).save(args['arg0'] as Counter),
  );
  rt.registerMethod(
    'CounterActions.handleSaveError',
    (recv, args) =>
        (recv as CounterActions).handleSaveError(args['arg0'] as Counter),
  );
  rt.registerMethod(
    'CounterActions.reset',
    (recv, args) => (recv as CounterActions).reset(args['arg0'] as Counter),
  );
  rt.registerSubscript(
    'List.[]',
    (recv, key) => (recv as List<int>)[key as int],
  );
  rt.registerFunction('tripled', (args) => tripled(args['arg0'] as int));
  rt.registerGetter('Counter.count', (r) => (r as Counter).count);
  rt.registerGetter('Counter.mode', (r) => (r as Counter).mode);
  rt.registerGetter('Counter.history', (r) => (r as Counter).history);
  rt.registerGetter('List.length', (r) => (r as List).length);
  rt.registerGetter('List.isNotEmpty', (r) => (r as List).isNotEmpty);
  rt.registerGetter(
    'TextTheme.headlineLarge',
    (r) => (r as TextTheme).headlineLarge,
  );
  rt.registerGetter('TextTheme.labelLarge', (r) => (r as TextTheme).labelLarge);
  rt.registerGetter('ThemeData.textTheme', (r) => (r as ThemeData).textTheme);
}
