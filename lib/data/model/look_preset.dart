import 'edit_command.dart';

class LookPreset {
  const LookPreset(this.name, this.params);
  final String name;
  final AdjustParams params;

  AdjustParams atStrength(double strength, AdjustParams current) =>
      current.copyWith(
        brightness: params.brightness * strength,
        contrast: params.contrast * strength,
        saturation: params.saturation * strength,
        hue: params.hue * strength,
        exposure: params.exposure * strength,
        temperature: params.temperature * strength,
        tint: params.tint * strength,
        highlights: params.highlights * strength,
        shadows: params.shadows * strength,
      );

  static const all = [
    LookPreset('原色', AdjustParams()),
    LookPreset(
      '清透',
      AdjustParams(
        exposure: .18,
        contrast: .10,
        saturation: .08,
        shadows: -.08,
      ),
    ),
    LookPreset(
      '暖阳',
      AdjustParams(
        temperature: .32,
        exposure: .12,
        saturation: .10,
        highlights: -.10,
      ),
    ),
    LookPreset(
      '冷调',
      AdjustParams(
        temperature: -.30,
        contrast: .12,
        saturation: -.12,
        tint: .06,
      ),
    ),
    LookPreset(
      '复古',
      AdjustParams(
        temperature: .22,
        saturation: -.24,
        contrast: -.12,
        tint: .08,
      ),
    ),
    LookPreset(
      '鲜明',
      AdjustParams(contrast: .24, saturation: .28, exposure: .06),
    ),
    LookPreset(
      '奶油',
      AdjustParams(
        temperature: .14,
        contrast: -.18,
        saturation: -.15,
        brightness: .10,
      ),
    ),
    LookPreset(
      '日落',
      AdjustParams(
        temperature: .50,
        tint: .12,
        saturation: .14,
        highlights: -.18,
      ),
    ),
    LookPreset(
      '森林',
      AdjustParams(
        temperature: -.10,
        tint: -.18,
        contrast: .16,
        saturation: .16,
        hue: -.012,
      ),
    ),
    LookPreset(
      '海风',
      AdjustParams(
        temperature: -.24,
        tint: -.08,
        exposure: .18,
        saturation: .12,
      ),
    ),
    LookPreset(
      '胶片',
      AdjustParams(
        temperature: .12,
        tint: .14,
        contrast: -.08,
        saturation: -.18,
        highlights: -.20,
      ),
    ),
    LookPreset(
      '哑光',
      AdjustParams(
        contrast: -.26,
        saturation: -.12,
        shadows: -.20,
        brightness: .04,
      ),
    ),
    LookPreset(
      '人像',
      AdjustParams(
        temperature: .10,
        tint: .06,
        exposure: .12,
        saturation: -.08,
        highlights: -.10,
      ),
    ),
    LookPreset(
      '街拍',
      AdjustParams(
        contrast: .30,
        saturation: -.22,
        exposure: -.08,
        shadows: .12,
      ),
    ),
    LookPreset(
      '夜色',
      AdjustParams(exposure: -.28, temperature: -.18, contrast: .18, tint: .10),
    ),
    LookPreset(
      '雾蓝',
      AdjustParams(
        temperature: -.36,
        contrast: -.16,
        saturation: -.24,
        brightness: .06,
      ),
    ),
    LookPreset(
      '蜜桃',
      AdjustParams(
        temperature: .22,
        tint: .22,
        saturation: -.08,
        exposure: .10,
      ),
    ),
    LookPreset(
      '琥珀',
      AdjustParams(
        temperature: .44,
        tint: -.06,
        contrast: .16,
        saturation: .06,
      ),
    ),
    LookPreset(
      '青橙',
      AdjustParams(
        temperature: -.14,
        tint: -.14,
        hue: -.018,
        contrast: .20,
        saturation: .18,
      ),
    ),
    LookPreset(
      '低饱和',
      AdjustParams(saturation: -.48, contrast: .10, exposure: .08),
    ),
  ];
}
