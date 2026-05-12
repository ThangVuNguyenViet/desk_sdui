// ignore_for_file: lines_longer_than_80_chars
//
// cost_demo.dart — demo screen for the cost-classifier feature.
//
// This file intentionally contains functions with different cost classes so
// that the cost classifier can be demonstrated / validated manually.
//
// Expected diagnostics (once a call-site-tracking pass is wired into codegen):
//   - sumPositives called in build → info: "sumPositives" is O(N) in its arg.
//   - label called in build        → silent (pureBounded).
//
import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/material.dart';

part 'cost_demo.sdui.g.dart';

// Pure-bounded — silent everywhere.
String label(int n) {
  return 'count: $n';
}

// Linear-in-arg — info in build, silent in action.
// The classifier detects the for-loop over the `items` parameter.
int sumPositives(List<int> items) {
  var s = 0;
  for (var i = 0; i < items.length; i++) {
    if (items[i] > 0) {
      s = s + items[i];
    }
  }
  return s;
}

// ignore: sdui_potential_cost.linear_in_build (silenced intentionally)
class CostController {
  final List<int> nums = const [1, -2, 3, -4, 5];
}

@Screen('cost_demo')
Widget costDemo(CostController vm) {
  // EXPECTED (future): 1 info diagnostic on the line below:
  //   "sumPositives is O(N) in its arg. Called per frame in build."
  return Column(children: [
    Text(label(sumPositives(vm.nums))),
  ]);
}
