/// Codegen for desk_sdui.
library;

import 'package:build/build.dart';
import 'src/builders.dart' as impl;

export 'src/compile_to_ir.dart' show compileToIr, CompileResult, CompileSuccess, CompileFailure, CompileError;

Builder screenBuilder(BuilderOptions options) => impl.screenBuilder(options);
Builder registryBuilder(BuilderOptions options) => impl.registryBuilder(options);
