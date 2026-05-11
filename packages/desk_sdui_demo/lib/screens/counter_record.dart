import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/material.dart';

part 'counter_record.sdui.g.dart';

@Screen('counter_record')
Widget counterRecord(({int value}) data) => Center(
      child: Text(
        '${data.value}',
        style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w800),
      ),
    );
