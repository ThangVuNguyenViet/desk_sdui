import 'package:cue/cue.dart';
import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui_demo/screens/counter_minimal.dart' show CounterData;
import 'package:flutter/material.dart';

part 'counter_stress.sdui.g.dart';

@Screen('counter_stress')
Widget counterStress(CounterData data) => Stack(
      alignment: Alignment.center,
      children: [
        for (final _ in data.chips)
          Cue.onMount(
            motion: const CueMotion.smooth(),
            acts: const [
              Act.fadeIn(),
              Act.slideY(from: 0.2),
              Act.scale(from: 0.4),
              Act.rotate(to: 360),
            ],
            child: const Icon(Icons.circle, size: 10, color: Colors.deepPurple),
          ),
        Cue.onChange(
          value: data.value,
          motion: const CueMotion.bouncy(),
          acts: const [Act.scale(from: 0.6)],
          child: Text(
            '${data.value}',
            style: const TextStyle(fontSize: 144, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
