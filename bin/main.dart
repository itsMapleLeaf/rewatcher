import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:args/args.dart';

main(List<String> args) async {
  if (!FileSystemEntity.isWatchSupported) {
    print('Watching not supported for this system. Sorry :(');
    return;
  }

  final parser = new ArgParser(allowTrailingOptions: true)
  ..addOption('watch', abbr: 'w', allowMultiple: true);

  final result = parser.parse(args);

  final watchPaths = result['watch'];
  final program = result.rest.first;
  final arguments = result.rest.sublist(1);

  Process process;

  print('Running "$program ${arguments.join(' ')}"');
  process = await runProgram(program, arguments);

  for (final path in watchPaths) {
    try {
      print('Watching $path');
      final watcher = await createWatcher(path);
      watcher.listen((event) async {
        logWatchOutput(event);
        if (process != null) {
          process.kill();
          process = null;
          process = await runProgram(program, arguments);
        }
      });
    } catch(err) {
      print(err);
      return;
    }
  }
}

Future<Process> runProgram(String program, List<String> arguments) async {
  return await Process.start(program, arguments)
    ..stdout.transform(UTF8.decoder).listen(print)
    ..stderr.transform(UTF8.decoder).listen(print);
}

Future<Stream<FileSystemEvent>> createWatcher(String path) async {
  if (await FileSystemEntity.isFile(path)) {
    if (!Platform.isWindows) {
      throw "Couldn't watch $path: Watching files isn't supported on this system. Sorry :(";
    } else {
      return new File(path).watch();
    }
  } else if (await FileSystemEntity.isDirectory(path)) {
    return new Directory(path).watch();
  } else {
    throw "$path must be a file or a directory.";
  }
}

void logWatchOutput(FileSystemEvent event) {
  if (event is FileSystemCreateEvent) {
    print('Created: ${event.path}');
  } else if (event is FileSystemModifyEvent) {
    print('Modified: ${event.path}');
  } else if (event is FileSystemDeleteEvent) {
    print('Deleted: ${event.path}');
  } else if (event is FileSystemMoveEvent) {
    print('Moved: ${event.path} -> ${event.destination}');
  }
}
