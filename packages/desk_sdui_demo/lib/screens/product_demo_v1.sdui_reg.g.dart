// GENERATED CODE — DO NOT MODIFY BY HAND
// ignore_for_file: cast_nullable_to_non_nullable, cascade_invocations, prefer_const_constructors, lines_longer_than_80_chars, unnecessary_const, unused_import, directives_ordering, always_use_package_imports, instantiate_abstract_class
import 'dart:ui';
import 'package:desk_sdui_demo/desk_sdui_demo.dart';
import 'package:desk_sdui_demo/screens/product_demo_v1.dart';
import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

void registerProduct_demoDependencies(Runtime rt) {
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
    'Card',
    (args) => Card(
      key: args['key'] as Key?,
      color: args['color'] as Color?,
      shadowColor: args['shadowColor'] as Color?,
      surfaceTintColor: args['surfaceTintColor'] as Color?,
      elevation: (args['elevation'] as num?)?.toDouble(),
      shape: args['shape'] as ShapeBorder?,
      borderOnForeground: args['borderOnForeground'] as bool? ?? true,
      margin: args['margin'] as EdgeInsetsGeometry?,
      clipBehavior: args['clipBehavior'] as Clip?,
      child: args['child'] as Widget?,
      semanticContainer: args['semanticContainer'] as bool? ?? true,
    ),
  );
  rt.registerWidget(
    'Card.filled',
    (args) => Card.filled(
      key: args['key'] as Key?,
      color: args['color'] as Color?,
      shadowColor: args['shadowColor'] as Color?,
      surfaceTintColor: args['surfaceTintColor'] as Color?,
      elevation: (args['elevation'] as num?)?.toDouble(),
      shape: args['shape'] as ShapeBorder?,
      borderOnForeground: args['borderOnForeground'] as bool? ?? true,
      margin: args['margin'] as EdgeInsetsGeometry?,
      clipBehavior: args['clipBehavior'] as Clip?,
      child: args['child'] as Widget?,
      semanticContainer: args['semanticContainer'] as bool? ?? true,
    ),
  );
  rt.registerWidget(
    'Card.outlined',
    (args) => Card.outlined(
      key: args['key'] as Key?,
      color: args['color'] as Color?,
      shadowColor: args['shadowColor'] as Color?,
      surfaceTintColor: args['surfaceTintColor'] as Color?,
      elevation: (args['elevation'] as num?)?.toDouble(),
      shape: args['shape'] as ShapeBorder?,
      borderOnForeground: args['borderOnForeground'] as bool? ?? true,
      margin: args['margin'] as EdgeInsetsGeometry?,
      clipBehavior: args['clipBehavior'] as Clip?,
      child: args['child'] as Widget?,
      semanticContainer: args['semanticContainer'] as bool? ?? true,
    ),
  );
  rt.registerWidget(
    'ListTile',
    (args) => ListTile(
      key: args['key'] as Key?,
      leading: args['leading'] as Widget?,
      title: args['title'] as Widget?,
      subtitle: args['subtitle'] as Widget?,
      trailing: args['trailing'] as Widget?,
      isThreeLine: args['isThreeLine'] as bool?,
      dense: args['dense'] as bool?,
      visualDensity: args['visualDensity'] as VisualDensity?,
      shape: args['shape'] as ShapeBorder?,
      style: args['style'] as ListTileStyle?,
      selectedColor: args['selectedColor'] as Color?,
      iconColor: args['iconColor'] as Color?,
      textColor: args['textColor'] as Color?,
      titleTextStyle: args['titleTextStyle'] as TextStyle?,
      subtitleTextStyle: args['subtitleTextStyle'] as TextStyle?,
      leadingAndTrailingTextStyle:
          args['leadingAndTrailingTextStyle'] as TextStyle?,
      contentPadding: args['contentPadding'] as EdgeInsetsGeometry?,
      enabled: args['enabled'] as bool? ?? true,
      onTap: args['onTap'] as void Function()?,
      onLongPress: args['onLongPress'] as void Function()?,
      onFocusChange: args['onFocusChange'] as void Function(bool)?,
      mouseCursor: args['mouseCursor'] as MouseCursor?,
      selected: args['selected'] as bool? ?? false,
      focusColor: args['focusColor'] as Color?,
      hoverColor: args['hoverColor'] as Color?,
      splashColor: args['splashColor'] as Color?,
      focusNode: args['focusNode'] as FocusNode?,
      autofocus: args['autofocus'] as bool? ?? false,
      tileColor: args['tileColor'] as Color?,
      selectedTileColor: args['selectedTileColor'] as Color?,
      enableFeedback: args['enableFeedback'] as bool?,
      horizontalTitleGap: (args['horizontalTitleGap'] as num?)?.toDouble(),
      minVerticalPadding: (args['minVerticalPadding'] as num?)?.toDouble(),
      minLeadingWidth: (args['minLeadingWidth'] as num?)?.toDouble(),
      minTileHeight: (args['minTileHeight'] as num?)?.toDouble(),
      titleAlignment: args['titleAlignment'] as ListTileTitleAlignment?,
      internalAddSemanticForOnTap:
          args['internalAddSemanticForOnTap'] as bool? ?? true,
      statesController: args['statesController'] as WidgetStatesController?,
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
    'demoShowSnackBar',
    (args) =>
        demoShowSnackBar(args['arg0'] as BuildContext, args['arg1'] as String),
  );
  rt.registerGetter(
    'ProductViewModel.products',
    (r) => (r as ProductViewModel).products,
  );
  rt.registerGetter('Product.title', (r) => (r as Product).title);
  rt.registerGetter('Product.description', (r) => (r as Product).description);
}
