// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

final Set<String> _registered = {};

/// Converts common watch URLs into embeddable player URLs.
String _embedUrl(String url) {
  final yt = RegExp(r'(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([\w-]{11})')
      .firstMatch(url);
  if (yt != null) return 'https://www.youtube.com/embed/${yt.group(1)}';
  final vimeo = RegExp(r'vimeo\.com/(?:video/)?(\d+)').firstMatch(url);
  if (vimeo != null) return 'https://player.vimeo.com/video/${vimeo.group(1)}';
  return url;
}

/// An embedded video player (iframe) for the given URL. Web only.
Widget webVideo(String url) {
  final embed = _embedUrl(url);
  final viewType = 'video-${embed.hashCode}';
  if (!_registered.contains(viewType)) {
    _registered.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final iframe = html.IFrameElement()
        ..src = embed
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;
      return iframe;
    });
  }
  return HtmlElementView(viewType: viewType);
}
