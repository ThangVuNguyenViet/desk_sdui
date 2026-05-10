import 'package:flutter/material.dart';
import '../runtime.dart';

void registerBuiltinWidgets(Runtime rt) {
  rt.registerWidgetWithContext('Container', (ctx, args) => Container(
        padding: args['padding'] as EdgeInsetsGeometry?,
        margin: args['margin'] as EdgeInsetsGeometry?,
        color: args['color'] as Color?,
        width: (args['width'] as num?)?.toDouble(),
        height: (args['height'] as num?)?.toDouble(),
        alignment: args['alignment'] as AlignmentGeometry?,
        child: args['child'] as Widget?,
      ),);

  rt.registerWidgetWithContext('Padding', (ctx, args) => Padding(
        padding: args['padding']! as EdgeInsetsGeometry,
        child: args['child']! as Widget,
      ),);

  rt.registerWidgetWithContext('SizedBox', (ctx, args) => SizedBox(
        width: (args['width'] as num?)?.toDouble(),
        height: (args['height'] as num?)?.toDouble(),
        child: args['child'] as Widget?,
      ),);

  rt.registerWidgetWithContext('Column', (ctx, args) => Column(
        mainAxisAlignment:
            args['mainAxisAlignment'] as MainAxisAlignment? ??
                MainAxisAlignment.start,
        crossAxisAlignment:
            args['crossAxisAlignment'] as CrossAxisAlignment? ??
                CrossAxisAlignment.center,
        mainAxisSize:
            args['mainAxisSize'] as MainAxisSize? ?? MainAxisSize.max,
        children:
            ((args['children'] as List?) ?? const []).cast<Widget>(),
      ),);

  rt.registerWidgetWithContext('Row', (ctx, args) => Row(
        mainAxisAlignment:
            args['mainAxisAlignment'] as MainAxisAlignment? ??
                MainAxisAlignment.start,
        crossAxisAlignment:
            args['crossAxisAlignment'] as CrossAxisAlignment? ??
                CrossAxisAlignment.center,
        textBaseline: args['textBaseline'] as TextBaseline?,
        mainAxisSize:
            args['mainAxisSize'] as MainAxisSize? ?? MainAxisSize.max,
        children:
            ((args['children'] as List?) ?? const []).cast<Widget>(),
      ),);

  rt.registerWidgetWithContext('Stack', (ctx, args) => Stack(
        alignment: args['alignment'] as AlignmentGeometry? ??
            AlignmentDirectional.topStart,
        fit: args['fit'] as StackFit? ?? StackFit.loose,
        children:
            ((args['children'] as List?) ?? const []).cast<Widget>(),
      ),);

  rt.registerWidgetWithContext(
    'Center',
    (ctx, args) => Center(child: args['child'] as Widget?),
  );

  rt.registerWidgetWithContext('Align', (ctx, args) => Align(
        alignment: args['alignment'] as AlignmentGeometry? ??
            Alignment.center,
        child: args['child'] as Widget?,
      ),);

  rt.registerWidgetWithContext('Expanded', (ctx, args) => Expanded(
        flex: (args['flex'] as int?) ?? 1,
        child: args['child']! as Widget,
      ),);

  rt.registerWidgetWithContext('Flexible', (ctx, args) => Flexible(
        flex: (args['flex'] as int?) ?? 1,
        child: args['child']! as Widget,
      ),);

  rt.registerWidgetWithContext('Text', (ctx, args) => Text(
        args['data']! as String,
        style: args['style'] as TextStyle?,
        textAlign: args['textAlign'] as TextAlign?,
        maxLines: args['maxLines'] as int?,
        overflow: args['overflow'] as TextOverflow?,
      ),);

  rt.registerWidgetWithContext('Icon', (ctx, args) => Icon(
        args['icon']! as IconData,
        size: (args['size'] as num?)?.toDouble(),
        color: args['color'] as Color?,
      ),);

  rt.registerWidgetWithContext('InkWell', (ctx, args) => InkWell(
        onTap: args['onTap'] as VoidCallback?,
        child: args['child'] as Widget?,
      ),);

  rt.registerWidgetWithContext('GestureDetector', (ctx, args) => GestureDetector(
        onTap: args['onTap'] as VoidCallback?,
        child: args['child'] as Widget?,
      ),);

  rt.registerWidgetWithContext('SingleChildScrollView', (ctx, args) =>
      SingleChildScrollView(
        scrollDirection:
            args['scrollDirection'] as Axis? ?? Axis.vertical,
        padding: args['padding'] as EdgeInsetsGeometry?,
        child: args['child'] as Widget?,
      ),);

  rt.registerWidgetWithContext('ListView', (ctx, args) => ListView(
        scrollDirection:
            args['scrollDirection'] as Axis? ?? Axis.vertical,
        padding: args['padding'] as EdgeInsetsGeometry?,
        shrinkWrap: (args['shrinkWrap'] as bool?) ?? false,
        children:
            ((args['children'] as List?) ?? const []).cast<Widget>(),
      ),);

  rt.registerWidgetWithContext('ClipRRect', (ctx, args) => ClipRRect(
        borderRadius: args['borderRadius'] as BorderRadiusGeometry? ??
            BorderRadius.zero,
        child: args['child'] as Widget?,
      ),);

  rt.registerWidgetWithContext('Card', (ctx, args) => Card(
        elevation: (args['elevation'] as num?)?.toDouble(),
        color: args['color'] as Color?,
        margin: args['margin'] as EdgeInsetsGeometry?,
        child: args['child'] as Widget?,
      ),);

  rt.registerWidgetWithContext('Material', (ctx, args) => Material(
        color: args['color'] as Color?,
        elevation:
            (args['elevation'] as num?)?.toDouble() ?? 0,
        child: args['child'] as Widget?,
      ),);

  rt.registerWidgetWithContext('Divider', (ctx, args) => Divider(
        height: (args['height'] as num?)?.toDouble(),
        thickness: (args['thickness'] as num?)?.toDouble(),
        color: args['color'] as Color?,
      ),);

  rt.registerWidgetWithContext(
    'Spacer',
    (ctx, args) => Spacer(flex: (args['flex'] as int?) ?? 1),
  );

  rt.registerWidgetWithContext('AspectRatio', (ctx, args) => AspectRatio(
        aspectRatio: (args['aspectRatio']! as num).toDouble(),
        child: args['child']! as Widget,
      ),);

  rt.registerWidgetWithContext('Wrap', (ctx, args) => Wrap(
        spacing: (args['spacing'] as num?)?.toDouble() ?? 0,
        runSpacing: (args['runSpacing'] as num?)?.toDouble() ?? 0,
        children:
            ((args['children'] as List?) ?? const []).cast<Widget>(),
      ),);

  rt.registerWidgetWithContext('IntrinsicHeight', (ctx, args) => IntrinsicHeight(
        child: args['child']! as Widget,
      ),);

  rt.registerWidgetWithContext('Positioned', (ctx, args) => Positioned(
        top: (args['top'] as num?)?.toDouble(),
        left: (args['left'] as num?)?.toDouble(),
        right: (args['right'] as num?)?.toDouble(),
        bottom: (args['bottom'] as num?)?.toDouble(),
        width: (args['width'] as num?)?.toDouble(),
        height: (args['height'] as num?)?.toDouble(),
        child: args['child']! as Widget,
      ),);

  rt.registerWidgetWithContext('SafeArea', (ctx, args) => SafeArea(
        child: args['child']! as Widget,
      ),);

  rt.registerWidgetWithContext('NetworkImage', (ctx, args) => Image.network(
        args['src']! as String,
        width: (args['width'] as num?)?.toDouble(),
        height: (args['height'] as num?)?.toDouble(),
        fit: args['fit'] as BoxFit?,
      ),);

  rt.registerWidgetWithContext('AssetImage', (ctx, args) => Image.asset(
        args['src']! as String,
        width: (args['width'] as num?)?.toDouble(),
        height: (args['height'] as num?)?.toDouble(),
        fit: args['fit'] as BoxFit?,
      ),);

  rt.registerFn('TextStyle', (Map<String, Object?> args) => TextStyle(
        fontSize: (args['fontSize'] as num?)?.toDouble(),
        color: args['color'] as Color?,
        fontStyle: args['fontStyle'] as FontStyle?,
        fontWeight: args['fontWeight'] as FontWeight?,
        letterSpacing: (args['letterSpacing'] as num?)?.toDouble(),
        height: (args['height'] as num?)?.toDouble(),
      ));

  rt.registerFn('Color', (Map<String, Object?> args) => Color(
        (args['arg0'] as num).toInt(),
      ));

  rt.registerFn('only', (Map<String, Object?> args) => EdgeInsets.only(
        left: (args['left'] as num?)?.toDouble() ?? 0,
        top: (args['top'] as num?)?.toDouble() ?? 0,
        right: (args['right'] as num?)?.toDouble() ?? 0,
        bottom: (args['bottom'] as num?)?.toDouble() ?? 0,
      ));

  rt.registerFn('fromLTRB', (Map<String, Object?> args) => EdgeInsets.fromLTRB(
        (args['arg0'] as num?)?.toDouble() ?? 0,
        (args['arg1'] as num?)?.toDouble() ?? 0,
        (args['arg2'] as num?)?.toDouble() ?? 0,
        (args['arg3'] as num?)?.toDouble() ?? 0,
      ));

  rt.registerFn('all', (Map<String, Object?> args) => EdgeInsets.all(
        (args['arg0'] as num?)?.toDouble() ?? 0,
      ));

  rt.registerFn('symmetric', (Map<String, Object?> args) => EdgeInsets.symmetric(
        horizontal: (args['horizontal'] as num?)?.toDouble() ?? 0,
        vertical: (args['vertical'] as num?)?.toDouble() ?? 0,
      ));

  rt.registerFn('circular', (Map<String, Object?> args) => BorderRadius.circular(
        (args['arg0'] as num?)?.toDouble() ?? 0,
      ));

  rt.registerFn('BoxDecoration', (Map<String, Object?> args) => BoxDecoration(
        color: args['color'] as Color?,
        shape: args['shape'] == 'circle' ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: args['borderRadius'] as BorderRadiusGeometry?,
        border: args['border'] as Border?,
      ));
}
