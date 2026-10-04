import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/model/edit_command.dart';
import 'shader_registry.dart';
import 'uniform_block.dart';
import 'preview_transform.dart';
import 'adjust_uniforms.dart';

class ImagePreview extends StatefulWidget {
  const ImagePreview({
    super.key,
    required this.image,
    required this.state,
    this.onPixelTapped,
  });
  final ui.Image image;
  final EditState state;
  final ValueChanged<Offset>? onPixelTapped;
  @override
  State<ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<ImagePreview> {
  ui.FragmentShader? _shader;
  Float32List _adjustUniforms = AdjustUniforms.create();
  double _zoom = 1, _startZoom = 1;
  Offset _pan = Offset.zero, _anchor = Offset.zero;
  Offset _doubleTapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    _shader?.dispose();
    _shader = ShaderRegistry.instance.isReady
        ? ShaderRegistry.instance.adjust.fragmentShader()
        : null;
    _shader?.setImageSampler(0, widget.image);
  }

  @override
  void didUpdateWidget(ImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _bind();
      _zoom = 1;
      _pan = Offset.zero;
    }
    if (oldWidget.state.geometry != widget.state.geometry) {
      _zoom = 1;
      _pan = Offset.zero;
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final viewport = constraints.biggest;
      final image = Size(
        widget.image.width.toDouble(),
        widget.image.height.toDouble(),
      );
      _adjustUniforms = buildAdjustUniforms(widget.state, image);
      final transform = PreviewTransform.matrix(
        viewport: viewport,
        image: image,
        geometry: widget.state.geometry,
        zoom: _zoom,
        pan: _pan,
      );
      final center = Offset(viewport.width / 2, viewport.height / 2);
      void clampPan() {
        final rotated = PreviewTransform.rotatedSize(
          image,
          widget.state.geometry.rotation,
        );
        final fit = math.min(
          viewport.width / rotated.width,
          viewport.height / rotated.height,
        );
        final x = math.max(
          0.0,
          (rotated.width * fit * _zoom - viewport.width) / 2,
        );
        final y = math.max(
          0.0,
          (rotated.height * fit * _zoom - viewport.height) / 2,
        );
        _pan = Offset(_pan.dx.clamp(-x, x), _pan.dy.clamp(-y, y));
      }

      return GestureDetector(
        onScaleStart: (details) {
          _startZoom = _zoom;
          _anchor = (details.localFocalPoint - center - _pan) / _zoom;
        },
        onScaleUpdate: (details) => setState(() {
          _zoom = (_startZoom * details.scale).clamp(1.0, 8.0);
          _pan = details.localFocalPoint - center - _anchor * _zoom;
          clampPan();
        }),
        onDoubleTapDown: (details) =>
            _doubleTapPosition = details.localPosition,
        onDoubleTap: () => setState(() {
          if (_zoom > 1.01) {
            _zoom = 1;
            _pan = Offset.zero;
          } else {
            _zoom = 2.5;
            _pan = (center - _doubleTapPosition) * (_zoom - 1);
            clampPan();
          }
        }),
        onTapUp: widget.onPixelTapped == null
            ? null
            : (details) {
                final pixel = PreviewTransform.pixelAt(
                  details.localPosition,
                  transform,
                  image,
                );
                if (pixel != null) widget.onPixelTapped!(pixel);
              },
        child: CustomPaint(
          size: viewport,
          isComplex: true,
          painter: _PreviewPainter(
            image: widget.image,
            shader: _shader,
            uniforms: _adjustUniforms,
            transform: transform,
            state: widget.state,
          ),
        ),
      );
    },
  );
}

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter({
    required this.image,
    required this.shader,
    required this.uniforms,
    required this.transform,
    required this.state,
  });
  final ui.Image image;
  final ui.FragmentShader? shader;
  final Float32List uniforms;
  final Matrix4 transform;
  final EditState state;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF1A1A1A),
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.transform(transform.storage);
    final rect = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    if (shader == null) {
      canvas.drawImageRect(
        image,
        rect,
        rect,
        Paint()..filterQuality = FilterQuality.medium,
      );
    } else {
      for (var i = 0; i < uniforms.length; i++) {
        shader!.setFloat(i, uniforms[i]);
      }
      canvas.drawRect(rect, Paint()..shader = shader);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PreviewPainter old) =>
      old.image != image || old.state != state || old.transform != transform;
}
