// ============================================================================
// selective_color.frag — 去色留色 / Color Splash
//
// 这就是你最初问的那个功能:只保留一种色相(比如树叶的绿),
// 其余全部转成黑白。
//
// 三种实现路径(本文件用第一种,另两种在下方注释保留):
//   1. HSV 色相距离  ← 采用。廉价、无依赖,可解释
//   2. Lab/OKLab 色差  ← 更符合人眼感知,保留"相近色"
//   3. RGB 空间曼哈顿距离 ← 最快,但对色相变化不敏感,会把蓝紫混一起
//
// uniform 布局必须与 lib/core/shader/uniform_block.dart 严格一致。
// ============================================================================

#include <flutter/runtime_effect.glsl>

uniform sampler2D uImageSampler;

uniform float uTargetHue;      // 0..1 目标色相(从取色器获得)
uniform float uHueTolerance;   // 0..1 色相容差(越宽保留越多)
uniform float uSoftness;       // 0..1 过渡软硬,0=硬边 1=极柔和
uniform float uKeepSaturation; // 0..1 保留目标色相的原有饱和度
uniform float uBlackStrength;  // 0..1 非目标色相变黑的程度(0=变灰)
uniform float uFeatherPower;   // 过渡曲线幂次,>1 更陡
uniform float uEnableColorize; // 0/1 是否给目标色相重新上色
uniform vec3  uColorizeTarget; // 重新上色的目标色 RGB

// --- 视口 ---
uniform vec2  uResolution;     // 输出分辨率
uniform float uAspectRatio;    // width/height

out vec4 fragColor;

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

// 色相环上的最短距离(环绕)。h 在[0,1),返回 [0, 0.5]
float hueDistance(float a, float b) {
  float d = abs(a - b);
  return min(d, 1.0 - d);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uResolution;
  vec4 src = texture(uImageSampler, uv);
  vec3 c = src.rgb;
  float alpha = src.a;

  vec3 hsv = rgb2hsv(c);
  float h = hsv.x;
  float s = hsv.y;
  float v = hsv.z;

  // ---- 归属度计算 ----
  // dist: 目标色相的距离(0=正好,0.5=最远)
  float dist = hueDistance(h, uTargetHue);

  // 归一化:容差内的算保留,容差外的算要去色
  float inner = uHueTolerance;
  float outer = min(inner + max(uSoftness, 1e-4), 0.5);

  // smoothstep 做过渡带, 避免硬边造成的锯齿
  float t = smoothstep(inner, outer, dist);

  // 幂次:>1 让过渡更陡(接近硬边), <1 更柔和
  float grayMix = pow(clamp(t, 0.0, 1.0), max(uFeatherPower, 0.01));

  // ---- 非目标色相:去色 ----
  // Rec.709 亮度作为灰度值
  float gray = dot(c, vec3(0.2126, 0.7152, 0.0722));

  // uBlackStrength:在灰度和纯黑之间插值(做"压暗"而非单纯去色)
  vec3 desaturated = mix(vec3(gray), vec3(gray * 0.25), uBlackStrength);

  // mix(保留色, 去色, grayMix)
  vec3 outc = mix(c, desaturated, grayMix);

  // ---- 目标色相:可选重新上色 ----
  // uKeepSaturation 控制保留多少原饱和度, 1=完全保留
  if (uEnableColorize > 0.5) {
    // 把目标色相的色相替换成 uColorizeTarget 的色相, 保留原亮度
    vec3 tintHsv = rgb2hsv(uColorizeTarget);
    vec3 recolored = hsv2rgb(vec3(tintHsv.x, s * uKeepSaturation, v));
    outc = mix(outc, recolored, 1.0 - grayMix);
  } else if (uKeepSaturation < 1.0) {
    // 保留色相但压饱和度, 避免"贴上去"的假感
    vec3 partial = hsv2rgb(vec3(h, s * uKeepSaturation, v));
    outc = mix(outc, partial, 1.0 - grayMix);
  }

  fragColor = vec4(clamp(outc, 0.0, 1.0), alpha);
}

// ============================================================================
// 备选实现:OKLab 色差法(参考)
// ---------------------------------------------------------------------------
// OKLab 更贴合人眼感知,能把"相近色"也保留下来(比如蓝绿一起),
// 但需要 sRGB->OKLab 的矩阵和 cbrt,约增加 20 行。
// 什么时候该换:当用户抱怨"只留了纯绿,黄绿色被误杀了"的时候。
//
// float oklabDistance(vec3 lab1, vec3 lab2) {
//   return distance(lab1, lab2);
// }
// ============================================================================