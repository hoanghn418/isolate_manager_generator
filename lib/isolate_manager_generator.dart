import 'dart:io';

import 'package:args/args.dart';
import 'package:isolate_manager/isolate_manager.dart';
import 'package:isolate_manager_generator/src/model/exceptions.dart';
import 'package:path/path.dart';

import 'src/generate_shared.dart' as shared;
import 'src/generate_single.dart' as single;

class IsolateManagerGenerator {
  /// Executes the isolate manager generator with the provided arguments.
  ///
  /// Takes a list of command-line arguments, processes them, and generates
  /// the appropriate worker files based on the configuration.
  ///
  /// Returns:
  ///   0: Success
  ///   1: Compilation error
  ///   2: Unable to resolve file
  ///   3: No main function found
  ///   4: Main function has no open braces
  ///   5: File not found
  static Future<int> execute(List<String> args) async {
    try {
      await _execute(args);
    } on IMGException catch (e) {
      print(e.message);
      switch (e) {
        case IMGCompileErrorException():
          return 1;
        case IMGUnableToResolvingFileException():
          return 2;
        case IMGNoMainFunctionFoundException():
          return 3;
        case IMGMainFunctionHasNoOpenBracesException():
          return 4;
        case IMGFileNotFoundException():
          return 5;
      }
    }
    return 0;
  }

  static Future<void> _execute(List<String> args) async {
    final separator = args.indexOf(' -- ');
    List<String> dartArgs = [];
    if (separator != -1) {
      dartArgs = args.sublist(separator + 1);
      args = args.sublist(0, separator);
    }

    final parser = ArgParser()
      ..addFlag(
        'single',
        defaultsTo: false,
        help: 'Generate the single Workers',
      )
      ..addFlag(
        'shared',
        defaultsTo: false,
        help: 'Generate the shared Workers',
      )
      ..addOption(
        'input',
        abbr: 'i',
        help: 'Path of the folder to generate the Workers',
        valueHelp: 'lib',
        defaultsTo: 'lib',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Path of the folder to save the generated files',
        valueHelp: 'web',
        defaultsTo: 'web',
      )
      ..addOption('shared-name',
          valueHelp: kSharedWorkerName,
          defaultsTo: kSharedWorkerName,
          help: 'Name of the generated shared Worker',
          aliases: ['name'])
      ..addOption(
        'obfuscate',
        valueHelp: '4',
        defaultsTo: '4',
        help: 'JS obfuscation level (0 to 4)',
      )
      ..addFlag(
        'debug',
        defaultsTo: false,
        help:
            'Export the debug files like *.js.deps, *.js.map and *.unopt.wasm',
      )
      ..addFlag(
        'wasm',
        defaultsTo: false,
        help: 'Compile to wasm',
      )
      ..addOption(
        'worker-mappings-experiment',
        defaultsTo: '',
        help:
            '[Experiment] Generate the `workerMappings` and add it to the `main` app automatically',
      )
      ..addFlag('help', abbr: 'h', help: 'Display this help message.')
      ..addOption(
        'sub-path',
        help:
            'Sub-path of the function name when generate the worker-mappings (apply only for the single functions). It\'s different from the `output` path.',
        defaultsTo: '',
        aliases: ['sub-dir'],
      );

    final argResults = parser.parse(args);

    if (argResults['help'] as bool) {
      print(parser.usage);
      return;
    }

    bool isSingle = argResults['single'] as bool;
    bool isShared = argResults['shared'] as bool;

    if (!isSingle && !isShared) {
      isSingle = true;
      isShared = true;
    }

    final input = argResults['input'] as String;
    final dir = Directory(input);
    if (!dir.existsSync()) {
      print('The command run in the wrong directory.');
      return;
    }

    final List<File> dartFiles = listDartFiles(Directory(input), []);

    if (isSingle) {
      print('>> Generating the single Workers...');
      await single.generate(argResults, dartArgs, dartFiles);
      print('>> Generated.');
    }

    if (isShared) {
      print('>> Generating the shared Worker...');
      await shared.generate(argResults, dartArgs, dartFiles);
      print('>> Generated.');
    }
  }

  static List<File> listDartFiles(
    Directory dir,
    List<File> fileList,
  ) {
    final files = dir.listSync(recursive: false);

    for (FileSystemEntity file in files) {
      if (file is File && extension(file.path) == '.dart') {
        fileList.add(file);
      } else if (file is Directory) {
        fileList = listDartFiles(file, fileList);
      }
    }

    return fileList;
  }
}
