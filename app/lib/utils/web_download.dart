// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

/// Triggers a browser download of [content] as [filename] (web only).
void downloadText(String filename, String content,
    {String mime = 'text/csv;charset=utf-8'}) {
  final bytes = utf8.encode(content);
  final blob = html.Blob(<dynamic>[bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)..download = filename;
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
