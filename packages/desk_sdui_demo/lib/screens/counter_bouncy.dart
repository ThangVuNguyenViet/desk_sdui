import 'package:cue/cue.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui_demo/screens/counter_minimal.dart' show CounterData;
import 'package:flutter/material.dart';

@Screen('counter_bouncy')
Widget counterBouncy(CounterData data) => Center(
      child: Cue.onChange(
        value: data.value,
        motion: const CueMotion.bouncy(),
        acts: const [
          Act.scale(from: 0.6),
          Act.fadeIn(),
        ],
        child: Text(
          '${data.value}',
          style: const TextStyle(fontSize: 128, fontWeight: FontWeight.w900),
        ),
      ),
    );
