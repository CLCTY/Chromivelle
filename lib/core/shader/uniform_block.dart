// ============================================================================
// lib/core/shader/uniform_block.dart
//
// Uniform 槽位映射 —— 与 assets/shaders/*.frag 严格对应。
//
// ============================================================================
// ⚠️ 槽位分配规则(实测纠正,这是最容易写错的地方)
// ---------------------------------------------------------------------------
// **不是 std140 对齐,而是紧密打包(tight packing)。**
//
// Flutter 的 impellerc 把 uniform "according to decoration order" 排序后,
// 按 GLSL 声明顺序连续分配 float 槽位:
//   - float 占 1 槽
//   - vec2 占 2 槽
//   - vec3 占 3 槽  ← 不是 4!
//   - vec4 占 4 槽
//
// 引擎文档给的例子印证了这一点:
//   uniform float uScale;    -> setFloat(0)
//   uniform vec2  uMagnitude; -> setFloat(1), setFloat(2)
//   uniform vec4  uColor;     -> setFloat(3..6)
//
// sampler 不占 float 槽位,用 setImageSampler(index, image) 单独绑定,
// 索引空间独立且从 0 重新开始。
//
// ⚠️ 因此:改动任何 .frag 的 uniform 声明(哪怕只是调整顺序)都必须同步改这里,
// 否则参数会静默错位 —— 不报错,只是效果全乱。
// ============================================================================

import 'dart:typed_data';

/// adjust.frag 的槽位索引。
/// 对应 .frag 中的声明顺序(sampler 不计入)。
abstract final class AdjustUniforms {
  // --- 基础调色 (float ×9) ---
  static const int brightness = 0;
  static const int contrast = 1;
  static const int saturation = 2;
  static const int hue = 3;
  static const int exposure = 4;
  static const int temperature = 5;
  static const int tint = 6;
  static const int highlights = 7;
  static const int shadows = 8;

  // --- 开关 (float ×2) ---
  static const int enableBW = 9;
  static const int bwChannel = 10;

  // --- vec3 占 3 槽 ---
  static const int bwWeights = 11; // 11,12,13

  static const int enableHSL = 14;

  static const int hslRed = 15; // 15,16,17
  static const int hslYellow = 18; // 18,19,20
  static const int hslGreen = 21; // 21,22,23
  static const int hslCyan = 24; // 24,25,26
  static const int hslBlue = 27; // 27,28,29
  static const int hslMagenta = 30; // 30,31,32

  // --- 视口 ---
  static const int resolution = 33; // vec2 -> 33,34
  static const int aspectRatio = 35;

  /// 槽位总数
  static const int selectiveEnabled = 36;
  static const int targetHue = 37;
  static const int hueTolerance = 38;
  static const int softness = 39;
  static const int keepSaturation = 40;
  static const int blackStrength = 41;
  static const int featherPower = 42;
  static const int enableColorize = 43;
  static const int colorizeTarget = 44;
  static const int totalSlots = 47;

  /// sampler 索引(独立空间)
  static const int imageSampler = 0;

  static Float32List create({double width = 1.0, double height = 1.0}) {
    final data = Float32List(totalSlots);
    data[resolution] = width;
    data[resolution + 1] = height;
    data[aspectRatio] = height == 0 ? 1.0 : width / height;
    return data;
  }
}

/// selective_color.frag 的槽位索引
abstract final class SelectiveColorUniforms {
  static const int targetHue = 0;
  static const int hueTolerance = 1;
  static const int softness = 2;
  static const int keepSaturation = 3;
  static const int blackStrength = 4;
  static const int featherPower = 5;
  static const int enableColorize = 6;

  static const int colorizeTarget = 7; // vec3 -> 7,8,9
  static const int resolution = 10; // vec2 -> 10,11
  static const int aspectRatio = 12;

  static const int totalSlots = 13;

  static const int imageSampler = 0;

  static Float32List create({double width = 1.0, double height = 1.0}) {
    final data = Float32List(totalSlots);
    data[resolution] = width;
    data[resolution + 1] = height;
    data[aspectRatio] = height == 0 ? 1.0 : width / height;
    return data;
  }
}

/// lut3d.frag 的槽位索引
abstract final class LutUniforms {
  static const int lutSize = 0;
  static const int lutIntensity = 1;
  static const int lutEnabled = 2;
  static const int resolution = 3; // vec2 -> 3,4
  static const int aspectRatio = 5;

  static const int totalSlots = 6;

  /// 该 shader 有两个 sampler,索引空间独立
  static const int imageSampler = 0;
  static const int lutSampler = 1;

  static Float32List create({double width = 1.0, double height = 1.0}) {
    final data = Float32List(totalSlots);
    data[resolution] = width;
    data[resolution + 1] = height;
    data[aspectRatio] = height == 0 ? 1.0 : width / height;
    return data;
  }
}
