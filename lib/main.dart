import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.light, // Ensures it's for light mode
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark, // Ensures it's for dark mode
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MyHomePage(title: 'PipePipe 2 NewPipe'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _dbFile;
  Directory? _extractedDir;
  String _selectMessage = "";
  String _convertMessage = "";
  String _saveMessage = "";

  Future<void> _selectZipFile() async {
    String message = "";
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _extractedDir = Directory("${tempDir.path}/extracted-$timestamp");
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
          final bytes = await zipFile!.readAsBytes();
          final archive = ZipDecoder().decodeBytes(bytes);
          if (_extractedDir!.existsSync()) _extractedDir!.deleteSync(recursive: true);
          _extractedDir!.createSync(recursive: true);

          File? dbFile;

          for (final file in archive.files) {
            if (!file.isFile) continue;
            final filePath = '${_extractedDir!.path}/${file.name}';
            File(filePath).writeAsBytesSync(file.content as List<int>);

            if (file.name == 'newpipe.db') {
              dbFile = File(filePath);
            }
          }

          if (dbFile != null) {
            _dbFile = dbFile;
          } else {
            message = "newpipe.db not found in the zip!";
          }
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
      _selectMessage = message;
    });
  }

  Future<void> _convertZipFile() async {
    String message = "";
    if (_dbFile != null) {
      try {
        var db = await openDatabase(_dbFile!.path);
        await db.transaction((txn) async {
          await txn.execute('ALTER TABLE playlists RENAME COLUMN display_index TO is_thumbnail_permanent');
          await txn.execute('UPDATE playlists SET is_thumbnail_permanent = 0');
          await txn.execute('ALTER TABLE remote_playlists DROP COLUMN display_index');
        });
        await db.close();
        message = "Conversion successfull!";
      } catch (e) {
        print(e);
        message = "Sorry, an error occurred!";
      }
    }

    setState(() {
      _convertMessage = message;
    });
  }

  Future<void> _saveFile() async {
    print("ZZZZ");
    if (_extractedDir == null) return;
    print("XXXX");

    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory == null) {
        final Directory? tempDir = await getTemporaryDirectory();
        selectedDirectory = tempDir?.path;
      }
      final zipFile = File("${selectedDirectory}/NewPipe.zip");
      final newArchive = Archive();

      for (final file in _extractedDir!.listSync(recursive: true)) {
        if (file is File) {
          final filename = p.basename(file.path);
          final fileBytes = await file.readAsBytes();
          newArchive.addFile(ArchiveFile(filename, fileBytes.length, fileBytes));
        }
      }

      final newZipBytes = ZipEncoder().encode(newArchive);
      final result = await zipFile.writeAsBytes(newZipBytes!);
      print(result);

      print("Archive created at: ${selectedDirectory}/NewPipe.zip");
    } catch (e) {
      print("Error creating archive: $e");
    }
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
            ElevatedButton(
              onPressed: _selectZipFile,
              child: Text("Select Zip File"),
            ),
            SizedBox(height: 8),
            Text(_selectMessage),

            SizedBox(height: 16),

            ElevatedButton(
              onPressed: _convertZipFile,
              child: Text("Convert Zip File"),
            ),
            SizedBox(height: 8),
            Text(_convertMessage),

            SizedBox(height: 16),

            ElevatedButton(
              onPressed: _saveFile,
              child: Text("Save File"),
            ),
            SizedBox(height: 8),
            Text(_saveMessage),
          ],
        ),
      ),
    );
  }
}
