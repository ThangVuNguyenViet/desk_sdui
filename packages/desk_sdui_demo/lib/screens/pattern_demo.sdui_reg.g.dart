// GENERATED CODE — DO NOT MODIFY BY HAND
// ignore_for_file: cast_nullable_to_non_nullable, cascade_invocations, prefer_const_constructors, lines_longer_than_80_chars, unnecessary_const, unused_import, directives_ordering, always_use_package_imports, instantiate_abstract_class
import 'dart:ui';
import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

void registerPattern_demoDependencies(Runtime rt) {
  rt.registerWidget(
    'CircularProgressIndicator',
    (args) => CircularProgressIndicator(
      key: args['key'] as Key?,
      value: args['value'] as double?,
      backgroundColor: args['backgroundColor'] as Color?,
      color: args['color'] as Color?,
      valueColor: args['valueColor'] as Animation<Color?>?,
      strokeWidth: args['strokeWidth'] as double?,
      strokeAlign: args['strokeAlign'] as double?,
      semanticsLabel: args['semanticsLabel'] as String?,
      semanticsValue: args['semanticsValue'] as String?,
      strokeCap: args['strokeCap'] as StrokeCap?,
      constraints: args['constraints'] as BoxConstraints?,
      trackGap: args['trackGap'] as double?,
      year2023: args['year2023'] as bool?,
      padding: args['padding'] as EdgeInsetsGeometry?,
      controller: args['controller'] as AnimationController?,
    ),
  );
  rt.registerWidget(
    'CircularProgressIndicator.adaptive',
    (args) => CircularProgressIndicator.adaptive(
      key: args['key'] as Key?,
      value: args['value'] as double?,
      backgroundColor: args['backgroundColor'] as Color?,
      valueColor: args['valueColor'] as Animation<Color?>?,
      strokeWidth: args['strokeWidth'] as double?,
      semanticsLabel: args['semanticsLabel'] as String?,
      semanticsValue: args['semanticsValue'] as String?,
      strokeCap: args['strokeCap'] as StrokeCap?,
      strokeAlign: args['strokeAlign'] as double?,
      constraints: args['constraints'] as BoxConstraints?,
      trackGap: args['trackGap'] as double?,
      year2023: args['year2023'] as bool?,
      padding: args['padding'] as EdgeInsetsGeometry?,
      controller: args['controller'] as AnimationController?,
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
}
