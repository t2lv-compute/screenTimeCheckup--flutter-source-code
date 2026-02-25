import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'file_service_interface.dart';

class FileServiceImpl implements FileServiceInterface {
  @override
  Future<void> downloadJson(String jsonString, String filename) async {
    final bytes = utf8.encode(jsonString);
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/json'),
    );

    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = filename;
    anchor.click();
    web.URL.revokeObjectURL(url);
  }

  @override
  Future<String?> pickAndReadJsonFile() async {
    final completer = Completer<String?>();

    final input = web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    input.accept = '.json,.stc';

    input.addEventListener(
      'change',
      ((web.Event event) {
        final files = input.files;
        if (files != null && files.length > 0) {
          final file = files.item(0);
          if (file != null) {
            final reader = web.FileReader();
            reader.addEventListener(
              'load',
              ((web.Event e) {
                final result = reader.result;
                if (result != null) {
                  completer.complete((result as JSString).toDart);
                } else {
                  completer.complete(null);
                }
              }).toJS,
            );
            reader.readAsText(file);
          } else {
            completer.complete(null);
          }
        } else {
          completer.complete(null);
        }
      }).toJS,
    );

    input.click();
    return completer.future;
  }

  @override
  Future<void> downloadCsv(String csvString, String filename) async {
    final bytes = utf8.encode(csvString);
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'text/csv'),
    );

    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = filename;
    anchor.click();
    web.URL.revokeObjectURL(url);
  }

  @override
  Future<String?> pickAndReadCsvFile() async {
    final completer = Completer<String?>();

    final input = web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    input.accept = '.csv';

    input.addEventListener(
      'change',
      ((web.Event event) {
        final files = input.files;
        if (files != null && files.length > 0) {
          final file = files.item(0);
          if (file != null) {
            final reader = web.FileReader();
            reader.addEventListener(
              'load',
              ((web.Event e) {
                final result = reader.result;
                if (result != null) {
                  completer.complete((result as JSString).toDart);
                } else {
                  completer.complete(null);
                }
              }).toJS,
            );
            reader.readAsText(file);
          } else {
            completer.complete(null);
          }
        } else {
          completer.complete(null);
        }
      }).toJS,
    );

    input.click();
    return completer.future;
  }
}

FileServiceInterface createFileService() => FileServiceImpl();
