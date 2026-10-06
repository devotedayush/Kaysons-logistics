// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

Future<void> downloadFile(
  String fileName,
  String content,
  String mimeType,
) async {
  final blob = html.Blob([content], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = fileName
    ..click();
  html.Url.revokeObjectUrl(url);
}

Future<void> downloadCsv(String fileName, String csvContent) {
  return downloadFile(fileName, csvContent, 'text/csv;charset=utf-8');
}
