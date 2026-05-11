/// Curated `const List<Type>` bundles for use with `@RegisterForSdui`.
///
/// ```dart
/// import 'package:desk_sdui/widget_bundles.dart';
/// import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
///
/// @RegisterForSdui([
///   ...kCommonWidgets,
///   ...kCommonMaterialWidgets,
///   MyCustomButton,
/// ])
/// class _Registrations {}
/// ```
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Stable, framework-agnostic widgets from `package:flutter/widgets.dart`.
const List<Type> kCommonWidgets = <Type>[
  Align, AspectRatio, Center, Column, ConstrainedBox, Container,
  Expanded, FittedBox, Flexible, IntrinsicHeight, IntrinsicWidth, Padding,
  Positioned, Row, SafeArea, SizedBox, Spacer, Stack, Wrap,
  ListView, SingleChildScrollView,
  ClipOval, ClipRRect, ClipRect, DecoratedBox, Icon, Image, Opacity,
  RotatedBox, Text, Transform,
  GestureDetector, InkWell,
  Builder, Divider, Visibility,
];

/// Material design widgets from `package:flutter/material.dart`.
///
/// Note: [AppBar], [FloatingActionButton], [Scaffold], and [TextField] are
/// excluded because their constructors reference private Flutter framework
/// symbols (e.g. `_DefaultHeroTag`, `_defaultContextMenuBuilder`) that cannot
/// be emitted in generated code. Add them to your `@RegisterForSdui` list only
/// if the desk_sdui codegen correctly handles their constructors in your
/// Flutter SDK version.
const List<Type> kCommonMaterialWidgets = <Type>[
  Card, Chip, CircularProgressIndicator, Drawer,
  ElevatedButton, FilledButton, IconButton,
  LinearProgressIndicator, ListTile, OutlinedButton,
  Switch, TextButton,
];

/// Cupertino design widgets from `package:flutter/cupertino.dart`.
const List<Type> kCommonCupertinoWidgets = <Type>[
  CupertinoActivityIndicator, CupertinoButton, CupertinoNavigationBar,
  CupertinoPageScaffold, CupertinoSwitch, CupertinoTextField,
];
