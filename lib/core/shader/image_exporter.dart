import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../../data/model/edit_command.dart';
import 'adjust_uniforms.dart';
import 'preview_transform.dart';
import 'shader_registry.dart';

class ExportedImage {
  const ExportedImage(this.png, this.width, this.height);
  final Uint8List png;
  final int width, height;
}

class ImageExporter {
  static const gallery = MethodChannel('io.github.clcty.chromivelle/gallery');

  /// Bound unusually large images to avoid exhausting the mobile GPU/heap.
  static ui.Size outputSize(ui.Size input, GeometryTransform geometry) {
    final bounds = PreviewTransform.rotatedSize(input, geometry.rotation);
    final scale = math.min(
      1.0,
      math.min(
        8192 / math.max(bounds.width, bounds.height),
        math.sqrt(24000000 / (bounds.width * bounds.height)),
      ),
    );
    return ui.Size(
      math.max(1, (bounds.width * scale - 1e-6).ceil()).toDouble(),
      math.max(1, (bounds.height * scale - 1e-6).ceil()).toDouble(),
    );
  }

  static Future<ExportedImage> render({
    required ui.Image preview,
    required EditState state,
    String? sourcePath,
  }) async {
    ui.Image? decoded;
    ui.FragmentShader? shader;
    ui.Picture? picture;
    ui.Image? output;
    try {
      if (sourcePath != null) {
        final buffer = await ui.ImmutableBuffer.fromUint8List(
          await File(sourcePath).readAsBytes(),
        );
        ui.ImageDescriptor? descriptor;
        ui.Codec? codec;
        try {
          descriptor = await ui.ImageDescriptor.encoded(buffer);
          final original = ui.Size(
            descriptor.width.toDouble(),
            descriptor.height.toDouble(),
          );
          final bounds = PreviewTransform.rotatedSize(
            original,
            state.geometry.rotation,
          );
          final target = outputSize(original, state.geometry);
          final scale = math.min(
            1.0,
            math.min(
              target.width / bounds.width,
              target.height / bounds.height,
            ),
          );
          codec = await descriptor.instantiateCodec(
            targetWidth: math.max(1, (descriptor.width * scale).round()),
            targetHeight: math.max(1, (descriptor.height * scale).round()),
          );
          decoded = (await codec.getNextFrame()).image;
        } finally {
          codec?.dispose();
          descriptor?.dispose();
          buffer.dispose();
        }
      }
      final source = decoded ?? preview;
      final size = ui.Size(source.width.toDouble(), source.height.toDouble());
      final target = outputSize(size, state.geometry);
      await ShaderRegistry.instance.preload();
      shader = ShaderRegistry.instance.adjust.fragmentShader();
      shader.setImageSampler(0, source);
      final uniforms = buildAdjustUniforms(state, size);
      for (var i = 0; i < uniforms.length; i++) {
        shader.setFloat(i, uniforms[i]);
      }
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.transform(
        PreviewTransform.matrix(
          viewport: target,
          image: size,
          geometry: state.geometry,
        ).storage,
      );
      canvas.drawRect(ui.Offset.zero & size, ui.Paint()..shader = shader);
      picture = recorder.endRecording();
      output = await picture.toImage(
        target.width.toInt(),
        target.height.toInt(),
      );
      final bytes = await output.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('图片编码失败');
      return ExportedImage(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        output.width,
        output.height,
      );
    } finally {
      output?.dispose();
      picture?.dispose();
      shader?.dispose();
      decoded?.dispose();
    }
  }

  static Future<String> saveToGallery(ExportedImage image) async {
    final uri = await gallery.invokeMethod<String>('savePng', {
      'bytes': image.png,
      'name': 'Chromivelle_${DateTime.now().microsecondsSinceEpoch}.png',
    });
    if (uri == null || uri.isEmpty) throw StateError('相册未确认图片保存成功');
    return uri;
  }
}
