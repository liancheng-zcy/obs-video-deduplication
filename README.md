# OBS视频特效脚本 - 详细说明文档

## 独立插件

### 1. camera_physics.lua 插件
#### 功能概述
- 模拟真实相机抖动效果
- 可调节晃动幅度和频率
- 支持缩放模糊效果
- 提供开关控制，实时启用/禁用效果
- 支持模糊和晃动解耦

#### 安装步骤
1. 下载 camera_physics.lua 文件
2. 打开 OBS Studio
3. 导航至 "工具" -> "脚本"
4. 点击"+"号添加新脚本
5. 选择下载的 camera_physics.lua 文件
6. 安装 OBS ShaderFilter 插件：
   - 下载地址：https://github.com/exeldro/obs-shaderfilter/releases
   - 安装路径：下一步下一步安装即可
7. 下载 zoom_blur.shader 文件并放置在 shader 目录下（使用我优化过后的zoom_blur.shader,在文件夹shader里）

### 2. video_color.lua 插件
#### 功能概述
- 动态调整视频色彩参数
- 参数范围可自定义
- 支持平滑过渡效果
- 提供开关控制，实时启用/禁用滤镜

#### 安装步骤
1. 下载 video_color.lua 文件
2. 打开 OBS Studio
3. 导航至 "工具" -> "脚本"
4. 点击"+"号添加新脚本
5. 选择下载的 video_color.lua 文件

## 组合插件
#### 功能概述
- 同时包含镜头晃动和视频去重效果
- 参数可独立调节
- 支持效果叠加
![组合插件](https://hv.z.wiki/autoupload/20250331/C30D/1578X1888/Snipaste-2025-03-31-14-20-37.png)
#### 安装步骤
1. 下载 combine_real_time_deduplication 文件夹
2. 打开 OBS Studio
3. 导航至 "工具" -> "脚本"
4. 点击"+"号添加新脚本
5. 选择 video_effects.lua 文件
6. 确保已安装 OBS ShaderFilter 插件和 zoom_blur.shader 文件

## 文件结构
```
.gitignore
README.md
test.html
combine_real_time_deduplication/
  key.py
  last_run.txt
  license.key
  video_effects.lua
shader/
  zoom_blur.shader
single_camera_physics/
  camera_physics_key.lua
  camera_physics_obfuscated.lua
  camera_physics.lua
single_video_color/
  video_color_key_obfuscated.lua
  video_color_key.lua
  video_color.lua
static/
  知识星球.jpg
  camera_physics.png
  video_color.png
  zoom_blur_shader.png
```

## 许可证验证
- 使用license.key文件进行功能验证
- 包含异或解密和简单哈希验证机制
- 检测时间篡改以防止绕过许可证
- 未激活时功能受限

## 安装与使用
1. 下载脚本文件
2. 打开OBS Studio
3. 导航至 "工具" -> "脚本"
4. 点击"+"号添加新脚本
5. 选择下载的Lua脚本文件

## 注意事项
- 使用zoom_blur.shader需要安装OBS ShaderFilter插件
- 参数调整建议逐步进行，避免突变
- 可根据实际需求调整参数范围
- 高采样次数或动画速度可能增加GPU负载

## 维护者
B站： @大成子ONLYYOU https://space.bilibili.com/341867068

加入知识星球获取更多好货
![video_color](https://cdn.z.wiki/autoupload/20250325/2lGz/1125X1676/%E7%9F%A5%E8%AF%86%E6%98%9F%E7%90%83.jpg)
