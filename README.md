# OBS视频特效脚本

## 概述 Overview
本仓库包含两个用于OBS Studio的Lua脚本：
1. camera_physics.lua - 模拟真实镜头的晃动和缩放模糊效果
2. video_color.lua - 动态调整滤镜参数实现视频去重效果

## 功能描述 Features

### camera_physics.lua
- 模拟真实相机抖动效果
- 可调节晃动幅度和频率
- 支持缩放模糊效果
- 提供开关控制，实时启用/禁用效果

![camera_physics](https://liancheng-zcy.github.io/obs-video-deduplication/static/camera_physics.png)

- 如何配合zoom_blur.shader 使用？ 
  - 首先安装OBS ShaderFilter，可直接到releases界面使用exe文件进行安装。安装之后的路径在obs根目录下的[path\to\obs-studio\data\obs-plugins\obs-shaderfilter]
  - zoom_blur.shader位于[path\to\obs-studio\data\obs-plugins\obs-shaderfilter\examples]
  -在OBS里添加滤镜

![zoom_blur_shader](https://liancheng-zcy.github.io/obs-video-deduplication/static/zoom_blur_shader.png)

### video_color.lua
- 动态调整视频色彩参数
- 参数范围可自定义
- 支持平滑过渡效果
- 提供开关控制，实时启用/禁用滤镜

![video_color](https://liancheng-zcy.github.io/obs-video-deduplication/static/video_color.png)


## 安装方法 Installation
1. 下载脚本文件
2. 打开OBS Studio
3. 导航至 "工具" -> "脚本"
4. 点击"+"号添加新脚本
5. 选择下载的Lua脚本文件

## 使用方法 Usage
### camera_physics.lua
1. 添加脚本后选择目标视频源
2. 调节晃动参数：
   - 晃动幅度
   - 晃动频率
   - 模糊强度
3. 使用开关启用/禁用效果

### video_color.lua
1. 添加脚本后选择目标视频源
2. 设置参数范围：
   - 亮度
   - 对比度
   - 饱和度
   - 色彩偏移
3. 设置更新间隔
4. 使用开关启用/禁用滤镜

## 注意事項 Notes
- 使用zoom_blur.shader需要安装OBS ShaderFilter插件, 感谢OBS ShaderFilter提供的模糊晃动效果。https://github.com/exeldro/obs-shaderfilter
- 参数调整建议逐步进行，避免突变
- 可根据实际需求调整参数范围

## 维护者 Maintainer
B站： @大成子ONLYYOU https://space.bilibili.com/341867068
