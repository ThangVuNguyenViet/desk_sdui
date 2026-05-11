import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';

part 'chef_view.sdui.g.dart';

extension type ChefView(Map<String, Object?> raw) {
  String get headline => raw['headline'] as String;
}

@Screen('chef_view')
Widget chefView(ChefView data) => Text(data.headline);
