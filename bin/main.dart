import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:args/args.dart';

const usage = '''
rewatcher: watch a path and rerun on changes

Usage: rewatcher [-w some/path] [-w some/other/path] [-r "executable with args"]
''';

main(List<String> args) async {
  if (!FileSystemEntity.isWatchSupported) {
    print('Watching not supported for this system. Sorry :(');
    return;
  }

  if (args.isEmpty) {
    print(usage);
    return;
  }

  final parser = new ArgParser(allowTrailingOptions: true)
  ..addOption('watch', abbr: 'w', allowMultiple: true, defaultsTo: Directory.current.path)
  ..addOption('run', abbr: 'r');

  final result = parser.parse(args);

  if (result['run'] == null) {
    print(usage);
    return;
  }

  final watchPaths = result['watch'];
  final run = result['run'].split(' ') as List<String>;

  final programExec = run.first;
  final programArgs = run.skip(1).toList();

  Process process;

  print('Running "${result['run']}"');
  process = await runProgram(programExec, programArgs);

  for (final path in watchPaths) {
    try {
      print('Watching $path');
      final watcher = await createWatcher(path);
      watcher.listen((event) async {
        logWatchOutput(event);
        if (process != null) {
          process.kill();
          process = null;
          process = await runProgram(programExec, programArgs);
        }
      });
    } catch(err) {
      print(err);
      return;
    }
  }
}

Future<Process> runProgram(String program, List<String> arguments) async {
  return await Process.start(program, arguments, runInShell: true)
    ..stdout.transform(UTF8.decoder).listen(print)
    ..stderr.transform(UTF8.decoder).listen(print);
}

Future<Stream<FileSystemEvent>> createWatcher(String path) async {
  if (await FileSystemEntity.isFile(path)) {
    if (!Platform.isWindows) {
      throw "Couldn't watch $path: Watching files isn't supported on this system. Sorry :(";
    } else {
      return new File(path).watch(recursive: true);
    }
  } else if (await FileSystemEntity.isDirectory(path)) {
    return new Directory(path).watch(recursive: true);
  } else {
    throw '$path must be a file or a directory.';
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
