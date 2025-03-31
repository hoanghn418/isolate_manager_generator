import 'dart:io';

import 'package:isolate_manager_generator/isolate_manager_generator.dart';

void main(List<String> args) async {
  final exitCode = await IsolateManagerGenerator.execute(args);

  exit(exitCode);
}
