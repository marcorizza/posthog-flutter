import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posthog_flutter/src/replay/screenshot/screenshot_capturer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native window crop replaces the opaque Flutter fallback', () async {
    final nativeImage = await _twoLayerImage();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Flutter's platform-view fallback can be opaque rather than transparent.
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 2, 2),
      Paint()..color = const Color.fromARGB(255, 255, 255, 255),
    );

    // The native crop already contains the real window z-order: a red Flutter
    // overlay in the top row and the blue platform view below it.
    drawCapturedPlatformView(
      canvas,
      nativeImage,
      const Rect.fromLTWH(0, 0, 2, 2),
    );

    final composed = await recorder.endRecording().toImage(2, 2);
    final bytes = await composed.toByteData(format: ui.ImageByteFormat.rawRgba);
    final pixels = bytes!.buffer.asUint8List();

    // Both the overlay and the platform view replace the opaque fallback.
    expect(_pixelAt(pixels, width: 2, x: 0, y: 0), [255, 0, 0, 255]);
    expect(_pixelAt(pixels, width: 2, x: 1, y: 0), [255, 0, 0, 255]);
    expect(_pixelAt(pixels, width: 2, x: 0, y: 1), [0, 0, 255, 255]);
    expect(_pixelAt(pixels, width: 2, x: 1, y: 1), [0, 0, 255, 255]);

    nativeImage.dispose();
    composed.dispose();
  });
}

Future<ui.Image> _twoLayerImage() {
  const width = 2;
  const height = 2;
  final pixels = Uint8List(width * height * 4);
  for (var offset = 0; offset < pixels.length; offset += 4) {
    final isOverlayRow = offset < width * 4;
    pixels[offset] = isOverlayRow ? 255 : 0;
    pixels[offset + 1] = 0;
    pixels[offset + 2] = isOverlayRow ? 0 : 255;
    pixels[offset + 3] = 255;
  }

  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

List<int> _pixelAt(
  Uint8List pixels, {
  required int width,
  required int x,
  required int y,
}) {
  final offset = (y * width + x) * 4;
  return pixels.sublist(offset, offset + 4);
}
