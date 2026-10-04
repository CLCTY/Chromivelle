// ============================================================================
// test/shader_layout_test.dart
//
// 校验 Dart 侧 uniform 槽位常量与 .frag 声明顺序一致。
//
// 为什么这个测试必须存在:
//   uniform 槽位错位是**静默失败** —— 编译通过、运行不报错、只是画面全乱。
//   开发时肉眼几乎无法定位(效果像是"参数没生效"而不是"参数串位")。
//   本测试把 .frag 的 uniform 声明顺序解析出来,与 uniform_block.dart
//   的常量做逐项比对,任何一侧改动导致错位都会立刻失败。
//
// 槽位规则(实测,非 std140):
//   float=1槽, vec2=2槽, vec3=3槽, vec4=4槽,按声明顺序紧密打包。
//   sampler 不占 float 槽位。
// ============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_editor/core/shader/uniform_block.dart';

/// 解析 .frag 中 sampler 之后的 uniform 声明,返回按顺序展开的槽位数。
///
/// 返回每个 uniform 的 (名字, 起始槽位, 占用槽数)。
List<({String name, int start, int slots})> parseFragUniforms(String source) {
  final result = <({String name, int start, int slots})>[];

  // 去掉注释,避免误匹配注释里的 uniform 字样
  final noComments = source
      .split('\n')
      .map((l) => l.contains('//') ? l.substring(0, l.indexOf('//')) : l)
      .join('\n');

  final samplerCount = RegExp(r'uniform\s+sampler2D\s+\w+\s*;')
      .allMatches(noComments)
      .length;

  final re = RegExp(r'uniform\s+(float|vec2|vec3|vec4)\s+(\w+)\s*;');
  var slot = 0;
  for (final m in re.allMatches(noComments)) {
    final type = m.group(1)!;
    final name = m.group(2)!;
    final slots = switch (type) {
      'float' => 1,
      'vec2' => 2,
      'vec3' => 3,
      'vec4' => 4,
      _ => 1,
    };
    result.add((name: name, start: slot, slots: slots));
    slot += slots;
  }

  // sampler 占据前N 个独立 sampler 索引,不进入 float 空间。
  // 记录下来供调用方核对。
  assert(samplerCount >= 0);
  return result;
}

void main() {
  group('adjust.frag uniform 布局', () {
    late String source;

    setUpAll(() {
      source = File('assets/shaders/adjust.frag').readAsStringSync();
    });

    test('槽位总数与 Dart 常量一致', () {
      final uniforms = parseFragUniforms(source);
      final total = uniforms.fold<int>(0, (sum, u) => sum + u.slots);
      expect(
        total,
        AdjustUniforms.totalSlots,
        reason:
            'shader 有 $total 个槽位,'
            'Dart 常量声明 ${AdjustUniforms.totalSlots}。改动任一侧都会静默错位。',
      );
    });

    test('每个常量的槽位与 shader 声明位置一致', () {
      final uniforms = parseFragUniforms(source);
      // Dart 常量 -> 期望的 uniform 名字
      const expected = <int, String>{
        AdjustUniforms.brightness: 'uBrightness',
        AdjustUniforms.contrast: 'uContrast',
        AdjustUniforms.saturation: 'uSaturation',
        AdjustUniforms.hue: 'uHue',
        AdjustUniforms.exposure: 'uExposure',
        AdjustUniforms.temperature: 'uTemperature',
        AdjustUniforms.tint: 'uTint',
        AdjustUniforms.highlights: 'uHighlights',
        AdjustUniforms.shadows: 'uShadows',
        AdjustUniforms.enableBW: 'uEnableBW',
        AdjustUniforms.bwChannel: 'uBWChannel',
        AdjustUniforms.bwWeights: 'uBWWeights',
        AdjustUniforms.enableHSL: 'uEnableHSL',
        AdjustUniforms.hslRed: 'uHSLRed',
        AdjustUniforms.hslYellow: 'uHSLYellow',
        AdjustUniforms.hslGreen: 'uHSLGreen',
        AdjustUniforms.hslCyan: 'uHSLCyan',
        AdjustUniforms.hslBlue: 'uHSLBlue',
        AdjustUniforms.hslMagenta: 'uHSLMagenta',
        AdjustUniforms.resolution: 'uResolution',
        AdjustUniforms.aspectRatio: 'uAspectRatio',
        AdjustUniforms.selectiveEnabled: 'uSelectiveEnabled',
        AdjustUniforms.targetHue: 'uTargetHue',
        AdjustUniforms.hueTolerance: 'uHueTolerance',
        AdjustUniforms.softness: 'uSoftness',
        AdjustUniforms.keepSaturation: 'uKeepSaturation',
        AdjustUniforms.blackStrength: 'uBlackStrength',
        AdjustUniforms.featherPower: 'uFeatherPower',
        AdjustUniforms.enableColorize: 'uEnableColorize',
        AdjustUniforms.colorizeTarget: 'uColorizeTarget',
      };

      final byName = {for (final u in uniforms) u.name: u};

      expected.forEach((slot, name) {
        final u = byName[name];
        expect(u, isNotNull, reason: 'shader 里找不到 $name');
        expect(
          u!.start,
          slot,
          reason:
              '$name 在 shader 里的槽位是 ${u.start},'
              '但 Dart 常量写的是 $slot',
        );
      });
    });

    test('声明了恰好一个 sampler', () {
      // 必须先剥掉注释 —— 否则本文件顶部的说明注释里写了
      // "uniform sampler2D xxx;" 会被误计为一个真实声明。
      final noComments = source
          .split('\n')
          .map((l) => l.contains('//') ? l.substring(0, l.indexOf('//')) : l)
          .join('\n');
      final count = RegExp(r'uniform\s+sampler2D\s+')
          .allMatches(noComments)
          .length;
      expect(count, 1, reason: 'adjust.frag 只需要一个 sampler(原图)');
      expect(AdjustUniforms.imageSampler, 0);
    });
  });

  group('selective_color.frag uniform 布局', () {
    late String source;

    setUpAll(() {
      source = File('assets/shaders/selective_color.frag').readAsStringSync();
    });

    test('槽位总数一致', () {
      final total = parseFragUniforms(source)
          .fold<int>(0, (sum, u) => sum + u.slots);
      expect(total, SelectiveColorUniforms.totalSlots);
    });

    test('关键常量位置一致', () {
      final uniforms = parseFragUniforms(source);
      final byName = {for (final u in uniforms) u.name: u};

      const expected = <int, String>{
        SelectiveColorUniforms.targetHue: 'uTargetHue',
        SelectiveColorUniforms.hueTolerance: 'uHueTolerance',
        SelectiveColorUniforms.softness: 'uSoftness',
        SelectiveColorUniforms.keepSaturation: 'uKeepSaturation',
        SelectiveColorUniforms.blackStrength: 'uBlackStrength',
        SelectiveColorUniforms.featherPower: 'uFeatherPower',
        SelectiveColorUniforms.enableColorize: 'uEnableColorize',
        SelectiveColorUniforms.colorizeTarget: 'uColorizeTarget',
        SelectiveColorUniforms.resolution: 'uResolution',
        SelectiveColorUniforms.aspectRatio: 'uAspectRatio',
      };

      expected.forEach((slot, name) {
        final u = byName[name];
        expect(u, isNotNull, reason: 'shader 里找不到 $name');
        expect(u!.start, slot, reason: '$name 槽位不一致');
      });
    });
  });

  group('lut3d.frag uniform 布局', () {
    late String source;

    setUpAll(() {
      source = File('assets/shaders/lut3d.frag').readAsStringSync();
    });

    test('槽位总数一致', () {
      final total = parseFragUniforms(source)
          .fold<int>(0, (sum, u) => sum + u.slots);
      expect(total, LutUniforms.totalSlots);
    });

    test('声明了两个 sampler 且索引不冲突', () {
      final noComments = source
          .split('\n')
          .map((l) => l.contains('//') ? l.substring(0, l.indexOf('//')) : l)
          .join('\n');
      final samplers = RegExp(r'uniform\s+sampler2D\s+(\w+)')
          .allMatches(noComments)
          .map((m) => m.group(1)!)
          .toList();
      expect(samplers.length, 2, reason: 'lut3d 需要原图 + LUT 两个 sampler');
      expect(LutUniforms.imageSampler, 0);
      expect(LutUniforms.lutSampler, 1);
      expect(LutUniforms.imageSampler, isNot(LutUniforms.lutSampler));
    });
  });

  group('shader 通用规范', () {
    test('所有 .frag 都用 Flutter 正确的 include 头', () {
      const files = [
        'assets/shaders/adjust.frag',
        'assets/shaders/selective_color.frag',
        'assets/shaders/lut3d.frag',
      ];
      for (final f in files) {
        final src = File(f).readAsStringSync();
        expect(
          src.contains('#include <flutter/runtime_effect.glsl>'),
          isTrue,
          reason:
              '$f 必须用 <flutter/runtime_effect.glsl>,'
              '不能用 "dart:core/uniforms"',
        );
      }
    });

    test('不要写 #version(编译器会强制 460 core)', () {
      const files = [
        'assets/shaders/adjust.frag',
        'assets/shaders/selective_color.frag',
        'assets/shaders/lut3d.frag',
      ];
      for (final f in files) {
        final src = File(f).readAsStringSync();
        expect(
          RegExp(r'^\s*#version', multiLine: true).hasMatch(src),
          isFalse,
          reason: '$f 不应写 #version —— 编译器会强制成 (460, core) 并报警告',
        );
      }
    });

    test('每个 .frag 都有 fragColor 输出', () {
      const files = [
        'assets/shaders/adjust.frag',
        'assets/shaders/selective_color.frag',
        'assets/shaders/lut3d.frag',
      ];
      for (final f in files) {
        final src = File(f).readAsStringSync();
        expect(src.contains('out vec4 fragColor'), isTrue, reason: '$f 缺少输出声明');
      }
    });
  });
}
