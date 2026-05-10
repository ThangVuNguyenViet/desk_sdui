/// Codegen for desk_sdui.
library;

import 'package:build/build.dart';
import 'src/builders.dart' as impl;

Builder screenBuilder(BuilderOptions options) => impl.screenBuilder(options);
Builder registryBuilder(BuilderOptions options) => impl.registryBuilder(options);
