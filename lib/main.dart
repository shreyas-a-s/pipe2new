import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PipePipe 2 NewPipe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      ),
      home: const MyHomePage(title: 'PipePipe 2 NewPipe'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _message = "Select zip file exported from PipePipe";

  Future<void> _createArchiveFromDirectory(Directory sourceDir, String fileName) async {
    try {
      final Directory? downloadsDir = await getDownloadsDirectory();
      final zipFilePath = "${downloadsDir?.path}/$fileName.zip";
      final zipFile = File(zipFilePath);

      ZipFile.createFromDirectory(
        sourceDir: sourceDir,
        zipFile: zipFile,
        recurseSubDirs: false
      );

      print("Archive created at: $zipFilePath");
    } catch (e) {
      print("Error creating archive: $e");
    }
  }

  Future<void> _alterDatabase(String dbFile) async {
    try {
      var db = await openDatabase(dbFile);
      await db.transaction((txn) async {
        await txn.execute('ALTER TABLE playlists RENAME COLUMN display_index TO is_thumbnail_permanent');
        await txn.execute('UPDATE playlist SET is_thumbnail_permanent = 0');
        await txn.execute('ALTER TABLE remote_playlists DROP COLUMN display_index');
      });
      await db.close();
    } catch (e) {
      print(e);
    }
  }

  void _addZipFile() async {
    String message = "";
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final destinationDir = Directory("${tempDir.path}/extracted-$timestamp");
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result != null) {
      if (result.files.single.extension == 'zip') {
        File zipFile = File(result.files.single.path!);
        print(result.files.single.name);
        message = 'Selected file is: ${result.files.single.name}';

        try {
          await ZipFile.extractToDirectory(
            zipFile: zipFile,
            destinationDir: destinationDir,
            onExtracting: (zipEntry, progress) {
              return ZipFileOperation.includeItem;
            }
          );

          await for (var entity in
              destinationDir.list(recursive: true, followLinks: false)) {
            print(entity.path);
          }

          final dbFile = "$destinationDir/newpipe.db";
          await _alterDatabase(dbFile);
          await _createArchiveFromDirectory(destinationDir, "NewPipe");
        } catch (e) {
          print(e);
        }
      } else {
        message = "You have selected ${result.files.single.extension}. Only zip files are allowed";
      }
    } else {
      message = "No file selected";
    }

    setState(() {
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              '$_message'
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addZipFile,
        tooltip: 'Add PipePipe zip file',
        child: const Icon(Icons.add),
      ),
    );
  }
}
