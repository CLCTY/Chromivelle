// Immutable parameters shared by preview and export.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Offset;

// =============================================================================
// 调色参数
// =============================================================================

@immutable
class AdjustParams {
  const AdjustParams({
    this.brightness = 0.0,
    this.contrast = 0.0,
    this.saturation = 0.0,
    this.hue = 0.0,
    this.exposure = 0.0,
    this.temperature = 0.0,
    this.tint = 0.0,
    this.highlights = 0.0,
    this.shadows = 0.0,
    this.enableBW = false,
    this.bwChannel = 0,
    this.bwWeights = const [1.0, 1.0, 1.0],
    this.enableHSL = false,
    this.hslZones = const {},
  });

  final double brightness; // -1..1
  final double contrast; // -1..1
  final double saturation; // -1..1
  final double hue; // -0.5..0.5
  final double exposure; // -2..2
  final double temperature; // -1..1
  final double tint; // -1..1
  final double highlights; // -1..1
  final double shadows; // -1..1
  final bool enableBW;
  final int bwChannel; // 0=纯亮度 1=红 2=黄 3=绿 4=青 5=蓝
  final List<double> bwWeights; // RGB 权重
  final bool enableHSL;
  final Map<HslZone, HslAdjustment> hslZones;

  static const AdjustParams neutral = AdjustParams();

  AdjustParams copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    double? hue,
    double? exposure,
    double? temperature,
    double? tint,
    double? highlights,
    double? shadows,
    bool? enableBW,
    int? bwChannel,
    List<double>? bwWeights,
    bool? enableHSL,
    Map<HslZone, HslAdjustment>? hslZones,
  }) {
    return AdjustParams(
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      hue: hue ?? this.hue,
      exposure: exposure ?? this.exposure,
      temperature: temperature ?? this.temperature,
      tint: tint ?? this.tint,
      highlights: highlights ?? this.highlights,
      shadows: shadows ?? this.shadows,
      enableBW: enableBW ?? this.enableBW,
      bwChannel: bwChannel ?? this.bwChannel,
      bwWeights: bwWeights ?? this.bwWeights,
      enableHSL: enableHSL ?? this.enableHSL,
      hslZones: hslZones ?? this.hslZones,
    );
  }

  /// 是否为中性状态(用于 UI 上禁用重置按钮)
  bool get isNeutral =>
      brightness == 0 &&
      contrast == 0 &&
      saturation == 0 &&
      hue == 0 &&
      exposure == 0 &&
      temperature == 0 &&
      tint == 0 &&
      highlights == 0 &&
      shadows == 0 &&
      !enableBW &&
      !enableHSL &&
      hslZones.isEmpty;

  /// 传统黑白滤镜的通道权重表(对应 Lightroom/VSCO 的经典配方)
  static const Map<int, List<double>> bwPresets = {
    0: [1.0, 1.0, 1.0], // 纯亮度
    1: [0.30, 0.59, 0.11], // 红
    2: [0.43, 0.78, 0.19], // 黄
    3: [0.21, 0.72, 0.07], // 绿
    4: [0.18, 0.76, 0.24], // 青
    5: [0.11, 0.48, 0.30], // 蓝
  };

  static const Map<int, String> bwPresetNames = {
    0: '亮度',
    1: '红',
    2: '黄',
    3: '绿',
    4: '青',
    5: '蓝',
  };

  Map<String, dynamic> toJson() => {
    'brightness': brightness,
    'contrast': contrast,
    'saturation': saturation,
    'hue': hue,
    'exposure': exposure,
    'temperature': temperature,
    'tint': tint,
    'highlights': highlights,
    'shadows': shadows,
    'enableBW': enableBW,
    'bwChannel': bwChannel,
    'bwWeights': bwWeights,
    'enableHSL': enableHSL,
    'hslZones': hslZones.map((k, v) => MapEntry(k.name, v.toJson())),
  };

  static AdjustParams fromJson(Map<String, dynamic> json) {
    return AdjustParams(
      brightness: (json['brightness'] as num?)?.toDouble() ?? 0,
      contrast: (json['contrast'] as num?)?.toDouble() ?? 0,
      saturation: (json['saturation'] as num?)?.toDouble() ?? 0,
      hue: (json['hue'] as num?)?.toDouble() ?? 0,
      exposure: (json['exposure'] as num?)?.toDouble() ?? 0,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
      tint: (json['tint'] as num?)?.toDouble() ?? 0,
      highlights: (json['highlights'] as num?)?.toDouble() ?? 0,
      shadows: (json['shadows'] as num?)?.toDouble() ?? 0,
      enableBW: json['enableBW'] as bool? ?? false,
      bwChannel: json['bwChannel'] as int? ?? 0,
      bwWeights:
          (json['bwWeights'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [1.0, 1.0, 1.0],
      enableHSL: json['enableHSL'] as bool? ?? false,
      hslZones: (json['hslZones'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(
          HslZone.values.firstWhere(
            (e) => e.name == k,
            orElse: () => HslZone.red,
          ),
          HslAdjustment.fromJson(Map<String, dynamic>.from(v as Map)),
        ),
      ),
    );
  }
}

// =============================================================================
// HSL 八分区
// =============================================================================

enum HslZone { red, yellow, green, cyan, blue, magenta }

@immutable
class HslAdjustment {
  const HslAdjustment({
    this.saturation = 0.0,
    this.luminance = 0.0,
    this.hue = 0.0,
  });

  final double saturation; // -1..1
  final double luminance; // -1..1
  final double hue; // -0.5..0.5

  static const HslAdjustment neutral = HslAdjustment();

  bool get isNeutral => saturation == 0 && luminance == 0 && hue == 0;

  HslAdjustment copyWith({double? saturation, double? luminance, double? hue}) {
    return HslAdjustment(
      saturation: saturation ?? this.saturation,
      luminance: luminance ?? this.luminance,
      hue: hue ?? this.hue,
    );
  }

  Map<String, dynamic> toJson() => {
    'saturation': saturation,
    'luminance': luminance,
    'hue': hue,
  };

  static HslAdjustment fromJson(Map<String, dynamic> json) => HslAdjustment(
    saturation: (json['saturation'] as num?)?.toDouble() ?? 0,
    luminance: (json['luminance'] as num?)?.toDouble() ?? 0,
    hue: (json['hue'] as num?)?.toDouble() ?? 0,
  );
}

// =============================================================================
// 去色留色(Color Splash)—— 你最初问的那个功能
// =============================================================================

@immutable
class SelectiveColorParams {
  const SelectiveColorParams({
    this.enabled = false,
    this.targetHue = 0.333, // 默认绿色
    this.hueTolerance = 0.08,
    this.softness = 0.12,
    this.keepSaturation = 1.0,
    this.blackStrength = 0.0,
    this.featherPower = 1.0,
    this.enableColorize = false,
    this.colorizeTarget = const [0.2, 0.6, 0.3],
  });

  final bool enabled;

  /// 目标色相(0..1,HSV 空间的 H)
  final double targetHue;

  /// 色相容差:容差内的色相被保留
  final double hueTolerance;

  /// 过渡带宽度:0=硬边,越大越柔和
  final double softness;

  /// 保留色相的饱和度比例。1=完全保留,<1 会更自然
  final double keepSaturation;

  /// 非目标色相变黑的程度。0=变灰,1=接近纯黑
  final double blackStrength;

  /// 过渡曲线幂次
  final double featherPower;

  /// 是否给目标色相重新上色
  final bool enableColorize;

  /// 重新上色的目标 RGB
  final List<double> colorizeTarget;

  static const SelectiveColorParams neutral = SelectiveColorParams();

  SelectiveColorParams copyWith({
    bool? enabled,
    double? targetHue,
    double? hueTolerance,
    double? softness,
    double? keepSaturation,
    double? blackStrength,
    double? featherPower,
    bool? enableColorize,
    List<double>? colorizeTarget,
  }) {
    return SelectiveColorParams(
      enabled: enabled ?? this.enabled,
      targetHue: targetHue ?? this.targetHue,
      hueTolerance: hueTolerance ?? this.hueTolerance,
      softness: softness ?? this.softness,
      keepSaturation: keepSaturation ?? this.keepSaturation,
      blackStrength: blackStrength ?? this.blackStrength,
      featherPower: featherPower ?? this.featherPower,
      enableColorize: enableColorize ?? this.enableColorize,
      colorizeTarget: colorizeTarget ?? this.colorizeTarget,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'targetHue': targetHue,
    'hueTolerance': hueTolerance,
    'softness': softness,
    'keepSaturation': keepSaturation,
    'blackStrength': blackStrength,
    'featherPower': featherPower,
    'enableColorize': enableColorize,
    'colorizeTarget': colorizeTarget,
  };

  static SelectiveColorParams fromJson(Map<String, dynamic> json) {
    return SelectiveColorParams(
      enabled: json['enabled'] as bool? ?? false,
      targetHue: (json['targetHue'] as num?)?.toDouble() ?? 0.333,
      hueTolerance: (json['hueTolerance'] as num?)?.toDouble() ?? 0.08,
      softness: (json['softness'] as num?)?.toDouble() ?? 0.12,
      keepSaturation: (json['keepSaturation'] as num?)?.toDouble() ?? 1.0,
      blackStrength: (json['blackStrength'] as num?)?.toDouble() ?? 0.0,
      featherPower: (json['featherPower'] as num?)?.toDouble() ?? 1.0,
      enableColorize: json['enableColorize'] as bool? ?? false,
      colorizeTarget:
          (json['colorizeTarget'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [0.2, 0.6, 0.3],
    );
  }
}

// =============================================================================
// 几何变换
// =============================================================================

@immutable
class GeometryTransform {
  const GeometryTransform({
    this.rotation = 0.0, // 弧度
    this.scale = 1.0,
    this.offset = Offset.zero,
    this.flipHorizontal = false,
    this.flipVertical = false,
  });

  final double rotation;
  final double scale;
  final Offset offset;
  final bool flipHorizontal;
  final bool flipVertical;

  static const GeometryTransform identity = GeometryTransform();

  bool get isIdentity =>
      rotation == 0 &&
      scale == 1.0 &&
      offset == Offset.zero &&
      !flipHorizontal &&
      !flipVertical;

  GeometryTransform copyWith({
    double? rotation,
    double? scale,
    Offset? offset,
    bool? flipHorizontal,
    bool? flipVertical,
  }) {
    return GeometryTransform(
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      offset: offset ?? this.offset,
      flipHorizontal: flipHorizontal ?? this.flipHorizontal,
      flipVertical: flipVertical ?? this.flipVertical,
    );
  }

  /// 旋正 90 度(裁剪时用)
  GeometryTransform rotateQuarter(bool clockwise) {
    final delta = clockwise ? math.pi / 2 : -math.pi / 2;
    return copyWith(rotation: rotation + delta);
  }

  Map<String, dynamic> toJson() => {
    'rotation': rotation,
    'scale': scale,
    'offset': [offset.dx, offset.dy],
    'flipHorizontal': flipHorizontal,
    'flipVertical': flipVertical,
  };

  static GeometryTransform fromJson(Map<String, dynamic> json) {
    final off = (json['offset'] as List?) ?? const [0.0, 0.0];
    return GeometryTransform(
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      offset: Offset((off[0] as num).toDouble(), (off[1] as num).toDouble()),
      flipHorizontal: json['flipHorizontal'] as bool? ?? false,
      flipVertical: json['flipVertical'] as bool? ?? false,
    );
  }
}

// =============================================================================
// LUT / 滤镜
// =============================================================================

@immutable
class LutParams {
  const LutParams({
    this.enabled = false,
    this.assetPath,
    this.size = 33,
    this.intensity = 1.0,
    this.name = '',
  });

  final bool enabled;
  final String? assetPath;
  final int size; // N (17/33/65)
  final double intensity;
  final String name;

  static const LutParams neutral = LutParams();

  LutParams copyWith({
    bool? enabled,
    String? assetPath,
    int? size,
    double? intensity,
    String? name,
  }) {
    return LutParams(
      enabled: enabled ?? this.enabled,
      assetPath: assetPath ?? this.assetPath,
      size: size ?? this.size,
      intensity: intensity ?? this.intensity,
      name: name ?? this.name,
    );
  }
}

// =============================================================================
// 完整编辑状态
// =============================================================================

@immutable
class EditState {
  const EditState({
    this.adjust = AdjustParams.neutral,
    this.selectiveColor = SelectiveColorParams.neutral,
    this.geometry = GeometryTransform.identity,
    this.lut = LutParams.neutral,
  });

  final AdjustParams adjust;
  final SelectiveColorParams selectiveColor;
  final GeometryTransform geometry;
  final LutParams lut;

  bool get isNeutral =>
      adjust.isNeutral &&
      !selectiveColor.enabled &&
      geometry.isIdentity &&
      !lut.enabled;

  EditState copyWith({
    AdjustParams? adjust,
    SelectiveColorParams? selectiveColor,
    GeometryTransform? geometry,
    LutParams? lut,
  }) {
    return EditState(
      adjust: adjust ?? this.adjust,
      selectiveColor: selectiveColor ?? this.selectiveColor,
      geometry: geometry ?? this.geometry,
      lut: lut ?? this.lut,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'adjust': adjust.toJson(),
    'selectiveColor': selectiveColor.toJson(),
    'geometry': geometry.toJson(),
    'lut': {
      'enabled': lut.enabled,
      'assetPath': lut.assetPath,
      'intensity': lut.intensity,
    },
  };

  static EditState fromJson(Map<String, dynamic> json) {
    return EditState(
      adjust: AdjustParams.fromJson(
        Map<String, dynamic>.from(json['adjust'] ?? {}),
      ),
      selectiveColor: SelectiveColorParams.fromJson(
        Map<String, dynamic>.from(json['selectiveColor'] ?? {}),
      ),
      geometry: GeometryTransform.fromJson(
        Map<String, dynamic>.from(json['geometry'] ?? {}),
      ),
      lut: LutParams(
        enabled: (json['lut'] as Map?)?['enabled'] as bool? ?? false,
        assetPath: (json['lut'] as Map?)?['assetPath'] as String?,
        intensity:
            ((json['lut'] as Map?)?['intensity'] as num?)?.toDouble() ?? 1.0,
      ),
    );
  }
}
