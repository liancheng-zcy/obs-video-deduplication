obs = obslua

-- 定义脚本描述
function script_description()
    return "一个OBS脚本，用于在固定时间内动态调整滤镜参数，实现视频去重效果。最佳时间请根据视频素材的情况调整\n@B站大成子ONLYYOU\nhttps://space.bilibili.com/341867068"
end

-- 定义脚本属性（用户界面）
function script_properties()
    local props = obs.obs_properties_create()

    -- 选择需要应用滤镜的源（只列出视频类源）
    local sources = obs.obs_enum_sources()
    if sources ~= nil then
        local list = obs.obs_properties_add_list(props, "source", "选择视频源", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
        obs.obs_property_list_add_string(list, "", "") -- 添加空选项
        for _, source in ipairs(sources) do
            local name = obs.obs_source_get_name(source)
            local source_type = obs.obs_source_get_type(source)
            local flags = obs.obs_source_get_output_flags(source)
            -- 只添加包含视频输出的源（排除纯音频源）
            if bit.band(flags, obs.OBS_SOURCE_VIDEO) ~= 0 and source_type ~= obs.OBS_SOURCE_TYPE_SCENE then
                obs.obs_property_list_add_string(list, name, name)
            end
        end
        obs.source_list_release(sources)
    end

    -- 添加启用/禁用开关
    obs.obs_properties_add_bool(props, "enabled", "启用动态色彩滤镜")

    -- 参数调整范围
    obs.obs_properties_add_float_slider(props, "min_offset", "最小偏移值", -1.0, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, "max_offset", "最大偏移值", -1.0, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, "min_brightness", "最小亮度", -1.0, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, "max_brightness", "最大亮度", -1.0, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, "min_contrast", "最小对比度", -1.0, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, "max_contrast", "最大对比度", -1.0, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, "min_saturation", "最小饱和度", 0.0, 2.0, 0.01)
    obs.obs_properties_add_float_slider(props, "max_saturation", "最大饱和度", 0.0, 2.0, 0.01)

    -- 更新时间间隔
    obs.obs_properties_add_int(props, "update_interval", "更新时间 (毫秒)", 100, 10000, 100)

    return props
end

-- 设置默认参数值
function script_defaults(settings)
    obs.obs_data_set_default_bool(settings, "enabled", true)
    obs.obs_data_set_default_double(settings, "min_offset", -0.02)
    obs.obs_data_set_default_double(settings, "max_offset", 0.02)
    obs.obs_data_set_default_double(settings, "min_brightness", -0.02)
    obs.obs_data_set_default_double(settings, "max_brightness", 0.02)
    obs.obs_data_set_default_double(settings, "min_contrast", -0.02)
    obs.obs_data_set_default_double(settings, "max_contrast", 0.02)
    obs.obs_data_set_default_double(settings, "min_saturation", 0.98)
    obs.obs_data_set_default_double(settings, "max_saturation", 1.02)
    obs.obs_data_set_default_int(settings, "update_interval", 2000)
end

-- 全局变量
local source_name = ""
local last_update = 0
local filter = nil
local script_settings = nil
local current_params = {offset = 0, brightness = 0, contrast = 0, saturation = 1}
local target_params = {offset = 0, brightness = 0, contrast = 0, saturation = 1}
local transition_time = 0
local transition_duration = 500 -- 过渡时间（毫秒）

-- 生成指定范围内的随机值
function random_range(min, max)
    return min + (max - min) * math.random()
end

-- 重置参数到默认值
function reset_params()
    current_params.offset = 0
    current_params.brightness = 0
    current_params.contrast = 0
    current_params.saturation = 1
    target_params.offset = 0
    target_params.brightness = 0
    target_params.contrast = 0
    target_params.saturation = 1
    transition_time = 0
end

-- 更新滤镜参数
function update_filter()
    if not filter then return end

    local settings = obs.obs_data_create()
    obs.obs_data_set_double(settings, "color_add", current_params.offset)
    obs.obs_data_set_double(settings, "brightness", current_params.brightness)
    obs.obs_data_set_double(settings, "contrast", current_params.contrast)
    obs.obs_data_set_double(settings, "saturation", current_params.saturation)
    obs.obs_source_update(filter, settings)
    obs.obs_data_release(settings)

    obs.script_log(obs.LOG_INFO, string.format("滤镜参数已更新 - 偏移: %.2f, 亮度: %.2f, 对比度: %.2f, 饱和度: %.2f", 
        current_params.offset, current_params.brightness, current_params.contrast, current_params.saturation))
end

-- 设置新的目标参数
function set_new_target_params()
    target_params.offset = random_range(obs.obs_data_get_double(script_settings, "min_offset"), obs.obs_data_get_double(script_settings, "max_offset"))
    target_params.brightness = random_range(obs.obs_data_get_double(script_settings, "min_brightness"), obs.obs_data_get_double(script_settings, "max_brightness"))
    target_params.contrast = random_range(obs.obs_data_get_double(script_settings, "min_contrast"), obs.obs_data_get_double(script_settings, "max_contrast"))
    target_params.saturation = random_range(obs.obs_data_get_double(script_settings, "min_saturation"), obs.obs_data_get_double(script_settings, "max_saturation"))
    transition_time = 0
end

-- 创建滤镜
function create_filter(source)
    if filter then
        obs.obs_source_release(filter)
        filter = nil
    end

    local filter_settings = obs.obs_data_create()
    filter = obs.obs_source_create("color_filter", "VideoDeduplicationFilter", filter_settings, nil)
    if not filter then
        obs.script_log(obs.LOG_ERROR, "无法创建颜色校正滤镜，请确保OBS支持此滤镜")
        obs.obs_data_release(filter_settings)
        return false
    end

    obs.obs_source_filter_add(source, filter)
    obs.obs_data_release(filter_settings)
    obs.script_log(obs.LOG_INFO, "已成功创建并添加滤镜到源: " .. source_name)
    return true
end

-- 脚本更新函数
function script_update(settings)
    script_settings = settings
    local new_source_name = obs.obs_data_get_string(settings, "source")
    local enabled = obs.obs_data_get_bool(settings, "enabled")

    if new_source_name == "" then
        obs.script_log(obs.LOG_WARNING, "请先选择一个视频源")
        if filter then
            local old_source = obs.obs_get_source_by_name(source_name)
            if old_source then
                obs.obs_source_filter_remove(old_source, filter)
                obs.obs_source_release(old_source)
            end
            obs.obs_source_release(filter)
            filter = nil
        end
        source_name = ""
        return
    end

    -- 如果源发生变化
    if new_source_name ~= source_name then
        source_name = new_source_name
        local source = obs.obs_get_source_by_name(source_name)
        if not source then
            obs.script_log(obs.LOG_ERROR, "未找到源: " .. source_name)
            return
        end

        -- 如果已有滤镜，移除旧滤镜
        if filter then
            local old_source = obs.obs_get_source_by_name(source_name)
            if old_source then
                obs.obs_source_filter_remove(old_source, filter)
                obs.obs_source_release(old_source)
            end
            obs.obs_source_release(filter)
            filter = nil
        end

        -- 重置参数
        reset_params()

        -- 如果启用，则创建新滤镜
        if enabled then
            if create_filter(source) then
                set_new_target_params()
                update_filter()
            end
        end
        obs.obs_source_release(source)
    -- 如果只是启用/禁用状态变化
    elseif enabled and not filter then
        local source = obs.obs_get_source_by_name(source_name)
        if source and create_filter(source) then
            set_new_target_params()
            update_filter()
        end
        if source then obs.obs_source_release(source) end
    elseif not enabled and filter then
        local source = obs.obs_get_source_by_name(source_name)
        if source then
            obs.obs_source_filter_remove(source, filter)
            obs.obs_source_release(source)
        end
        obs.obs_source_release(filter)
        filter = nil
        obs.script_log(obs.LOG_INFO, "滤镜已禁用并移除")
    end
end

-- 定时器回调函数（实现平滑过渡）
function timer_callback()
    if not filter or not script_settings or not obs.obs_data_get_bool(script_settings, "enabled") then return end

    local current_time = os.clock() * 1000
    local interval = obs.obs_data_get_int(script_settings, "update_interval")

    -- 更新过渡参数
    if transition_time < transition_duration then
        transition_time = transition_time + 100
        local t = math.min(transition_time / transition_duration, 1)
        current_params.offset = current_params.offset + (target_params.offset - current_params.offset) * t
        current_params.brightness = current_params.brightness + (target_params.brightness - current_params.brightness) * t
        current_params.contrast = current_params.contrast + (target_params.contrast - current_params.contrast) * t
        current_params.saturation = current_params.saturation + (target_params.saturation - current_params.saturation) * t
        update_filter()
    end

    -- 检查是否需要生成新目标参数
    if current_time - last_update >= interval then
        set_new_target_params()
        last_update = current_time
    end
end

-- 脚本加载时初始化
function script_load(settings)
    math.randomseed(os.time())
    script_settings = settings
    obs.timer_add(timer_callback, 100)
    obs.script_log(obs.LOG_INFO, "脚本已加载，定时器已启动")
end

-- 脚本卸载时清理
function script_unload()
    obs.timer_remove(timer_callback)
    if filter then
        local source = obs.obs_get_source_by_name(source_name)
        if source then
            obs.obs_source_filter_remove(source, filter)
            obs.obs_source_release(source)
        end
        obs.obs_source_release(filter)
        filter = nil
    end
    obs.script_log(obs.LOG_INFO, "脚本已卸载")
end