import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_editor/core/shader/image_exporter.dart';
import 'package:image_editor/data/model/edit_command.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Export encodes adjusted pixels and geometry, without preview UI',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xFFFF0000), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final source = await picture.toImage(8, 4);
      addTearDown(source.dispose);
      picture.dispose();
      final result = await ImageExporter.render(
        preview: source,
        state: EditState(
          adjust: const AdjustParams(enableBW: true),
          geometry: GeometryTransform(
            rotation: math.pi / 2,
            flipHorizontal: true,
          ),
        ),
      );
      expect(result.width, 4);
      expect(result.height, 8);
      final codec = await ui.instantiateImageCodec(result.png);
      final saved = (await codec.getNextFrame()).image;
      final pixels = (await saved.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      for (var i = 0; i < pixels.length; i += 4) {
        expect((pixels[i] - pixels[i + 1]).abs(), lessThanOrEqualTo(2));
        expect((pixels[i] - pixels[i + 2]).abs(), lessThanOrEqualTo(2));
        expect(pixels[i + 3], 255);
      }
      saved.dispose();
      codec.dispose();
    },
  );

  test(
    'Export reopens the original source rather than saving the preview size',
    () async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder)
          .drawColor(const ui.Color(0xFFCC8844), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final original = await picture.toImage(16, 8);
      final preview = await picture.toImage(4, 2);
      picture.dispose();
      final directory = await Directory.systemTemp.createTemp(
        'chromivelle-export-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/source.png';
      await File(path).writeAsBytes(
        (await original.toByteData(format: ui.ImageByteFormat.png))!.buffer
            .asUint8List(),
      );
      final result = await ImageExporter.render(
        preview: preview,
        sourcePath: path,
        state: const EditState(),
      );
      expect([result.width, result.height], [16, 8]);
      original.dispose();
      preview.dispose();
    },
  );

  test('Gallery receives a PNG and requires a confirmed destination', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    MethodCall? sent;
    messenger.setMockMethodCallHandler(ImageExporter.gallery, (call) async {
      sent = call;
      return 'content://media/external/images/media/123';
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(ImageExporter.gallery, null),
    );
    final image = ExportedImage(Uint8List.fromList([137, 80, 78, 71]), 1, 1);
    expect(await ImageExporter.saveToGallery(image), contains('content://'));
    expect(sent!.method, 'savePng');
    expect(sent!.arguments['bytes'], image.png);
    expect(sent!.arguments['name'], matches(r'^Chromivelle_\d+\.png$'));
    messenger.setMockMethodCallHandler(
      ImageExporter.gallery,
      (_) async => null,
    );
    await expectLater(ImageExporter.saveToGallery(image), throwsStateError);
  });
}
