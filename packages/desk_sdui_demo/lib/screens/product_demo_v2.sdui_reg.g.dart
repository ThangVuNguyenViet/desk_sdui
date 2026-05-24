// GENERATED CODE — DO NOT MODIFY BY HAND
// ignore_for_file: cast_nullable_to_non_nullable, cascade_invocations, prefer_const_constructors, lines_longer_than_80_chars, unnecessary_const, unused_import, directives_ordering, always_use_package_imports, instantiate_abstract_class
import 'dart:ui';
import 'package:desk_sdui_demo/desk_sdui_demo.dart';
import 'package:desk_sdui_demo/screens/product_demo_v2.dart';
import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

void registerProduct_demo_v2Dependencies(Runtime rt) {
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
      width: (args['width'] as num?)?.toDouble(),
      height: (args['height'] as num?)?.toDouble(),
      constraints: args['constraints'] as BoxConstraints?,
      margin: args['margin'] as EdgeInsetsGeometry?,
      transform: args['transform'] as Matrix4?,
      transformAlignment: args['transformAlignment'] as AlignmentGeometry?,
      child: args['child'] as Widget?,
      clipBehavior: args['clipBehavior'] as Clip? ?? Clip.none,
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
    'Expanded',
    (args) => Expanded(
      key: args['key'] as Key?,
      flex: args['flex'] as int? ?? 1,
      child: args['child'] as Widget,
    ),
  );
  rt.registerWidget(
    'ListView',
    (args) => ListView(
      key: args['key'] as Key?,
      scrollDirection: args['scrollDirection'] as Axis? ?? Axis.vertical,
      reverse: args['reverse'] as bool? ?? false,
      controller: args['controller'] as ScrollController?,
      primary: args['primary'] as bool?,
      physics: args['physics'] as ScrollPhysics?,
      shrinkWrap: args['shrinkWrap'] as bool? ?? false,
      padding: args['padding'] as EdgeInsetsGeometry?,
      itemExtent: (args['itemExtent'] as num?)?.toDouble(),
      itemExtentBuilder:
          args['itemExtentBuilder']
              as double? Function(int, SliverLayoutDimensions)?,
      prototypeItem: args['prototypeItem'] as Widget?,
      addAutomaticKeepAlives: args['addAutomaticKeepAlives'] as bool? ?? true,
      addRepaintBoundaries: args['addRepaintBoundaries'] as bool? ?? true,
      addSemanticIndexes: args['addSemanticIndexes'] as bool? ?? true,
      cacheExtent: (args['cacheExtent'] as num?)?.toDouble(),
      children: (args['children'] as List?)?.cast<Widget>() ?? const [],
      semanticChildCount: args['semanticChildCount'] as int?,
      dragStartBehavior:
          args['dragStartBehavior'] as DragStartBehavior? ??
          DragStartBehavior.start,
      keyboardDismissBehavior:
          args['keyboardDismissBehavior'] as ScrollViewKeyboardDismissBehavior?,
      restorationId: args['restorationId'] as String?,
      clipBehavior: args['clipBehavior'] as Clip? ?? Clip.hardEdge,
      hitTestBehavior:
          args['hitTestBehavior'] as HitTestBehavior? ?? HitTestBehavior.opaque,
    ),
  );
  rt.registerWidget(
    'ListView.builder',
    (args) => ListView.builder(
      key: args['key'] as Key?,
      scrollDirection: args['scrollDirection'] as Axis? ?? Axis.vertical,
      reverse: args['reverse'] as bool? ?? false,
      controller: args['controller'] as ScrollController?,
      primary: args['primary'] as bool?,
      physics: args['physics'] as ScrollPhysics?,
      shrinkWrap: args['shrinkWrap'] as bool? ?? false,
      padding: args['padding'] as EdgeInsetsGeometry?,
      itemExtent: (args['itemExtent'] as num?)?.toDouble(),
      itemExtentBuilder:
          args['itemExtentBuilder']
              as double? Function(int, SliverLayoutDimensions)?,
      prototypeItem: args['prototypeItem'] as Widget?,
      itemBuilder: args['itemBuilder'] as Widget? Function(BuildContext, int),
      findChildIndexCallback:
          args['findChildIndexCallback'] as int? Function(Key)?,
      itemCount: args['itemCount'] as int?,
      addAutomaticKeepAlives: args['addAutomaticKeepAlives'] as bool? ?? true,
      addRepaintBoundaries: args['addRepaintBoundaries'] as bool? ?? true,
      addSemanticIndexes: args['addSemanticIndexes'] as bool? ?? true,
      cacheExtent: (args['cacheExtent'] as num?)?.toDouble(),
      semanticChildCount: args['semanticChildCount'] as int?,
      dragStartBehavior:
          args['dragStartBehavior'] as DragStartBehavior? ??
          DragStartBehavior.start,
      keyboardDismissBehavior:
          args['keyboardDismissBehavior'] as ScrollViewKeyboardDismissBehavior?,
      restorationId: args['restorationId'] as String?,
      clipBehavior: args['clipBehavior'] as Clip? ?? Clip.hardEdge,
      hitTestBehavior:
          args['hitTestBehavior'] as HitTestBehavior? ?? HitTestBehavior.opaque,
    ),
  );
  rt.registerWidget(
    'ListView.separated',
    (args) => ListView.separated(
      key: args['key'] as Key?,
      scrollDirection: args['scrollDirection'] as Axis? ?? Axis.vertical,
      reverse: args['reverse'] as bool? ?? false,
      controller: args['controller'] as ScrollController?,
      primary: args['primary'] as bool?,
      physics: args['physics'] as ScrollPhysics?,
      shrinkWrap: args['shrinkWrap'] as bool? ?? false,
      padding: args['padding'] as EdgeInsetsGeometry?,
      itemBuilder: args['itemBuilder'] as Widget? Function(BuildContext, int),
      findChildIndexCallback:
          args['findChildIndexCallback'] as int? Function(Key)?,
      findItemIndexCallback:
          args['findItemIndexCallback'] as int? Function(Key)?,
      separatorBuilder:
          args['separatorBuilder'] as Widget Function(BuildContext, int),
      itemCount: args['itemCount'] as int,
      addAutomaticKeepAlives: args['addAutomaticKeepAlives'] as bool? ?? true,
      addRepaintBoundaries: args['addRepaintBoundaries'] as bool? ?? true,
      addSemanticIndexes: args['addSemanticIndexes'] as bool? ?? true,
      cacheExtent: (args['cacheExtent'] as num?)?.toDouble(),
      dragStartBehavior:
          args['dragStartBehavior'] as DragStartBehavior? ??
          DragStartBehavior.start,
      keyboardDismissBehavior:
          args['keyboardDismissBehavior'] as ScrollViewKeyboardDismissBehavior?,
      restorationId: args['restorationId'] as String?,
      clipBehavior: args['clipBehavior'] as Clip? ?? Clip.hardEdge,
      hitTestBehavior:
          args['hitTestBehavior'] as HitTestBehavior? ?? HitTestBehavior.opaque,
    ),
  );
  rt.registerWidget(
    'ListView.custom',
    (args) => ListView.custom(
      key: args['key'] as Key?,
      scrollDirection: args['scrollDirection'] as Axis? ?? Axis.vertical,
      reverse: args['reverse'] as bool? ?? false,
      controller: args['controller'] as ScrollController?,
      primary: args['primary'] as bool?,
      physics: args['physics'] as ScrollPhysics?,
      shrinkWrap: args['shrinkWrap'] as bool? ?? false,
      padding: args['padding'] as EdgeInsetsGeometry?,
      itemExtent: (args['itemExtent'] as num?)?.toDouble(),
      prototypeItem: args['prototypeItem'] as Widget?,
      itemExtentBuilder:
          args['itemExtentBuilder']
              as double? Function(int, SliverLayoutDimensions)?,
      childrenDelegate: args['childrenDelegate'] as SliverChildDelegate,
      cacheExtent: (args['cacheExtent'] as num?)?.toDouble(),
      semanticChildCount: args['semanticChildCount'] as int?,
      dragStartBehavior:
          args['dragStartBehavior'] as DragStartBehavior? ??
          DragStartBehavior.start,
      keyboardDismissBehavior:
          args['keyboardDismissBehavior'] as ScrollViewKeyboardDismissBehavior?,
      restorationId: args['restorationId'] as String?,
      clipBehavior: args['clipBehavior'] as Clip? ?? Clip.hardEdge,
      hitTestBehavior:
          args['hitTestBehavior'] as HitTestBehavior? ?? HitTestBehavior.opaque,
    ),
  );
  rt.registerWidget(
    'ProductCard',
    (args) => ProductCard(
      p: args['p'] as Product,
      onAddToCart: args['onAddToCart'] as void Function(),
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
  rt.registerConstant('CrossAxisAlignment.start', CrossAxisAlignment.start);
  rt.registerConstant('FontWeight.w900', FontWeight.w900);
  rt.registerConstant('Colors.white', Colors.white);
  rt.registerConstant('FontWeight.w300', FontWeight.w300);
  rt.registerFunction(
    'ProductViewModelProvider.of',
    (args) => ProductViewModelProvider.of(args['arg0'] as BuildContext),
  );
  rt.registerFunction(
    'Theme.of',
    (args) => Theme.of(args['arg0'] as BuildContext),
  );
  rt.registerMethod(
    'ProductViewModel.addToCart',
    (recv, args) => (recv as ProductViewModel).addToCart(
      args['arg0'] as BuildContext,
      args['arg1'] as Product,
    ),
  );
  rt.registerFunction(
    'demoShowSuccess',
    (args) =>
        demoShowSuccess(args['arg0'] as BuildContext, args['arg1'] as String),
  );
  rt.registerGetter(
    'ThemeData.scaffoldBackgroundColor',
    (r) => (r as ThemeData).scaffoldBackgroundColor,
  );
  rt.registerGetter(
    'ProductViewModel.products',
    (r) => (r as ProductViewModel).products,
  );
  rt.registerGetter('Product.title', (r) => (r as Product).title);
}
