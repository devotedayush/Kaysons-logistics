import 'dart:convert';

import 'package:file_picker/file_picker.dart';

Future<void> downloadFile(
  String fileName,
  String content,
  String mimeType,
) async {
  await FilePicker.saveFile(
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: [fileName.split('.').last],
    bytes: utf8.encode(content),
  );
}

Future<void> downloadCsv(String fileName, String csvContent) {
  return downloadFile(fileName, csvContent, 'text/csv;charset=utf-8');
}
