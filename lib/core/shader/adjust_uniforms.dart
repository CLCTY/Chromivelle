import 'dart:typed_data';
import 'dart:ui';

import '../../data/model/edit_command.dart';
import 'uniform_block.dart';

/// One parameter mapping for both the live preview and saved images.
Float32List buildAdjustUniforms(EditState state, Size size) {
  final a = state.adjust;
  final s = state.selectiveColor;

  // --- adjust.frag ---
  final au = AdjustUniforms.create();
  au[AdjustUniforms.brightness] = a.brightness;
  au[AdjustUniforms.contrast] = a.contrast;
  au[AdjustUniforms.saturation] = a.saturation;
  au[AdjustUniforms.hue] = a.hue;
  au[AdjustUniforms.exposure] = a.exposure;
  au[AdjustUniforms.temperature] = a.temperature;
  au[AdjustUniforms.tint] = a.tint;
  au[AdjustUniforms.highlights] = a.highlights;
  au[AdjustUniforms.shadows] = a.shadows;
  au[AdjustUniforms.enableBW] = a.enableBW ? 1.0 : 0.0;
  au[AdjustUniforms.bwChannel] = a.bwChannel.toDouble();

  au[AdjustUniforms.resolution] = size.width;
  au[AdjustUniforms.resolution + 1] = size.height;
  au[AdjustUniforms.aspectRatio] = size.width / size.height;

  au[AdjustUniforms.bwWeights] = a.bwWeights[0];
  au[AdjustUniforms.bwWeights + 1] = a.bwWeights[1];
  au[AdjustUniforms.bwWeights + 2] = a.bwWeights[2];

  void writeHsl(int base, HslAdjustment adj) {
    au[base] = adj.saturation;
    au[base + 1] = adj.luminance;
    au[base + 2] = adj.hue;
  }

  writeHsl(
    AdjustUniforms.hslRed,
    a.hslZones[HslZone.red] ?? HslAdjustment.neutral,
  );
  writeHsl(
    AdjustUniforms.hslYellow,
    a.hslZones[HslZone.yellow] ?? HslAdjustment.neutral,
  );
  writeHsl(
    AdjustUniforms.hslGreen,
    a.hslZones[HslZone.green] ?? HslAdjustment.neutral,
  );
  writeHsl(
    AdjustUniforms.hslCyan,
    a.hslZones[HslZone.cyan] ?? HslAdjustment.neutral,
  );
  writeHsl(
    AdjustUniforms.hslBlue,
    a.hslZones[HslZone.blue] ?? HslAdjustment.neutral,
  );
  writeHsl(
    AdjustUniforms.hslMagenta,
    a.hslZones[HslZone.magenta] ?? HslAdjustment.neutral,
  );
  au[AdjustUniforms.enableHSL] = a.enableHSL ? 1.0 : 0.0;

  au[AdjustUniforms.selectiveEnabled] = s.enabled ? 1 : 0;
  au[AdjustUniforms.targetHue] = s.targetHue;
  au[AdjustUniforms.hueTolerance] = s.hueTolerance;
  au[AdjustUniforms.softness] = s.softness;
  au[AdjustUniforms.keepSaturation] = s.keepSaturation;
  au[AdjustUniforms.blackStrength] = s.blackStrength;
  au[AdjustUniforms.featherPower] = s.featherPower;
  au[AdjustUniforms.enableColorize] = s.enableColorize ? 1 : 0;
  for (var i = 0; i < 3; i++) {
    au[AdjustUniforms.colorizeTarget + i] = s.colorizeTarget[i];
  }
  return au;
}
