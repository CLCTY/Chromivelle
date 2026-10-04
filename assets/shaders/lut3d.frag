// ============================================================================
// lut3d.frag — 3D LUT (.cube) 应用
//
// LUT 以 2D 切片图形式上传(标准做法),shader 里手算三线性插值。
// 之所以不用硬件三线性过滤:sRGB 色彩空间下必须在线性插值,
// 而 GPU 对 8bit 纹理默认是 sRGB 感知插值,结果会偏。
// 所以自己算,保证颜色正确。
//
// uniform 布局必须与 lib/core/shader/uniform_block.dart 严格一致。
// ============================================================================

#include <flutter/runtime_effect.glsl>

uniform sampler2D uImageSampler;  // 原图
uniform sampler2D uLutTexture;  // LUT 2D 切片图(N x N*N)
uniform float uLutSize;        // N,例如 17/33/65
uniform float uLutIntensity;   // 0..1 混合强度
uniform float uLutEnabled;     // 0/1

// --- 视口 ---
uniform vec2  uResolution;     // 输出分辨率
uniform float uAspectRatio;    // width/height

out vec4 fragColor;

// sRGB -> 线性(插值必须在��性空间)
vec3 srgbToLinear(vec3 c) {
  return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}
vec3 linearToSrgb(vec3 c) {
  return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055,
             step(0.0031308, c));
}

// 读取 LUT:输入 rgb(0..1)和切片层 z,返回该点的 LUT 值
vec3 sampleLut(vec3 rgb, float z) {
  float n = uLutSize;
  float sliceSize = 1.0 / n;                  // 每个 b 切片在2D 图里的高度占比

  // b 通道切片索引与切片内坐标
  float zPos = clamp(z, 0.0, 1.0) * (n - 1.0);
  float z0 = floor(zPos);
  float zFrac = zPos - z0;

  // 切片内的 x,y(绿红在切片内)
  vec2 inSlice = clamp(rgb.xy, 0.0, 1.0) * ((n - 1.0) / n) + (0.5 / n);

  // 采样 z0 和 z1 两层
  float v0 = (z0 + inSlice.y) * sliceSize;
  float v1 = (min(z0 + 1.0, n - 1.0) + inSlice.y) * sliceSize;

  vec3 c0 = texture(uLutTexture, vec2(inSlice.x, v0 + sliceSize * 0.5)).rgb;
  vec3 c1 = texture(uLutTexture, vec2(inSlice.x, v1 + sliceSize * 0.5)).rgb;

  // 在线性空间插值(关键:色带会少很多)
  vec3 lin0 = srgbToLinear(c0);
  vec3 lin1 = srgbToLinear(c1);
  return linearToSrgb(mix(lin0, lin1, zFrac));
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uResolution;
  vec4 src = texture(uImageSampler, uv);
  vec3 c = src.rgb;

  if (uLutEnabled < 0.5) {
    fragColor = src;
    return;
  }

  vec3 graded = sampleLut(c, c.b);
  fragColor = vec4(mix(c, graded, clamp(uLutIntensity, 0.0, 1.0)), src.a);
}