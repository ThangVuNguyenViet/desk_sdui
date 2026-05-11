part of 'package:desk_sdui_demo/screens/chef_view.dart';

ScreenBinding get chef_viewBinding => ScreenBinding(
  name: 'chef_view',
  ir: IrTree(
    name: 'chef_view',
    version: 1,
    root: WidgetNode(
      name: 'Text',
      args: {
        'data': RefNode(['data', 'headline']),
      },
    ),
  ),
  inputs: [InputBinding(name: 'data', read: (v) => v as dynamic)],
  methodRefs: const {},
  reactives: const [],
);
