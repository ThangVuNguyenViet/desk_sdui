import 'package:cue/cue.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:desk_sdui_demo/screens/counter_minimal.dart' show CounterData;
import 'package:flutter/material.dart';

@Screen('counter_burst')
Widget counterBurst(CounterData data) => Stack(
      alignment: Alignment.center,
      children: [
        for (final i in data.chips)
          Cue.onMount(
            motion: const CueMotion.smooth(),
            acts: const [
              Act.fadeIn(),
              Act.slideY(from: 0.3),
              Act.scale(from: 0.5),
            ],
            child: Padding(
              padding: EdgeInsets.only(left: 6.0 * i, top: 4.0 * i),
              child: const Icon(Icons.star, size: 24, color: Colors.amber),
            ),
          ),
        Cue.onChange(
          value: data.value,
          motion: const CueMotion.bouncy(),
          acts: const [Act.scale(from: 0.7)],
          child: Text(
            '${data.value}',
            style: const TextStyle(fontSize: 128, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
