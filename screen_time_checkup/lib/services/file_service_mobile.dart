import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'file_service_interface.dart';

class FileServiceImpl implements FileServiceInterface {
  @override
  Future<void> downloadJson(String jsonString, String filename) async {
    // Save to temp directory first
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsString(jsonString);

    // Open share sheet so user can save/share the file
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Screen Time Checkup Backup',
      ),
    );
  }

  @override
  Future<String?> pickAndReadJsonFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'stc'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      return await file.readAsString();
    }
    return null;
  }

  @override
  Future<void> downloadCsv(String csvString, String filename) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsString(csvString);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Screen Time Checkup CSV Export',
      ),
    );
  }

  @override
  Future<String?> pickAndReadCsvFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      return await file.readAsString();
    }
    return null;
  }
}

FileServiceInterface createFileService() => FileServiceImpl();
