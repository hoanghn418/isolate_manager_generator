import 'dart:io';

import 'package:path/path.dart' as p;

void printDebug(Object? Function() log) {
  print(log());
}

/// Reads the content of a file and returns it as a list of lines
Future<List<String>> readFileLines(String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    printDebug(() => 'File does not exist: $path');
    return [];
  }
  return await file.readAsLines();
}

/// Writes content to a file
Future<void> writeFile(String path, List<String> content) async {
  final file = File(path);
  await file.writeAsString('${content.join('\n')}\n');
}

/// Adds import statements to content if they don't already exist
List<String> addImportStatements(
  List<String> content,
  String sourceFilePath,
  String mainPath,
) {
  var result = List<String>.from(content);
  var lastImportIndex = -1;
  for (var i = 0; i < result.length; i++) {
    if (result[i].startsWith('import ')) {
      lastImportIndex = i;
    }
  }

  const newImportLine =
      "import 'package:isolate_manager/isolate_manager.dart';";
  if (!result.contains(newImportLine)) {
    result.insert(++lastImportIndex, newImportLine);
  }

  final newFunctionSourceImport = p.relative(sourceFilePath, from: 'lib');
  final newFunctionSourceImportRelativeFromMain =
      p.relative(sourceFilePath, from: p.dirname(mainPath));

  // Convert paths to use forward slashes for import statements
  final platformIndependentSourceImport =
      newFunctionSourceImport.replaceAll(p.separator, '/');
  final platformIndependentSourceImportRelative =
      newFunctionSourceImportRelativeFromMain.replaceAll(p.separator, '/');

  final containsSourceImport =
      result.any((line) => line.contains(platformIndependentSourceImport));
  final containsSourceImportRelativeFromMain = result
      .any((line) => line.contains(platformIndependentSourceImportRelative));

  if (p.absolute(sourceFilePath) != mainPath &&
      !containsSourceImport &&
      !containsSourceImportRelativeFromMain) {
    result.insert(++lastImportIndex,
        "import '$platformIndependentSourceImportRelative';");
  }

  return result;
}

/// Adds the worker mappings call to the main function
List<String> addWorkerMappingsCall(List<String> content) {
  var result = List<String>.from(content);
  var mainIndex = -1;
  for (var i = 0; i < result.length; i++) {
    if (result[i].contains('void main(') ||
        result[i].contains('Future<void> main(')) {
      mainIndex = i;
      break;
    }
  }

  if (mainIndex == -1) {
    printDebug(() => 'No main function found in the source file.');
    return result;
  }

  var insertionIndex = mainIndex;
  while (insertionIndex < result.length &&
      !result[insertionIndex].trim().endsWith('{')) {
    insertionIndex++;
  }

  if (insertionIndex == result.length) {
    printDebug(() => 'Malformed main function, no opening brace found.');
    return result;
  }

  const addWorkerMappingsCall = '  _addWorkerMappings();';
  if (!result.any((line) => line.contains('_addWorkerMappings();'))) {
    result.insert(insertionIndex + 1, addWorkerMappingsCall);
  }

  return result;
}

/// Adds or updates the _addWorkerMappings function
List<String> addOrUpdateWorkerMappingsFunction(
  List<String> content,
  String functionName,
  String subDir,
) {
  var result = List<String>.from(content);
  // We don't need to set the right separator here, the `IsolateManager.addWorkerMapping`
  // method will handle it.
  final functionPath = '$subDir/$functionName';
  final newWorkerMappingLine =
      "  IsolateManager.addWorkerMapping($functionName, '$functionPath');";

  final addWorkerMappingsIndex = result.indexWhere((line) =>
      line.replaceAll(' ', '').startsWith('void_addWorkerMappings()'));

  if (addWorkerMappingsIndex == -1) {
    // Add new function
    result
      ..add('')
      ..add('/// This method MUST be stored at the end of the file to avoid')
      ..add('/// issues when generating.')
      ..add('void _addWorkerMappings() {')
      ..add(newWorkerMappingLine)
      ..add('}')
      ..add('');
  } else {
    // Update existing function
    final containsFunctionPath = result.any(
        (line) => line.contains(RegExp('(\'$functionPath\'|"$functionPath")')));

    if (!containsFunctionPath) {
      final line = result[addWorkerMappingsIndex].replaceAll(' ', '');
      if (line.startsWith('void_addWorkerMappings(){}')) {
        result[addWorkerMappingsIndex] = 'void _addWorkerMappings() {';
        result.insert(addWorkerMappingsIndex + 1, newWorkerMappingLine);
        result.insert(addWorkerMappingsIndex + 2, '}');
      } else {
        // Find the closing brace of the function
        int closingBraceIndex = addWorkerMappingsIndex + 1;
        while (closingBraceIndex < result.length &&
            !result[closingBraceIndex].trim().startsWith('}')) {
          closingBraceIndex++;
        }
        result.insert(closingBraceIndex, newWorkerMappingLine);
      }
    }
  }

  return result;
}

Future<void> addWorkerMappingToSourceFile(
  String workerMappingsPath,
  String sourceFilePath,
  String functionName,
  String subDir,
) async {
  final mainPath = workerMappingsPath.isNotEmpty
      ? p.absolute(workerMappingsPath)
      : p.absolute(p.join('lib', 'main.dart'));

  final content = await readFileLines(mainPath);
  if (content.isEmpty) return;

  var updatedContent = addImportStatements(content, sourceFilePath, mainPath);
  updatedContent = addWorkerMappingsCall(updatedContent);
  updatedContent =
      addOrUpdateWorkerMappingsFunction(updatedContent, functionName, subDir);

  await writeFile(mainPath, updatedContent);

  printDebug(
    () =>
        'Updated source file: $sourceFilePath with new import, worker mapping call, and addWorkerMappings function.',
  );
}
