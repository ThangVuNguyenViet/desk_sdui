// GENERATED CODE — DO NOT MODIFY BY HAND
// ignore_for_file: cast_nullable_to_non_nullable, cascade_invocations, prefer_const_constructors, lines_longer_than_80_chars, unnecessary_const, unused_import, directives_ordering, always_use_package_imports, instantiate_abstract_class
import 'dart:ui';
import 'package:desk_sdui_demo/screens/counter_minimal.dart';
import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

void registerCounter_minimalDependencies(Runtime rt) {
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
  rt.registerConstant('FontWeight.w800', FontWeight.w800);
}
