import 'package:cue/cue.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/material.dart';

class HeroData {
  const HeroData({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
}

@Screen('hero')
Widget hero(HeroData data) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Cue.onMount(
          motion: const CueMotion.smooth(),
          acts: const [
            Act.fadeIn(),
            Act.slideY(from: 0.2),
          ],
          child: Text(
            data.title,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 16),
        Cue.onMount(
          motion: const CueMotion.smooth(),
          acts: const [
            Act.fadeIn(),
            Act.slideY(from: 0.4),
          ],
          child: Text(
            data.subtitle,
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ),
      ],
    ),
  );
}
