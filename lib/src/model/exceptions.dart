sealed class IMGException implements Exception {
  final String message;

  const IMGException(this.message);

  @override
  String toString() => 'IsolateManagerGeneratorException: $message';
}

class IMGCompileErrorException extends IMGException {
  const IMGCompileErrorException() : super('Compile error');
}

class IMGUnableToResolvingFileException extends IMGException {
  const IMGUnableToResolvingFileException(String filePath)
      : super('Unable to resolving file: $filePath');
}

class IMGNoMainFunctionFoundException extends IMGException {
  const IMGNoMainFunctionFoundException()
      : super('No main function found in the source file.');
}

class IMGMainFunctionHasNoOpenBracesException extends IMGException {
  const IMGMainFunctionHasNoOpenBracesException()
      : super('Malformed main function, no opening brace found.');
}

class IMGFileNotFoundException extends IMGException {
  const IMGFileNotFoundException(String filePath)
      : super('File not found: $filePath');
}
