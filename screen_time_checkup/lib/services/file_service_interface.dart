abstract class FileServiceInterface {
  Future<void> downloadJson(String jsonString, String filename);
  Future<String?> pickAndReadJsonFile();
  Future<void> downloadCsv(String csvString, String filename);
  Future<String?> pickAndReadCsvFile();
}
