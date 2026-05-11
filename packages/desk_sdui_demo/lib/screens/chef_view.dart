import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/material.dart';

part 'chef_view.sdui.g.dart';

extension type ChefView(Map<String, Object?> raw) {
  String get headline => raw['headline'] as String;
}

@Screen('chef_view')
Widget chefView(ChefView data) {
  return Text(data.headline);
}
