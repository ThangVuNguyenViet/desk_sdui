import 'package:flutter/material.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
extension type ChefView(Map<String, Object?> raw) {
  String get headline => raw['headline'] as String;
}
@Screen('chef_view')
Widget chefView(ChefView data) => Text(data.headline);
