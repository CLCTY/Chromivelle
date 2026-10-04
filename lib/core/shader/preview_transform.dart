import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/model/edit_command.dart';

/// Shared by rendering and color picking, including rotated image bounds.
class PreviewTransform {
  static Size rotatedSize(Size image, double rotation) {
    final cos = math.cos(rotation).abs();
    final sin = math.sin(rotation).abs();
    return Size(
      image.width * cos + image.height * sin,
      image.width * sin + image.height * cos,
    );
  }

  static Matrix4 matrix({
    required Size viewport,
    required Size image,
    required GeometryTransform geometry,
    double zoom = 1,
    Offset pan = Offset.zero,
  }) {
    final bounds = rotatedSize(image, geometry.rotation);
    final fit = math.min(
      viewport.width / bounds.width,
      viewport.height / bounds.height,
    );
    return Matrix4.identity()
      ..translateByDouble(
        viewport.width / 2 + pan.dx,
        viewport.height / 2 + pan.dy,
        0,
        1,
      )
      ..rotateZ(geometry.rotation)
      ..scaleByDouble(
        fit * zoom * (geometry.flipHorizontal ? -1 : 1),
        fit * zoom * (geometry.flipVertical ? -1 : 1),
        1,
        1,
      )
      ..translateByDouble(-image.width / 2, -image.height / 2, 0, 1);
  }

  static Offset? pixelAt(Offset point, Matrix4 transform, Size image) {
    final inverse = Matrix4.tryInvert(transform);
    if (inverse == null) return null;
    final pixel = MatrixUtils.transformPoint(inverse, point);
    if (pixel.dx < 0 ||
        pixel.dy < 0 ||
        pixel.dx >= image.width ||
        pixel.dy >= image.height) {
      return null;
    }
    return pixel;
  }
}
