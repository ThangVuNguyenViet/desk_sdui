// GENERATED CODE — DO NOT MODIFY BY HAND
// ignore_for_file: cast_nullable_to_non_nullable, cascade_invocations, prefer_const_constructors, lines_longer_than_80_chars, unnecessary_const, unused_import, directives_ordering, always_use_package_imports, instantiate_abstract_class
import 'dart:ui';
import 'package:cue/cue.dart';
import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

void registerChefDependencies(Runtime rt) {
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
      spacing: args['spacing'] as double? ?? 0.0,
      children: (args['children'] as List?)?.cast<Widget>() ?? const [],
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
    'SizedBox',
    (args) => SizedBox(
      key: args['key'] as Key?,
      width: args['width'] as double?,
      height: args['height'] as double?,
      child: args['child'] as Widget?,
    ),
  );
  rt.registerWidget(
    'Container',
    (args) => Container(
      key: args['key'] as Key?,
      alignment: args['alignment'] as AlignmentGeometry?,
      padding: args['padding'] as EdgeInsetsGeometry?,
      color: args['color'] as Color?,
      isAntiAlias: args['isAntiAlias'] as bool? ?? true,
      decoration: args['decoration'] as Decoration?,
      foregroundDecoration: args['foregroundDecoration'] as Decoration?,
      width: args['width'] as double?,
      height: args['height'] as double?,
      constraints: args['constraints'] as BoxConstraints?,
      margin: args['margin'] as EdgeInsetsGeometry?,
      transform: args['transform'] as Matrix4?,
      transformAlignment: args['transformAlignment'] as AlignmentGeometry?,
      child: args['child'] as Widget?,
      clipBehavior: args['clipBehavior'] as Clip? ?? Clip.none,
    ),
  );
  rt.registerWidget(
    'Divider',
    (args) => Divider(
      key: args['key'] as Key?,
      height: args['height'] as double?,
      thickness: args['thickness'] as double?,
      indent: args['indent'] as double?,
      endIndent: args['endIndent'] as double?,
      color: args['color'] as Color?,
      radius: args['radius'] as BorderRadiusGeometry?,
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
      spacing: args['spacing'] as double? ?? 0.0,
      children: (args['children'] as List?)?.cast<Widget>() ?? const [],
    ),
  );
  rt.registerWidget(
    'ClipRRect',
    (args) => ClipRRect(
      key: args['key'] as Key?,
      borderRadius:
          args['borderRadius'] as BorderRadiusGeometry? ?? BorderRadius.zero,
      clipper: args['clipper'] as CustomClipper<RRect>?,
      clipBehavior: args['clipBehavior'] as Clip? ?? Clip.antiAlias,
      child: args['child'] as Widget?,
    ),
  );
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
    'Expanded',
    (args) => Expanded(
      key: args['key'] as Key?,
      flex: args['flex'] as int? ?? 1,
      child: args['child'] as Widget,
    ),
  );
  rt.registerWidget(
    'Positioned',
    (args) => Positioned(
      key: args['key'] as Key?,
      left: args['left'] as double?,
      top: args['top'] as double?,
      right: args['right'] as double?,
      bottom: args['bottom'] as double?,
      width: args['width'] as double?,
      height: args['height'] as double?,
      child: args['child'] as Widget,
    ),
  );
  rt.registerWidget(
    'Wrap',
    (args) => Wrap(
      key: args['key'] as Key?,
      direction: args['direction'] as Axis? ?? Axis.horizontal,
      alignment: args['alignment'] as WrapAlignment? ?? WrapAlignment.start,
      spacing: args['spacing'] as double? ?? 0.0,
      runAlignment:
          args['runAlignment'] as WrapAlignment? ?? WrapAlignment.start,
      runSpacing: args['runSpacing'] as double? ?? 0.0,
      crossAxisAlignment:
          args['crossAxisAlignment'] as WrapCrossAlignment? ??
          WrapCrossAlignment.start,
      textDirection: args['textDirection'] as TextDirection?,
      verticalDirection:
          args['verticalDirection'] as VerticalDirection? ??
          VerticalDirection.down,
      clipBehavior: args['clipBehavior'] as Clip? ?? Clip.none,
      children: (args['children'] as List?)?.cast<Widget>() ?? const [],
    ),
  );
  rt.registerWidget(
    'GestureDetector',
    (args) => GestureDetector(
      key: args['key'] as Key?,
      child: args['child'] as Widget?,
      onTapDown: args['onTapDown'] as void Function(TapDownDetails)?,
      onTapUp: args['onTapUp'] as void Function(TapUpDetails)?,
      onTap: args['onTap'] as void Function()?,
      onTapMove: args['onTapMove'] as void Function(TapMoveDetails)?,
      onTapCancel: args['onTapCancel'] as void Function()?,
      onSecondaryTap: args['onSecondaryTap'] as void Function()?,
      onSecondaryTapDown:
          args['onSecondaryTapDown'] as void Function(TapDownDetails)?,
      onSecondaryTapUp:
          args['onSecondaryTapUp'] as void Function(TapUpDetails)?,
      onSecondaryTapCancel: args['onSecondaryTapCancel'] as void Function()?,
      onTertiaryTapDown:
          args['onTertiaryTapDown'] as void Function(TapDownDetails)?,
      onTertiaryTapUp: args['onTertiaryTapUp'] as void Function(TapUpDetails)?,
      onTertiaryTapCancel: args['onTertiaryTapCancel'] as void Function()?,
      onDoubleTapDown:
          args['onDoubleTapDown'] as void Function(TapDownDetails)?,
      onDoubleTap: args['onDoubleTap'] as void Function()?,
      onDoubleTapCancel: args['onDoubleTapCancel'] as void Function()?,
      onLongPressDown:
          args['onLongPressDown'] as void Function(LongPressDownDetails)?,
      onLongPressCancel: args['onLongPressCancel'] as void Function()?,
      onLongPress: args['onLongPress'] as void Function()?,
      onLongPressStart:
          args['onLongPressStart'] as void Function(LongPressStartDetails)?,
      onLongPressMoveUpdate:
          args['onLongPressMoveUpdate']
              as void Function(LongPressMoveUpdateDetails)?,
      onLongPressUp: args['onLongPressUp'] as void Function()?,
      onLongPressEnd:
          args['onLongPressEnd'] as void Function(LongPressEndDetails)?,
      onSecondaryLongPressDown:
          args['onSecondaryLongPressDown']
              as void Function(LongPressDownDetails)?,
      onSecondaryLongPressCancel:
          args['onSecondaryLongPressCancel'] as void Function()?,
      onSecondaryLongPress: args['onSecondaryLongPress'] as void Function()?,
      onSecondaryLongPressStart:
          args['onSecondaryLongPressStart']
              as void Function(LongPressStartDetails)?,
      onSecondaryLongPressMoveUpdate:
          args['onSecondaryLongPressMoveUpdate']
              as void Function(LongPressMoveUpdateDetails)?,
      onSecondaryLongPressUp:
          args['onSecondaryLongPressUp'] as void Function()?,
      onSecondaryLongPressEnd:
          args['onSecondaryLongPressEnd']
              as void Function(LongPressEndDetails)?,
      onTertiaryLongPressDown:
          args['onTertiaryLongPressDown']
              as void Function(LongPressDownDetails)?,
      onTertiaryLongPressCancel:
          args['onTertiaryLongPressCancel'] as void Function()?,
      onTertiaryLongPress: args['onTertiaryLongPress'] as void Function()?,
      onTertiaryLongPressStart:
          args['onTertiaryLongPressStart']
              as void Function(LongPressStartDetails)?,
      onTertiaryLongPressMoveUpdate:
          args['onTertiaryLongPressMoveUpdate']
              as void Function(LongPressMoveUpdateDetails)?,
      onTertiaryLongPressUp: args['onTertiaryLongPressUp'] as void Function()?,
      onTertiaryLongPressEnd:
          args['onTertiaryLongPressEnd'] as void Function(LongPressEndDetails)?,
      onVerticalDragDown:
          args['onVerticalDragDown'] as void Function(DragDownDetails)?,
      onVerticalDragStart:
          args['onVerticalDragStart'] as void Function(DragStartDetails)?,
      onVerticalDragUpdate:
          args['onVerticalDragUpdate'] as void Function(DragUpdateDetails)?,
      onVerticalDragEnd:
          args['onVerticalDragEnd'] as void Function(DragEndDetails)?,
      onVerticalDragCancel: args['onVerticalDragCancel'] as void Function()?,
      onHorizontalDragDown:
          args['onHorizontalDragDown'] as void Function(DragDownDetails)?,
      onHorizontalDragStart:
          args['onHorizontalDragStart'] as void Function(DragStartDetails)?,
      onHorizontalDragUpdate:
          args['onHorizontalDragUpdate'] as void Function(DragUpdateDetails)?,
      onHorizontalDragEnd:
          args['onHorizontalDragEnd'] as void Function(DragEndDetails)?,
      onHorizontalDragCancel:
          args['onHorizontalDragCancel'] as void Function()?,
      onForcePressStart:
          args['onForcePressStart'] as void Function(ForcePressDetails)?,
      onForcePressPeak:
          args['onForcePressPeak'] as void Function(ForcePressDetails)?,
      onForcePressUpdate:
          args['onForcePressUpdate'] as void Function(ForcePressDetails)?,
      onForcePressEnd:
          args['onForcePressEnd'] as void Function(ForcePressDetails)?,
      onPanDown: args['onPanDown'] as void Function(DragDownDetails)?,
      onPanStart: args['onPanStart'] as void Function(DragStartDetails)?,
      onPanUpdate: args['onPanUpdate'] as void Function(DragUpdateDetails)?,
      onPanEnd: args['onPanEnd'] as void Function(DragEndDetails)?,
      onPanCancel: args['onPanCancel'] as void Function()?,
      onScaleStart: args['onScaleStart'] as void Function(ScaleStartDetails)?,
      onScaleUpdate:
          args['onScaleUpdate'] as void Function(ScaleUpdateDetails)?,
      onScaleEnd: args['onScaleEnd'] as void Function(ScaleEndDetails)?,
      behavior: args['behavior'] as HitTestBehavior?,
      excludeFromSemantics: args['excludeFromSemantics'] as bool? ?? false,
      dragStartBehavior:
          args['dragStartBehavior'] as DragStartBehavior? ??
          DragStartBehavior.start,
      trackpadScrollCausesScale:
          args['trackpadScrollCausesScale'] as bool? ?? false,
      trackpadScrollToScaleFactor:
          args['trackpadScrollToScaleFactor'] as Offset? ??
          kDefaultTrackpadScrollToScaleFactor,
      supportedDevices: args['supportedDevices'] as Set<PointerDeviceKind>?,
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
  rt.registerValueBuilder('Color', (args) => Color(args['arg0'] as int));
  rt.registerValueBuilder(
    'Color.from',
    (args) => Color.from(
      alpha: args['alpha'] as double,
      red: args['red'] as double,
      green: args['green'] as double,
      blue: args['blue'] as double,
      colorSpace: args['colorSpace'] as ColorSpace? ?? ColorSpace.sRGB,
    ),
  );
  rt.registerValueBuilder(
    'Color.fromARGB',
    (args) => Color.fromARGB(
      args['arg0'] as int,
      args['arg1'] as int,
      args['arg2'] as int,
      args['arg3'] as int,
    ),
  );
  rt.registerValueBuilder(
    'Color.fromRGBO',
    (args) => Color.fromRGBO(
      args['arg0'] as int,
      args['arg1'] as int,
      args['arg2'] as int,
      args['arg3'] as double,
    ),
  );
  rt.registerValueBuilder(
    'BorderRadius.all',
    (args) => BorderRadius.all(args['arg0'] as Radius),
  );
  rt.registerValueBuilder(
    'BorderRadius.circular',
    (args) => BorderRadius.circular(args['arg0'] as double),
  );
  rt.registerValueBuilder(
    'BorderRadius.vertical',
    (args) => BorderRadius.vertical(
      top: args['top'] as Radius? ?? Radius.zero,
      bottom: args['bottom'] as Radius? ?? Radius.zero,
    ),
  );
  rt.registerValueBuilder(
    'BorderRadius.horizontal',
    (args) => BorderRadius.horizontal(
      left: args['left'] as Radius? ?? Radius.zero,
      right: args['right'] as Radius? ?? Radius.zero,
    ),
  );
  rt.registerValueBuilder(
    'BorderRadius.only',
    (args) => BorderRadius.only(
      topLeft: args['topLeft'] as Radius? ?? Radius.zero,
      topRight: args['topRight'] as Radius? ?? Radius.zero,
      bottomLeft: args['bottomLeft'] as Radius? ?? Radius.zero,
      bottomRight: args['bottomRight'] as Radius? ?? Radius.zero,
    ),
  );
  rt.registerValueBuilder(
    'BoxDecoration',
    (args) => BoxDecoration(
      color: args['color'] as Color?,
      image: args['image'] as DecorationImage?,
      border: args['border'] as BoxBorder?,
      borderRadius: args['borderRadius'] as BorderRadiusGeometry?,
      boxShadow: args['boxShadow'] as List<BoxShadow>?,
      gradient: args['gradient'] as Gradient?,
      backgroundBlendMode: args['backgroundBlendMode'] as BlendMode?,
      shape: args['shape'] as BoxShape? ?? BoxShape.rectangle,
    ),
  );
  rt.registerConstant('CrossAxisAlignment.stretch', CrossAxisAlignment.stretch);
  rt.registerConstant('CrossAxisAlignment.start', CrossAxisAlignment.start);
  rt.registerConstant('FontStyle.italic', FontStyle.italic);
  rt.registerConstant('FontWeight.w500', FontWeight.w500);
  rt.registerConstant('Icons.person', Icons.person);
  rt.registerConstant('FontWeight.w600', FontWeight.w600);
  rt.registerConstant('BoxShape.circle', BoxShape.circle);
  rt.registerConstant('Icons.play_arrow', Icons.play_arrow);
  rt.registerConstant('Colors.grey', Colors.grey);
  rt.registerConstant('FontWeight.w700', FontWeight.w700);
  rt.registerConstant(
    'CrossAxisAlignment.baseline',
    CrossAxisAlignment.baseline,
  );
  rt.registerConstant('TextBaseline.alphabetic', TextBaseline.alphabetic);
  rt.registerConstant('WrapCrossAlignment.center', WrapCrossAlignment.center);
  rt.registerConstant('Colors.white', Colors.white);
  rt.registerConstant('TextAlign.center', TextAlign.center);
  rt.registerConstant(
    'MainAxisAlignment.spaceBetween',
    MainAxisAlignment.spaceBetween,
  );
  rt.registerConstant('Icons.arrow_back_ios_new', Icons.arrow_back_ios_new);
  rt.registerConstant('Icons.bookmark_border', Icons.bookmark_border);
  rt.registerSubscript(
    'MaterialColor.[]',
    (recv, key) => (recv as MaterialColor)[key as int],
  );
}
