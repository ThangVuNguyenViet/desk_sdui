// GENERATED CODE — DO NOT MODIFY BY HAND
// ignore_for_file: cast_nullable_to_non_nullable, cascade_invocations, prefer_const_constructors, lines_longer_than_80_chars, unnecessary_const, unused_import, directives_ordering, always_use_package_imports, instantiate_abstract_class
import 'dart:ui';
import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

void registerStateful_counter_demoDependencies(Runtime rt) {
  rt.registerWidget(
    'Center',
    (args) => Center(
      key: args['key'] as Key?,
      widthFactor: args['widthFactor'] as double?,
      heightFactor: args['heightFactor'] as double?,
      child: args['child'] as Widget?,
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
      spacing: args['spacing'] as double? ?? 0.0,
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
      textScaleFactor: args['textScaleFactor'] as double?,
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
      textScaleFactor: args['textScaleFactor'] as double?,
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
      width: args['width'] as double?,
      height: args['height'] as double?,
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
      dimension: args['dimension'] as double?,
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
  rt.registerValueBuilder(
    'TextStyle',
    (args) => TextStyle(
      inherit: args['inherit'] as bool? ?? true,
      color: args['color'] as Color?,
      backgroundColor: args['backgroundColor'] as Color?,
      fontSize: args['fontSize'] as double?,
      fontWeight: args['fontWeight'] as FontWeight?,
      fontStyle: args['fontStyle'] as FontStyle?,
      letterSpacing: args['letterSpacing'] as double?,
      wordSpacing: args['wordSpacing'] as double?,
      textBaseline: args['textBaseline'] as TextBaseline?,
      height: args['height'] as double?,
      leadingDistribution:
          args['leadingDistribution'] as TextLeadingDistribution?,
      locale: args['locale'] as Locale?,
      foreground: args['foreground'] as Paint?,
      background: args['background'] as Paint?,
      shadows: args['shadows'] as List<Shadow>?,
      fontFeatures: args['fontFeatures'] as List<FontFeature>?,
      fontVariations: args['fontVariations'] as List<FontVariation>?,
      decoration: args['decoration'] as TextDecoration?,
      decorationColor: args['decorationColor'] as Color?,
      decorationStyle: args['decorationStyle'] as TextDecorationStyle?,
      decorationThickness: args['decorationThickness'] as double?,
      debugLabel: args['debugLabel'] as String?,
      fontFamily: args['fontFamily'] as String?,
      fontFamilyFallback: args['fontFamilyFallback'] as List<String>?,
      package: args['package'] as String?,
      overflow: args['overflow'] as TextOverflow?,
    ),
  );
  rt.registerConstant('MainAxisAlignment.center', MainAxisAlignment.center);
}
