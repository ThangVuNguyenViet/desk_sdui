import 'package:desk_sdui/desk_sdui.dart';
import 'package:desk_sdui_demo/data/fixtures.dart';
import 'package:desk_sdui_demo/desk_sdui_setup.g.dart';
import 'package:flutter/material.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  late final Runtime rt;

  @override
  void initState() {
    super.initState();
    rt = Runtime();
    registerAllScreens(rt);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'desk_sdui demo',
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('desk_sdui — chef')),
        body: SduiScreen(
          runtime: rt,
          name: 'chef',
          inputs: {
            'data': _chefDataToMap(),
            'controller': {
              'tapBack': () => debugPrint('tapBack'),
              'toggleBookmark': () => debugPrint('toggleBookmark'),
            },
          },
        ),
      ),
    );
  }
}

Map<String, Object?> _chefDataToMap() => {
      'headline': chefFixture.headline,
      'bio': chefFixture.bio,
      'pullQuote': chefFixture.pullQuote,
      'chefName': chefFixture.chefName,
      'chefRole': chefFixture.chefRole,
      'chefRoleUpper': chefFixture.chefRoleUpper,
      'chefPortraitUrl': chefFixture.chefPortraitUrl,
      'refreshCadence': chefFixture.refreshCadence,
      'dishes': chefFixture.dishes
          .map((d) => {
                'numberLabel': d.numberLabel,
                'name': d.name,
                'description': d.description,
                'price': d.price,
                'priceLabel': d.priceLabel,
                'imageUrl': d.imageUrl,
              })
          .toList(),
    };
