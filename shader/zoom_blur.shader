// zoom blur shader by Charles Fettinger for obs-shaderfilter plugin 3/2019
// https://github.com/Oncorporation/obs-shaderfilter
// https://github.com/dinfinity/mpc-pixel-shaders/blob/master/PS_Zoom%20Blur.hlsl 
// Converted to OpenGL by Q-mii & Exeldro February 18, 2022

uniform int samples <
    string label = "Samples";
    string widget_type = "slider";
    int minimum = 0;
    int maximum = 100;
    int step = 1;
> = 32;

uniform float magnitude <
    string label = "Magnitude";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.001;
> = 0.5;

uniform int speed_percent <
    string label = "Speed percent";
    string widget_type = "slider";
    int minimum = 0;
    int maximum = 100;
    int step = 1;
> = 0;

uniform bool ease;
uniform bool glitch;

uniform string notes <
    string widget_type = "info";
> = "Speed Percent above zero will animate the zoom. Keep samples low to save power";

float EaseInOutCircTimer(float t, float b, float c, float d) {
    t /= d / 2;
    if (t < 1) return -c / 2 * (sqrt(1 - t * t) - 1) + b;
    t -= 2;
    return c / 2 * (sqrt(1 - t * t) + 1) + b;
}

float Styler(float t, float b, float c, float d, bool ease) {
    if (ease) return EaseInOutCircTimer(t, 0, c, d);
    return t / 2.0;  // 修改：b 范围仍为 0-1，保持动画平滑
}

float4 mainImage(VertData v_in) : TARGET {
    float4 c0 = image.Sample(textureSampler, v_in.uv);  // 获取原始颜色

    // 当 magnitude = 0.0 或 samples <= 1 时，直接返回原始颜色
    if (magnitude == 0.0 || samples <= 1) {
        return c0;
    }

    float speed = speed_percent * 0.01;
    float t = 1.0 + sin(elapsed_time * speed);  // t 范围 0-2
    float b = 0.0;
    float c = 2.0;
    float d = 2.0;

    if (glitch) t = clamp(t + ((rand_f * 2) - 1), 0.0, 2.0);
    b = Styler(t, 0, c, d, ease);  // b 范围 0-1

    float PI = 3.1415926535897932384626433832795;
    float xTrans = (v_in.uv.x * 2) - 1;
    float yTrans = 1 - (v_in.uv.y * 2);
    float angle = atan(yTrans / xTrans) + PI;
    if (sign(xTrans) == 1) {
        angle += PI;
    }
    float radius = sqrt(pow(xTrans, 2) + pow(yTrans, 2));

    float4 accumulatedColor = c0;  // 初始颜色
    int fixed_samples = max(samples, 1);  // 确保采样次数至少为 1
    for (int i = 1; i < fixed_samples; i++) {
        float currentRadius = max(0, radius - (radius / 1000 * i * magnitude * 1.5 * b));
        float2 currentCoord;
        currentCoord.x = (currentRadius * cos(angle) + 1.0) / 2.0;
        currentCoord.y = -1 * ((currentRadius * sin(angle) - 1.0) / 2.0);
        float4 currentColor = image.Sample(textureSampler, currentCoord);
        accumulatedColor += currentColor;
    }

    // 固定归一化，除以采样次数+1
    accumulatedColor /= float(fixed_samples + 1);
    accumulatedColor = clamp(accumulatedColor, 0.0, 1.0);  // 保持颜色限制
    accumulatedColor.a = 1.0;

    return accumulatedColor;
}