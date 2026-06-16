// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

/// Triggers a browser download of [content] as [filename] (web only).
void downloadText(String filename, String content,
    {String mime = 'text/csv;charset=utf-8'}) {
  downloadBytes(filename, utf8.encode(content), mime: mime);
}

/// Triggers a browser download of raw [bytes] as [filename] (web only).
/// Used for binary files such as PDFs, without any platform plugin.
void downloadBytes(String filename, List<int> bytes,
    {String mime = 'application/octet-stream'}) {
  final blob = html.Blob(<dynamic>[bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)..download = filename;
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
