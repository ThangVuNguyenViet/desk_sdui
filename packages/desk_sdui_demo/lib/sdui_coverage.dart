import 'package:cue/cue.dart';
import 'package:desk_sdui/widget_bundles.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';

@RegisterForSdui([
  ...kCommonWidgets,
  ...kCommonMaterialWidgets,
  PageView,
  Cue,
  Act,
  CueMotion,
])
class SduiCoverage {}
