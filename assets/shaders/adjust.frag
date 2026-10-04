// Combined tone, HSL, black-and-white, and selective-color adjustments.
// Uniform layout: lib/core/shader/uniform_block.dart.

#include <flutter/runtime_effect.glsl>

// 默认采样器。Dart 侧用 setImageSampler(0, image) 绑定。
uniform sampler2D uImageSampler;

// --- 基础调色 ---
uniform float uBrightness;   // -1.0 .. 1.0
uniform float uContrast;     // -1.0 .. 1.0
uniform float uSaturation;   // -1.0 .. 1.0
uniform float uHue;          // -0.5 .. 0.5  (环绕,单位为圈)
uniform float uExposure;     // -2.0 .. 2.0  (EV)
uniform float uTemperature;  // -1.0 .. 1.0  (冷<->暖)
uniform float uTint;         // -1.0 .. 1.0  (绿<->洋红)
uniform float uHighlights;   // -1.0 .. 1.0
uniform float uShadows;      // -1.0 .. 1.0

// --- 功能开关 ---
uniform float uEnableBW;     // 0/1 黑白
uniform float uBWChannel;    // 0..5 选通道权重(RGB 逐通道)
uniform vec3  uBWWeights;    // 黑白通道混合权重
uniform float uEnableHSL;    // 0/1
uniform vec3  uHSLRed;       // 色相分区: 饱和/亮度/色相偏移
uniform vec3  uHSLYellow;
uniform vec3  uHSLGreen;
uniform vec3  uHSLCyan;
uniform vec3  uHSLBlue;
uniform vec3  uHSLMagenta;

// --- 视口 ---
uniform vec2  uResolution;   // 输出分辨率
uniform float uAspectRatio;  // width/height,供依赖宽高比的运算使用

// Color splash shares the adjusted pixels rather than replacing the first pass.
uniform float uSelectiveEnabled;
uniform float uTargetHue;
uniform float uHueTolerance;
uniform float uSoftness;
uniform float uKeepSaturation;
uniform float uBlackStrength;
uniform float uFeatherPower;
uniform float uEnableColorize;
uniform vec3 uColorizeTarget;

out vec4 fragColor;

// ============================================================================
// 工具函数
// ============================================================================

// sRGB <-> 线性。亮度/对比度必须在线性空间做才物理正确,
// 直接在sRGB 上做会让中间调发灰(这也是很多 App 的通病)。
vec3 srgbToLinear(vec3 c) {
  return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

vec3 linearToSrgb(vec3 c) {
  return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055,
             step(0.0031308, c));
}

// Rec.709 亮度
float luminance(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// HSV 分解(hsv.x 在 [0,1))
vec3 rgb2hsv(vec3 c) {
  vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
  vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
  vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
  float d = q.x - min(q.w, q.y);
  return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv2rgb(vec3 c) {
  vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// 色温/色调:沿"白点"方向推动颜色。
// 白点在 sRGB 的近似冷暖轴: 暖=(1.0, 0.87, 0.72), 冷=(0.72, 0.87, 1.0)
vec3 applyWhiteBalance(vec3 c) {
  vec3 warm = vec3(1.0, 0.87, 0.72);
  vec3 cool = vec3(0.72, 0.87, 1.0);
  vec3 g = mix(vec3(1.0), mix(cool, warm, uTemperature * 0.5 + 0.5), abs(uTemperature));
  c *= g;
  // tint 沿 绿<->洋红
  c.g -= uTint * 0.08;
  c.r += uTint * 0.05;
  c.b += uTint * 0.05;
  return c;
}

// 高光/阴影:基于亮度的平滑掩膜加权调整
vec3 applyToneZones(vec3 c) {
  float lum = luminance(c);
  float shadowMask = 1.0 - smoothstep(0.0, 0.5, lum);
  float highMask = smoothstep(0.5, 1.0, lum);
  c += (c - 0.5) * (uShadows * shadowMask * 0.5 + uHighlights * highMask * 0.5);
  return c;
}

// 黑白:亮度基 + 逐通道权重(模拟传统滤镜的通道过滤)
vec3 applyBlackWhite(vec3 c) {
  vec3 weights = max(uBWWeights, vec3(0.0));
  float gray = uBWChannel < 0.5 ? luminance(c) : dot(c, weights) / max(dot(weights, vec3(1.0)), 0.0001);
  return vec3(gray);
}

// --- HSL 八分区 ---
// 权重函数:给定色相,返回该分区的归属度(0..1,三角窗,相邻分区交叉淡入)
float hueZone(float h, float center) {
  float d = abs(fract(h - center + 0.5) - 0.5);   // 环绕距离
  return 1.0 - smoothstep(0.0, 1.0 / 6.0 * 1.6, d);
}

// 对某个分区施加 [饱和度偏移, 亮度偏移, 色相偏移]
vec3 applyHslZone(vec3 rgb, float h, vec3 adj) {
  if (adj.x == 0.0 && adj.y == 0.0 && adj.z == 0.0) return rgb;
  vec3 hsv = rgb2hsv(rgb);
  hsv.x = fract(hsv.x + adj.z);                     // 色相偏移(环绕)
  hsv.y = clamp(hsv.y + adj.x, 0.0, 1.0);           // 饱和度
  hsv.z = clamp(hsv.z + adj.y, 0.0, 1.0);           // 亮度
  return hsv2rgb(hsv);
}

vec3 applyHSL(vec3 rgb) {
  float h = rgb2hsv(rgb).x;
  vec3 outc = rgb;
  outc = mix(outc, applyHslZone(outc, h, uHSLRed),     hueZone(h, 0.000));
  outc = mix(outc, applyHslZone(outc, h, uHSLYellow),  hueZone(h, 0.167));
  outc = mix(outc, applyHslZone(outc, h, uHSLGreen),   hueZone(h, 0.333));
  outc = mix(outc, applyHslZone(outc, h, uHSLCyan),    hueZone(h, 0.500));
  outc = mix(outc, applyHslZone(outc, h, uHSLBlue),    hueZone(h, 0.667));
  outc = mix(outc, applyHslZone(outc, h, uHSLMagenta), hueZone(h, 0.833));
  return outc;
}

vec3 applySelective(vec3 adjusted, vec3 source) {
  float distance = abs(rgb2hsv(source).x - uTargetHue);
  distance = min(distance, 1.0 - distance);
  float outer = min(uHueTolerance + max(uSoftness, 0.0001), 0.5);
  float grayMix = pow(smoothstep(uHueTolerance, outer, distance), max(uFeatherPower, 0.01));
  float gray = luminance(adjusted) * mix(1.0, 0.25, uBlackStrength);
  vec3 hsv = rgb2hsv(adjusted);
  if (uEnableColorize > 0.5) hsv.x = rgb2hsv(uColorizeTarget).x;
  hsv.y *= uKeepSaturation;
  return mix(hsv2rgb(hsv), vec3(gray), grayMix);
}

// ============================================================================
// 主流程
// ============================================================================

void main() {
  vec2 uv = FlutterFragCoord().xy / uResolution;

  // 纹理已在下面由 setImageSampler 绑定; Flutter 的默认 sampler 名为 sampler0
  vec4 src = texture(uImageSampler, uv);
  vec3 c = src.rgb;
  float alpha = src.a;

  // ---- 线性空间处理 ----
  c = srgbToLinear(c);

  // 曝光 (EV) — 在线性空间做,物理正确
  c *= pow(2.0, uExposure);

  // 白平衡
  c = applyWhiteBalance(c);

  // 亮度:在线性空间乘常数(加法在线性空间不自然)
  c *= (1.0 + uBrightness * 0.8);

  // 高光/阴影
  c = applyToneZones(c);

  // 对比度:绕 0.5 线性中点
  c = (c - 0.5) * (1.0 + uContrast) + 0.5;

  // ---- 回到sRGB 做色相类操作 ----
  c = linearToSrgb(clamp(c, 0.0, 1.0));

  // HSL 八分区
  if (uEnableHSL > 0.5) c = applyHSL(c);

  // 饱和度
  if (uEnableBW < 0.5) {
    float l = luminance(c);
    c = mix(vec3(l), c, 1.0 + uSaturation);
  }

  // 色相旋转:转HSV 改 H 再转回(比RGB矩阵更不易引入色带)
  if (abs(uHue) > 0.001) {
    vec3 hsv = rgb2hsv(c);
    hsv.x = fract(hsv.x + uHue);
    c = hsv2rgb(hsv);
  }

  // 黑白覆盖(放在最后,保证是纯黑白)
  if (uEnableBW > 0.5) c = applyBlackWhite(c);

  if (uSelectiveEnabled > 0.5) c = applySelective(c, src.rgb);

  fragColor = vec4(clamp(c, 0.0, 1.0), alpha);
}