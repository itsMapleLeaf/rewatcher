import 'dart:io';
import 'dart:convert';

import 'package:args/args.dart';

main(List<String> args) async {
  final parser = new ArgParser(allowTrailingOptions: true)
  ..addOption('watch', abbr: 'w', allowMultiple: true);

  final result = parser.parse(args);

  final watchPaths = result['watch'];
  final program = result.rest.first;
  final arguments = result.rest.sublist(1);

  Process process;

  print('Running "$program ${arguments.join(' ')}"');
  process = await runProgram(program, arguments);

  watcher(FileSystemEvent event) async {
    if (event is FileSystemCreateEvent) {
      print('Created: ${event.path}');
    } else if (event is FileSystemModifyEvent) {
      print('Modified: ${event.path}');
    } else if (event is FileSystemDeleteEvent) {
      print('Deleted: ${event.path}');
    } else if (event is FileSystemMoveEvent) {
      print('Moved: ${event.path} -> ${event.destination}');
    }

    if (process != null) {
      process.kill();
      process = null;
      process = await runProgram(program, arguments);
    }
  }

  for (final path in watchPaths) {
    if (await FileSystemEntity.isFile(path)) {
      if (!Platform.isWindows) {
        new File(path).watch(recursive: true).listen(watcher);
      }
    } else if (await FileSystemEntity.isDirectory(path)) {
      new Directory(path).watch(recursive: true).listen(watcher);
    }
  }
}

runProgram(String program, List<String> arguments) async {
  return await Process.start(program, arguments)
    ..stdout.transform(UTF8.decoder).listen(print)
    ..stderr.transform(UTF8.decoder).listen(print);
}
