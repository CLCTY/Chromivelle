// Viewport scaling and coordinate conversion utilities.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class CoordinateSpace {
  CoordinateSpace();

  /// 用户可缩放范围
  static const double minScale = 1.0;
  static const double maxScale = 8.0;

  /// 当前缩放
  double _scale = 1.0;

  /// 当前平移(逻辑像素)
  Offset _translation = Offset.zero;

  /// 视口尺寸(逻辑像素)
  Size _viewportSize = Size.zero;

  /// 图像原始尺寸
  Size _imageSize = Size.zero;

  double get scale => _scale;
  Offset get translation => _translation;
  Size get viewportSize => _viewportSize;

  /// 图像在视口内的"适配缩放"(contain 模式)
  double get _fitScale {
    if (_imageSize.isEmpty || _viewportSize.isEmpty) return 1.0;
    final scaleX = _viewportSize.width / _imageSize.width;
    final scaleY = _viewportSize.height / _imageSize.height;
    return math.min(scaleX, scaleY);
  }

  /// 图像在视口中的实际显示尺寸(未叠加用户缩放)
  Size get fittedImageSize {
    final s = _fitScale;
    return Size(_imageSize.width * s, _imageSize.height * s);
  }

  /// 设置视口与图像尺寸。视口变化时重新 clamp 平移量。
  void update({Size? viewport, Size? image}) {
    if (viewport != null) _viewportSize = viewport;
    if (image != null) _imageSize = image;
    _clampTranslation();
  }

  /// 视口 -> 图像 的变换矩阵(用于 GestureDetector 的坐标转换)
  Matrix4 get viewportToImage {
    final fitted = fittedImageSize;
    // 图像在视口中居中
    final baseOffset = Offset(
      (_viewportSize.width - fitted.width) / 2,
      (_viewportSize.height - fitted.height) / 2,
    );

    return Matrix4.identity()
      // 先平移回原点
      ..translateByDouble(-baseOffset.dx, -baseOffset.dy, 0, 1)
      // 用户变换(缩放围绕视口中心,再平移)
      ..translateByDouble(
        _viewportSize.width / 2,
        _viewportSize.height / 2,
        0,
        1,
      )
      ..scaleByDouble(_scale, _scale, _scale, 1)
      ..translateByDouble(
        -_viewportSize.width / 2,
        -_viewportSize.height / 2,
        0,
        1,
      )
      ..translateByDouble(_translation.dx, _translation.dy, 0, 1);
  }

  /// 图像 -> 视口 的变换矩阵(= 上面那个的逆)。
  /// 传给 shader,shader 用它把 fragcoord 转成图像 UV。
  Matrix4 get imageToViewport {
    final m = Matrix4.identity();
    m.setEntry(0, 0, _viewportSize.width);
    m.setEntry(1, 1, _viewportSize.height);
    m.setEntry(2, 2, 1.0);
    m.setEntry(3, 3, 1.0);
    final fitted = fittedImageSize;
    final baseOffset = Offset(
      (_viewportSize.width - fitted.width) / 2,
      (_viewportSize.height - fitted.height) / 2,
    );
    m
      ..translateByDouble(baseOffset.dx, baseOffset.dy, 0, 1)
      ..translateByDouble(
        _viewportSize.width / 2,
        _viewportSize.height / 2,
        0,
        1,
      )
      ..scaleByDouble(_scale, _scale, _scale, 1)
      ..translateByDouble(
        -_viewportSize.width / 2,
        -_viewportSize.height / 2,
        0,
        1,
      )
      ..translateByDouble(_translation.dx, _translation.dy, 0, 1);
    return m;
  }

  /// 把屏幕坐标点转成图像像素坐标(取色器需要)
  Offset? screenToImagePixel(Offset screenPoint) {
    final fitted = fittedImageSize;
    if (fitted.isEmpty) return null;

    final baseOffset = Offset(
      (_viewportSize.width - fitted.width) / 2,
      (_viewportSize.height - fitted.height) / 2,
    );

    // 反解:先减用户平移,再反向缩放,再减居中偏移,最后除以 fitScale
    var p = screenPoint - _translation;

    // 反向缩放(围绕视口中心)
    final center = Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    p = center + (p - center) / _scale;

    p -= baseOffset;

    final px = p.dx / _fitScale;
    final py = p.dy / _fitScale;

    if (px < 0 || py < 0 || px >= _imageSize.width || py >= _imageSize.height) {
      return null; // 点在图像外
    }
    return Offset(px, py);
  }

  /// 双指缩放 + 拖动平移。参数来自 GestureDetector 的 ScaleUpdateDetails。
  void applyScaleUpdate({
    required double scaleFactor,
    required Offset focalPointDelta,
  }) {
    final newScale = (_scale * scaleFactor).clamp(minScale, maxScale);
    final applied = newScale / _scale;
    _scale = newScale;

    // 以焦点为锚点缩放,让缩放中心跟手
    if (applied != 1.0) {
      final center = Offset(_viewportSize.width / 2, _viewportSize.height / 2);
      final offset = focalPointDelta - center;
      // 焦点下的点保持不动
      _translation = _translation + offset - (offset / applied);
    }

    _translation += focalPointDelta;
    _clampTranslation();
  }

  /// 限制平移量,防止图像被拖出视野。
  void _clampTranslation() {
    if (_viewportSize.isEmpty) return;

    final fitted = fittedImageSize;
    final scaled = Size(fitted.width * _scale, fitted.height * _scale);

    // 图像小于视口时锁定居中;大于时允许拖动但留边
    final maxDx = scaled.width > _viewportSize.width
        ? (scaled.width - _viewportSize.width) / 2
        : 0.0;
    final maxDy = scaled.height > _viewportSize.height
        ? (scaled.height - _viewportSize.height) / 2
        : 0.0;

    _translation = Offset(
      _translation.dx.clamp(-maxDx, maxDx),
      _translation.dy.clamp(-maxDy, maxDy),
    );
  }

  /// 双击在指定点缩放(1x <-> 2.5x)
  void handleDoubleTap(Offset position) {
    const targetZoom = 2.5;
    if (_scale > minScale + 0.01) {
      // 当前已放大 -> 复位
      _scale = 1.0;
      _translation = Offset.zero;
    } else {
      // 放大到该点
      _scale = targetZoom;
      final center = Offset(_viewportSize.width / 2, _viewportSize.height / 2);
      final offset = position - center;
      _translation = offset - offset / targetZoom;
    }
    _clampTranslation();
  }

  void reset() {
    _scale = 1.0;
    _translation = Offset.zero;
  }
}
