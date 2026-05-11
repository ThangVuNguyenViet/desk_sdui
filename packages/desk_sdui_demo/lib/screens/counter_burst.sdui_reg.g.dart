// GENERATED CODE — DO NOT MODIFY BY HAND
// ignore_for_file: cast_nullable_to_non_nullable, cascade_invocations, prefer_const_constructors, lines_longer_than_80_chars, unnecessary_const, unused_import, directives_ordering, always_use_package_imports, instantiate_abstract_class
import 'dart:ui';
import 'package:cue/cue.dart';
import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

void registerCounter_burstDependencies(Runtime rt) {
  rt.registerWidget(
    'Stack',
    (args) => Stack(
      key: args['key'] as Key?,
      alignment:
          args['alignment'] as AlignmentGeometry? ??
          AlignmentDirectional.topStart,
      textDirection: args['textDirection'] as TextDirection?,
      fit: args['fit'] as StackFit? ?? StackFit.loose,
      clipBehavior: args['clipBehavior'] as Clip? ?? Clip.hardEdge,
      children: (args['children'] as List?)?.cast<Widget>() ?? const [],
    ),
  );
  rt.registerWidget(
    'Cue',
    (args) => Cue(
      key: args['key'] as Key?,
      debugLabel: args['debugLabel'] as String?,
      acts: args['acts'] as List<Act>?,
      controller: args['controller'] as CueController,
      child: args['child'] as Widget,
    ),
  );
  rt.registerWidget(
    'Padding',
    (args) => Padding(
      key: args['key'] as Key?,
      padding: args['padding'] as EdgeInsetsGeometry,
      child: args['child'] as Widget?,
    ),
  );
  rt.registerWidget(
    'Icon',
    (args) => Icon(
      args['icon'] as IconData?,
      key: args['key'] as Key?,
      size: args['size'] as double?,
      fill: args['fill'] as double?,
      weight: args['weight'] as double?,
      grade: args['grade'] as double?,
      opticalSize: args['opticalSize'] as double?,
      color: args['color'] as Color?,
      shadows: args['shadows'] as List<Shadow>?,
      semanticLabel: args['semanticLabel'] as String?,
      textDirection: args['textDirection'] as TextDirection?,
      applyTextScaling: args['applyTextScaling'] as bool?,
      blendMode: args['blendMode'] as BlendMode?,
      fontWeight: args['fontWeight'] as FontWeight?,
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
  rt.registerValueBuilder(
    'CueMotion.linear',
    (args) => CueMotion.linear(args['arg0'] as Duration),
  );
  rt.registerValueBuilder(
    'CueMotion.threshold',
    (args) => CueMotion.threshold(
      args['arg0'] as Duration,
      breakpoint: args['breakpoint'] as double,
    ),
  );
  rt.registerValueBuilder(
    'CueMotion.curved',
    (args) => CueMotion.curved(
      args['arg0'] as Duration,
      curve: args['curve'] as Curve,
    ),
  );
  rt.registerValueBuilder(
    'CueMotion.easeIn',
    (args) => CueMotion.easeIn(args['arg0'] as Duration),
  );
  rt.registerValueBuilder(
    'CueMotion.easeOut',
    (args) => CueMotion.easeOut(args['arg0'] as Duration),
  );
  rt.registerValueBuilder(
    'CueMotion.easeInOut',
    (args) => CueMotion.easeInOut(args['arg0'] as Duration),
  );
  rt.registerValueBuilder(
    'CueMotion.easeOutBack',
    (args) => CueMotion.easeOutBack(args['arg0'] as Duration),
  );
  rt.registerValueBuilder(
    'CueMotion.easeInBack',
    (args) => CueMotion.easeInBack(args['arg0'] as Duration),
  );
  rt.registerValueBuilder(
    'CueMotion.fastOutSlowIn',
    (args) => CueMotion.fastOutSlowIn(args['arg0'] as Duration),
  );
  rt.registerValueBuilder(
    'CueMotion.spring',
    (args) => CueMotion.spring(
      duration: args['duration'] as Duration,
      bounce: args['bounce'] as double,
    ),
  );
  rt.registerValueBuilder(
    'CueMotion.smooth',
    (args) => CueMotion.smooth(
      mass: args['mass'] as double,
      stiffness: args['stiffness'] as double,
      dampingRatio: args['dampingRatio'] as double,
      tolerance: args['tolerance'] as Tolerance,
      snapToEnd: args['snapToEnd'] as bool,
    ),
  );
  rt.registerValueBuilder(
    'CueMotion.gentle',
    (args) => CueMotion.gentle(
      mass: args['mass'] as double,
      stiffness: args['stiffness'] as double,
      dampingRatio: args['dampingRatio'] as double,
      tolerance: args['tolerance'] as Tolerance,
      snapToEnd: args['snapToEnd'] as bool,
    ),
  );
  rt.registerValueBuilder(
    'CueMotion.bouncy',
    (args) => CueMotion.bouncy(
      mass: args['mass'] as double,
      stiffness: args['stiffness'] as double,
      dampingRatio: args['dampingRatio'] as double,
      tolerance: args['tolerance'] as Tolerance,
      snapToEnd: args['snapToEnd'] as bool,
    ),
  );
  rt.registerValueBuilder(
    'CueMotion.wobbly',
    (args) => CueMotion.wobbly(
      mass: args['mass'] as double,
      stiffness: args['stiffness'] as double,
      dampingRatio: args['dampingRatio'] as double,
      tolerance: args['tolerance'] as Tolerance,
      snapToEnd: args['snapToEnd'] as bool,
    ),
  );
  rt.registerValueBuilder(
    'CueMotion.snappy',
    (args) => CueMotion.snappy(
      mass: args['mass'] as double,
      stiffness: args['stiffness'] as double,
      dampingRatio: args['dampingRatio'] as double,
      tolerance: args['tolerance'] as Tolerance,
      snapToEnd: args['snapToEnd'] as bool,
    ),
  );
  rt.registerValueBuilder(
    'CueMotion.spatial',
    (args) => CueMotion.spatial(
      mass: args['mass'] as double,
      stiffness: args['stiffness'] as double,
      dampingRatio: args['dampingRatio'] as double,
      tolerance: args['tolerance'] as Tolerance,
      snapToEnd: args['snapToEnd'] as bool,
    ),
  );
  rt.registerValueBuilder(
    'CueMotion.spatialSlow',
    (args) => CueMotion.spatialSlow(
      mass: args['mass'] as double,
      stiffness: args['stiffness'] as double,
      dampingRatio: args['dampingRatio'] as double,
      tolerance: args['tolerance'] as Tolerance,
      snapToEnd: args['snapToEnd'] as bool,
    ),
  );
  rt.registerValueBuilder(
    'CueMotion.spatialFast',
    (args) => CueMotion.spatialFast(
      mass: args['mass'] as double,
      stiffness: args['stiffness'] as double,
      dampingRatio: args['dampingRatio'] as double,
      tolerance: args['tolerance'] as Tolerance,
      snapToEnd: args['snapToEnd'] as bool,
    ),
  );
  rt.registerValueBuilder(
    'CueMotion.effect',
    (args) => CueMotion.effect(
      mass: args['mass'] as double,
      stiffness: args['stiffness'] as double,
      dampingRatio: args['dampingRatio'] as double,
      tolerance: args['tolerance'] as Tolerance,
      snapToEnd: args['snapToEnd'] as bool,
    ),
  );
  rt.registerValueBuilder(
    'CueMotion.effectSlow',
    (args) => CueMotion.effectSlow(
      mass: args['mass'] as double,
      stiffness: args['stiffness'] as double,
      dampingRatio: args['dampingRatio'] as double,
      tolerance: args['tolerance'] as Tolerance,
      snapToEnd: args['snapToEnd'] as bool,
    ),
  );
  rt.registerValueBuilder(
    'CueMotion.effectFast',
    (args) => CueMotion.effectFast(
      mass: args['mass'] as double,
      stiffness: args['stiffness'] as double,
      dampingRatio: args['dampingRatio'] as double,
      tolerance: args['tolerance'] as Tolerance,
      snapToEnd: args['snapToEnd'] as bool,
    ),
  );
  rt.registerValueBuilder(
    'Act.scale',
    (args) => Act.scale(
      from: args['from'] as double,
      to: args['to'] as double,
      motion: args['motion'] as CueMotion?,
      reverse: args['reverse'] as ReverseBehavior<double>,
      delay: args['delay'] as Duration,
      alignment: args['alignment'] as AlignmentGeometry,
    ),
  );
  rt.registerValueBuilder(
    'Act.zoomIn',
    (args) => Act.zoomIn(
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<double>,
      alignment: args['alignment'] as AlignmentGeometry,
    ),
  );
  rt.registerValueBuilder(
    'Act.zoomOut',
    (args) => Act.zoomOut(
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<double>,
      alignment: args['alignment'] as AlignmentGeometry,
    ),
  );
  rt.registerValueBuilder(
    'Act.stretch',
    (args) => Act.stretch(
      from: args['from'] as Stretch,
      to: args['to'] as Stretch,
      motion: args['motion'] as CueMotion?,
      reverse: args['reverse'] as ReverseBehavior<Stretch>,
      delay: args['delay'] as Duration,
      alignment: args['alignment'] as AlignmentGeometry,
    ),
  );
  rt.registerValueBuilder(
    'Act.fractionalSize',
    (args) => Act.fractionalSize(
      widthFactor: args['widthFactor'] as AnimatableValue<double>?,
      heightFactor: args['heightFactor'] as AnimatableValue<double>?,
      alignment: args['alignment'] as AnimatableValue<AlignmentGeometry>?,
      motion: args['motion'] as CueMotion?,
      reverse: args['reverse'] as ReverseBehavior<FractionalSize>,
      delay: args['delay'] as Duration,
    ),
  );
  rt.registerValueBuilder(
    'Act.translate',
    (args) => Act.translate(
      from: args['from'] as Offset,
      to: args['to'] as Offset,
      motion: args['motion'] as CueMotion?,
      reverse: args['reverse'] as ReverseBehavior<Offset>,
      delay: args['delay'] as Duration,
    ),
  );
  rt.registerValueBuilder(
    'Act.parallax',
    (args) => Act.parallax(
      slide: args['slide'] as double,
      axis: args['axis'] as Axis,
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<double>,
    ),
  );
  rt.registerValueBuilder(
    'Act.translateX',
    (args) => Act.translateX(
      from: args['from'] as double,
      to: args['to'] as double,
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<double>,
    ),
  );
  rt.registerValueBuilder(
    'Act.translateY',
    (args) => Act.translateY(
      from: args['from'] as double,
      to: args['to'] as double,
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<double>,
    ),
  );
  rt.registerValueBuilder(
    'Act.translateFromGlobal',
    (args) => Act.translateFromGlobal(
      offset: args['offset'] as Offset,
      toLocal: args['toLocal'] as Offset,
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
    ),
  );
  rt.registerValueBuilder(
    'Act.translateFromGlobalRect',
    (args) => Act.translateFromGlobalRect(
      args['arg0'] as Rect,
      alignment: args['alignment'] as AlignmentGeometry,
      toLocal: args['toLocal'] as Offset,
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
    ),
  );
  rt.registerValueBuilder(
    'Act.translateFromGlobalKey',
    (args) => Act.translateFromGlobalKey(
      args['arg0'] as GlobalKey<State<StatefulWidget>>,
      alignment: args['alignment'] as AlignmentGeometry,
      toLocal: args['toLocal'] as Offset,
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
    ),
  );
  rt.registerValueBuilder(
    'Act.slide',
    (args) => Act.slide(
      from: args['from'] as Offset,
      to: args['to'] as Offset,
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<Offset>,
    ),
  );
  rt.registerValueBuilder(
    'Act.slideX',
    (args) => Act.slideX(
      from: args['from'] as double,
      to: args['to'] as double,
      motion: args['motion'] as CueMotion?,
      reverse: args['reverse'] as ReverseBehavior<double>,
      delay: args['delay'] as Duration,
    ),
  );
  rt.registerValueBuilder(
    'Act.slideY',
    (args) => Act.slideY(
      from: args['from'] as double,
      to: args['to'] as double,
      motion: args['motion'] as CueMotion?,
      reverse: args['reverse'] as ReverseBehavior<double>,
      delay: args['delay'] as Duration,
    ),
  );
  rt.registerValueBuilder(
    'Act.slideUp',
    (args) => Act.slideUp(
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<Offset>,
    ),
  );
  rt.registerValueBuilder(
    'Act.slideDown',
    (args) => Act.slideDown(
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<Offset>,
    ),
  );
  rt.registerValueBuilder(
    'Act.slideFromLeading',
    (args) => Act.slideFromLeading(
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<Offset>,
    ),
  );
  rt.registerValueBuilder(
    'Act.slideFromTrailing',
    (args) => Act.slideFromTrailing(
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<Offset>,
    ),
  );
  rt.registerValueBuilder(
    'Act.opacity',
    (args) => Act.opacity(
      from: args['from'] as double,
      to: args['to'] as double,
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<double>,
    ),
  );
  rt.registerValueBuilder(
    'Act.fadeIn',
    (args) => Act.fadeIn(
      from: args['from'] as double,
      motion: args['motion'] as CueMotion?,
      reverse: args['reverse'] as ReverseBehavior<double>,
      delay: args['delay'] as Duration,
    ),
  );
  rt.registerValueBuilder(
    'Act.fadeOut',
    (args) => Act.fadeOut(
      from: args['from'] as double,
      motion: args['motion'] as CueMotion?,
      reverse: args['reverse'] as ReverseBehavior<double>,
      delay: args['delay'] as Duration,
    ),
  );
  rt.registerValueBuilder(
    'Act.align',
    (args) => Act.align(
      from: args['from'] as AlignmentGeometry,
      to: args['to'] as AlignmentGeometry,
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<AlignmentGeometry>,
    ),
  );
  rt.registerValueBuilder(
    'Act.padding',
    (args) => Act.padding(
      from: args['from'] as EdgeInsetsGeometry,
      to: args['to'] as EdgeInsetsGeometry,
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<EdgeInsetsGeometry>,
    ),
  );
  rt.registerValueBuilder(
    'Act.blur',
    (args) => Act.blur(
      from: args['from'] as double,
      to: args['to'] as double,
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<double>,
    ),
  );
  rt.registerValueBuilder(
    'Act.focus',
    (args) => Act.focus(
      from: args['from'] as double,
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<double>,
    ),
  );
  rt.registerValueBuilder(
    'Act.unfocus',
    (args) => Act.unfocus(
      to: args['to'] as double,
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<double>,
    ),
  );
  rt.registerValueBuilder(
    'Act.backdropBlur',
    (args) => Act.backdropBlur(
      from: args['from'] as double,
      to: args['to'] as double,
      motion: args['motion'] as CueMotion?,
      blendMode: args['blendMode'] as BlendMode,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<double>,
    ),
  );
  rt.registerValueBuilder(
    'Act.colorTint',
    (args) => Act.colorTint(
      from: args['from'] as Color,
      to: args['to'] as Color,
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<Color>,
    ),
  );
  rt.registerValueBuilder(
    'Act.sizedBox',
    (args) => Act.sizedBox(
      width: args['width'] as AnimatableValue<double>?,
      height: args['height'] as AnimatableValue<double>?,
      alignment: args['alignment'] as AlignmentGeometry,
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<Size>,
    ),
  );
  rt.registerValueBuilder(
    'Act.sizedClip',
    (args) => Act.sizedClip(
      from: args['from'] as NSize?,
      to: args['to'] as NSize?,
      motion: args['motion'] as CueMotion?,
      alignment: args['alignment'] as AlignmentGeometry,
      clipGeometry: args['clipGeometry'] as ClipGeometry,
      clipBehavior: args['clipBehavior'] as Clip,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<NSize>,
    ),
  );
  rt.registerValueBuilder(
    'Act.clip',
    (args) => Act.clip(
      borderRadius: args['borderRadius'] as BorderRadiusGeometry,
      alignment: args['alignment'] as AlignmentGeometry,
      useSuperellipse: args['useSuperellipse'] as bool,
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
    ),
  );
  rt.registerValueBuilder(
    'Act.clipHeight',
    (args) => Act.clipHeight(
      fromFactor: args['fromFactor'] as double,
      toFactor: args['toFactor'] as double,
      alignment: args['alignment'] as AlignmentGeometry,
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
    ),
  );
  rt.registerValueBuilder(
    'Act.clipWidth',
    (args) => Act.clipWidth(
      fromFactor: args['fromFactor'] as double,
      toFactor: args['toFactor'] as double,
      alignment: args['alignment'] as AlignmentGeometry,
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
    ),
  );
  rt.registerValueBuilder(
    'Act.circularClip',
    (args) => Act.circularClip(
      alignment: args['alignment'] as AlignmentGeometry,
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
    ),
  );
  rt.registerValueBuilder(
    'Act.rotate',
    (args) => Act.rotate(
      from: args['from'] as double,
      to: args['to'] as double,
      motion: args['motion'] as CueMotion?,
      unit: args['unit'] as RotateUnit,
      axis: args['axis'] as RotateAxis,
      delay: args['delay'] as Duration,
      alignment: args['alignment'] as AlignmentGeometry,
      reverse: args['reverse'] as ReverseBehavior<double>,
    ),
  );
  rt.registerValueBuilder(
    'Act.rotate3D',
    (args) => Act.rotate3D(
      from: args['from'] as Rotation3D,
      to: args['to'] as Rotation3D,
      motion: args['motion'] as CueMotion?,
      unit: args['unit'] as Rotate3DUnit,
      perspective: args['perspective'] as double,
      alignment: args['alignment'] as AlignmentGeometry,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<Rotation3D>,
    ),
  );
  rt.registerValueBuilder(
    'Act.rotateLayout',
    (args) => Act.rotateLayout(
      from: args['from'] as double,
      to: args['to'] as double,
      motion: args['motion'] as CueMotion?,
      unit: args['unit'] as RotateUnit,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<double>,
    ),
  );
  rt.registerValueBuilder(
    'Act.flipX',
    (args) => Act.flipX(
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
      perspective: args['perspective'] as double,
    ),
  );
  rt.registerValueBuilder(
    'Act.flipY',
    (args) => Act.flipY(
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
      perspective: args['perspective'] as double,
    ),
  );
  rt.registerValueBuilder(
    'Act.skew',
    (args) => Act.skew(
      from: args['from'] as Skew,
      to: args['to'] as Skew,
      alignment: args['alignment'] as AlignmentGeometry?,
      origin: args['origin'] as Offset?,
      motion: args['motion'] as CueMotion?,
      reverse: args['reverse'] as ReverseBehavior<Skew>,
      delay: args['delay'] as Duration,
    ),
  );
  rt.registerValueBuilder(
    'Act.textStyle',
    (args) => Act.textStyle(
      from: args['from'] as TextStyle,
      to: args['to'] as TextStyle,
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<TextStyle>,
    ),
  );
  rt.registerValueBuilder(
    'Act.iconTheme',
    (args) => Act.iconTheme(
      from: args['from'] as IconThemeData,
      to: args['to'] as IconThemeData,
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<IconThemeData>,
    ),
  );
  rt.registerValueBuilder(
    'Act.transform',
    (args) => Act.transform(
      from: args['from'] as Matrix4?,
      to: args['to'] as Matrix4,
      motion: args['motion'] as CueMotion?,
      alignment: args['alignment'] as AlignmentGeometry,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<Matrix4>,
    ),
  );
  rt.registerValueBuilder(
    'Act.decorate',
    (args) => Act.decorate(
      color: args['color'] as AnimatableValue<Color>?,
      borderRadius:
          args['borderRadius'] as AnimatableValue<BorderRadiusGeometry>?,
      border: args['border'] as AnimatableValue<BoxBorder>?,
      boxShadow: args['boxShadow'] as AnimatableValue<List<BoxShadow>>?,
      gradient: args['gradient'] as AnimatableValue<Gradient>?,
      shape: args['shape'] as BoxShape,
      position: args['position'] as DecorationPosition,
      motion: args['motion'] as CueMotion?,
      delay: args['delay'] as Duration,
      reverse: args['reverse'] as ReverseBehavior<Decoration>,
    ),
  );
  rt.registerValueBuilder(
    'EdgeInsets.fromLTRB',
    (args) => EdgeInsets.fromLTRB(
      args['arg0'] as double,
      args['arg1'] as double,
      args['arg2'] as double,
      args['arg3'] as double,
    ),
  );
  rt.registerValueBuilder(
    'EdgeInsets.all',
    (args) => EdgeInsets.all(args['arg0'] as double),
  );
  rt.registerValueBuilder(
    'EdgeInsets.only',
    (args) => EdgeInsets.only(
      left: args['left'] as double? ?? 0.0,
      top: args['top'] as double? ?? 0.0,
      right: args['right'] as double? ?? 0.0,
      bottom: args['bottom'] as double? ?? 0.0,
    ),
  );
  rt.registerValueBuilder(
    'EdgeInsets.symmetric',
    (args) => EdgeInsets.symmetric(
      vertical: args['vertical'] as double? ?? 0.0,
      horizontal: args['horizontal'] as double? ?? 0.0,
    ),
  );
  rt.registerValueBuilder(
    'EdgeInsets.fromViewPadding',
    (args) => EdgeInsets.fromViewPadding(
      args['arg0'] as ViewPadding,
      args['arg1'] as double,
    ),
  );
  rt.registerValueBuilder(
    'EdgeInsets.fromWindowPadding',
    (args) => EdgeInsets.fromWindowPadding(
      args['arg0'] as ViewPadding,
      args['arg1'] as double,
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
  rt.registerConstant('Alignment.center', Alignment.center);
  rt.registerConstant('Icons.star', Icons.star);
  rt.registerConstant('Colors.amber', Colors.amber);
  rt.registerConstant('FontWeight.w900', FontWeight.w900);
}
