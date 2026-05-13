// GENERATED CODE — DO NOT MODIFY BY HAND
// ignore_for_file: cast_nullable_to_non_nullable, cascade_invocations, prefer_const_constructors, lines_longer_than_80_chars, unnecessary_const, unused_import, directives_ordering, always_use_package_imports, instantiate_abstract_class
import 'dart:ui';
import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

void registerCascade_demoDependencies(Runtime rt) {
  rt.registerWidget(
    'TextField',
    (args) => TextField(
      key: args['key'] as Key?,
      groupId: args['groupId'] as Object? ?? EditableText,
      controller: args['controller'] as TextEditingController?,
      focusNode: args['focusNode'] as FocusNode?,
      undoController: args['undoController'] as UndoHistoryController?,
      decoration:
          args['decoration'] as InputDecoration? ?? const InputDecoration(),
      keyboardType: args['keyboardType'] as TextInputType?,
      textInputAction: args['textInputAction'] as TextInputAction?,
      textCapitalization:
          args['textCapitalization'] as TextCapitalization? ??
          TextCapitalization.none,
      style: args['style'] as TextStyle?,
      strutStyle: args['strutStyle'] as StrutStyle?,
      textAlign: args['textAlign'] as TextAlign? ?? TextAlign.start,
      textAlignVertical: args['textAlignVertical'] as TextAlignVertical?,
      textDirection: args['textDirection'] as TextDirection?,
      readOnly: args['readOnly'] as bool? ?? false,
      toolbarOptions: args['toolbarOptions'] as ToolbarOptions?,
      showCursor: args['showCursor'] as bool?,
      autofocus: args['autofocus'] as bool? ?? false,
      statesController: args['statesController'] as WidgetStatesController?,
      obscuringCharacter: args['obscuringCharacter'] as String? ?? '•',
      obscureText: args['obscureText'] as bool? ?? false,
      autocorrect: args['autocorrect'] as bool?,
      smartDashesType: args['smartDashesType'] as SmartDashesType?,
      smartQuotesType: args['smartQuotesType'] as SmartQuotesType?,
      enableSuggestions: args['enableSuggestions'] as bool? ?? true,
      maxLines: args['maxLines'] as int? ?? 1,
      minLines: args['minLines'] as int?,
      expands: args['expands'] as bool? ?? false,
      maxLength: args['maxLength'] as int?,
      maxLengthEnforcement:
          args['maxLengthEnforcement'] as MaxLengthEnforcement?,
      onChanged: args['onChanged'] as void Function(String)?,
      onEditingComplete: args['onEditingComplete'] as void Function()?,
      onSubmitted: args['onSubmitted'] as void Function(String)?,
      onAppPrivateCommand:
          args['onAppPrivateCommand']
              as void Function(String, Map<String, dynamic>)?,
      inputFormatters: args['inputFormatters'] as List<TextInputFormatter>?,
      enabled: args['enabled'] as bool?,
      ignorePointers: args['ignorePointers'] as bool?,
      cursorWidth: args['cursorWidth'] as double? ?? 2.0,
      cursorHeight: args['cursorHeight'] as double?,
      cursorRadius: args['cursorRadius'] as Radius?,
      cursorOpacityAnimates: args['cursorOpacityAnimates'] as bool?,
      cursorColor: args['cursorColor'] as Color?,
      cursorErrorColor: args['cursorErrorColor'] as Color?,
      selectionHeightStyle: args['selectionHeightStyle'] as BoxHeightStyle?,
      selectionWidthStyle: args['selectionWidthStyle'] as BoxWidthStyle?,
      keyboardAppearance: args['keyboardAppearance'] as Brightness?,
      scrollPadding:
          args['scrollPadding'] as EdgeInsets? ?? const EdgeInsets.all(20.0),
      dragStartBehavior:
          args['dragStartBehavior'] as DragStartBehavior? ??
          DragStartBehavior.start,
      enableInteractiveSelection: args['enableInteractiveSelection'] as bool?,
      selectAllOnFocus: args['selectAllOnFocus'] as bool?,
      selectionControls: args['selectionControls'] as TextSelectionControls?,
      onTap: args['onTap'] as void Function()?,
      onTapAlwaysCalled: args['onTapAlwaysCalled'] as bool? ?? false,
      onTapOutside: args['onTapOutside'] as void Function(PointerDownEvent)?,
      onTapUpOutside: args['onTapUpOutside'] as void Function(PointerUpEvent)?,
      mouseCursor: args['mouseCursor'] as MouseCursor?,
      buildCounter:
          args['buildCounter']
              as Widget? Function(
                BuildContext, {
                required int currentLength,
                required bool isFocused,
                required int? maxLength,
              })?,
      scrollController: args['scrollController'] as ScrollController?,
      scrollPhysics: args['scrollPhysics'] as ScrollPhysics?,
      autofillHints:
          args['autofillHints'] as Iterable<String>? ?? const <String>[],
      contentInsertionConfiguration:
          args['contentInsertionConfiguration']
              as ContentInsertionConfiguration?,
      clipBehavior: args['clipBehavior'] as Clip? ?? Clip.hardEdge,
      restorationId: args['restorationId'] as String?,
      scribbleEnabled: args['scribbleEnabled'] as bool? ?? true,
      stylusHandwritingEnabled:
          args['stylusHandwritingEnabled'] as bool? ??
          EditableText.defaultStylusHandwritingEnabled,
      enableIMEPersonalizedLearning:
          args['enableIMEPersonalizedLearning'] as bool? ?? true,
      contextMenuBuilder:
          args['contextMenuBuilder']
              as Widget Function(BuildContext, EditableTextState)? ??
          _defaultContextMenuBuilder,
      canRequestFocus: args['canRequestFocus'] as bool? ?? true,
      spellCheckConfiguration:
          args['spellCheckConfiguration'] as SpellCheckConfiguration?,
      magnifierConfiguration:
          args['magnifierConfiguration'] as TextMagnifierConfiguration?,
      hintLocales: args['hintLocales'] as List<Locale>?,
    ),
  );
}
