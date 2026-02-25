import 'file_service_interface.dart';
import 'file_service_web.dart'
    if (dart.library.io) 'file_service_mobile.dart';

class FileService implements FileServiceInterface {
  final FileServiceInterface _impl = createFileService();

  @override
  Future<void> downloadJson(String jsonString, String filename) =>
      _impl.downloadJson(jsonString, filename);

  @override
  Future<String?> pickAndReadJsonFile() => _impl.pickAndReadJsonFile();

  @override
  Future<void> downloadCsv(String csvString, String filename) =>
      _impl.downloadCsv(csvString, filename);

  @override
  Future<String?> pickAndReadCsvFile() => _impl.pickAndReadCsvFile();
}
