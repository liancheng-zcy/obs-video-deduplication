obs = obslua

-- 定义脚本描述
function script_description()
    return "一个OBS脚本，用于在固定时间内动态调整滤镜参数，实现视频去重效果。@B站大成子ONLYYOU"
end

-- 定义脚本属性（用户界面）
function script_properties()
    local props = obs.obs_properties_create()

    -- 选择需要应用滤镜的源
    local sources = obs.obs_enum_sources()
    if sources ~= nil then
        local list = obs.obs_properties_add_list(props, "source", "选择源", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
        for _, source in ipairs(sources) do
            local name = obs.obs_source_get_name(source)
            obs.obs_property_list_add_string(list, name, name)
        end
        obs.source_list_release(sources)
    end

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
    obs.obs_data_set_default_double(settings, "min_offset", -0.05)
    obs.obs_data_set_default_double(settings, "max_offset", 0.05)
    obs.obs_data_set_default_double(settings, "min_brightness", -0.05)
    obs.obs_data_set_default_double(settings, "max_brightness", 0.05)
    obs.obs_data_set_default_double(settings, "min_contrast", -0.05)
    obs.obs_data_set_default_double(settings, "max_contrast", 0.05)
    obs.obs_data_set_default_double(settings, "min_saturation", 0.95)
    obs.obs_data_set_default_double(settings, "max_saturation", 1.05)
    obs.obs_data_set_default_int(settings, "update_interval", 1000)
end

-- 全局变量
local source_name = ""
local last_update = 0
local filter = nil
local script_settings = nil

-- 生成指定范围内的随机值
function random_range(min, max)
    return min + (max - min) * math.random()
end

-- 更新滤镜参数
function update_filter()
    if filter then
        local settings = obs.obs_data_create()
        local offset = random_range(obs.obs_data_get_double(script_settings, "min_offset"), obs.obs_data_get_double(script_settings, "max_offset"))
        local brightness = random_range(obs.obs_data_get_double(script_settings, "min_brightness"), obs.obs_data_get_double(script_settings, "max_brightness"))
        local contrast = random_range(obs.obs_data_get_double(script_settings, "min_contrast"), obs.obs_data_get_double(script_settings, "max_contrast"))
        local saturation = random_range(obs.obs_data_get_double(script_settings, "min_saturation"), obs.obs_data_get_double(script_settings, "max_saturation"))
        
        obs.obs_data_set_double(settings, "offset", offset)
        obs.obs_data_set_double(settings, "brightness", brightness)
        obs.obs_data_set_double(settings, "contrast", contrast)
        obs.obs_data_set_double(settings, "saturation", saturation)
        
        obs.obs_source_update(filter, settings)
        obs.obs_data_release(settings)
        
        obs.script_log(obs.LOG_INFO, string.format("滤镜参数已更新 - 偏移: %.2f, 亮度: %.2f, 对比度: %.2f, 饱和度: %.2f", 
            offset, brightness, contrast, saturation))
    else
        obs.script_log(obs.LOG_WARNING, "未找到滤镜，无法更新参数")
    end
end

-- 脚本更新函数
function script_update(settings)
    source_name = obs.obs_data_get_string(settings, "source")
    if source_name == "" then
        obs.script_log(obs.LOG_WARNING, "请先选择一个源")
        return
    end
    
    local source = obs.obs_get_source_by_name(source_name)
    if not source then
        obs.script_log(obs.LOG_ERROR, "未找到源: " .. source_name)
        return
    end

        filter = obs.obs_source_get_filter_by_name(source, "VideoDeduplicationFilter")
        if not filter then
            local filter_settings = obs.obs_data_create()
            -- 尝试创建颜色校正滤镜
            -- 创建滤镜并检查是否成功
            filter = obs.obs_source_create_private("color_filter", "VideoDeduplicationFilter", filter_settings)
            if not filter then
                obs.script_log(obs.LOG_ERROR, "无法创建颜色校正滤镜，请确保已安装所需插件")
                obs.obs_data_release(filter_settings)
                return
            end

            -- 设置初始滤镜参数
            obs.obs_data_set_default_double(filter_settings, "offset", 0.0)
            obs.obs_data_set_default_double(filter_settings, "brightness", 0.0)
            obs.obs_data_set_default_double(filter_settings, "contrast", 0.0)
            obs.obs_data_set_default_double(filter_settings, "saturation", 1.0)

            -- 设置滤镜参数
            obs.obs_source_update(filter, filter_settings)

            -- 尝试添加滤镜到源
            local success = pcall(function()
                return obs.obs_source_filter_add(source, filter)
            end)
            
            if not success then
                obs.script_log(obs.LOG_ERROR, "无法添加滤镜到源: " .. source_name)
                obs.obs_source_release(filter)
                obs.obs_data_release(filter_settings)
                return
            end

            obs.script_log(obs.LOG_INFO, "已成功添加视频去重滤镜到: " .. source_name)
            obs.obs_data_release(filter_settings)
            -- 立即应用初始参数
            update_filter()
        else
            obs.script_log(obs.LOG_INFO, "滤镜已存在，无需重新创建")
        end
        obs.obs_source_release(source)
        obs.script_log(obs.LOG_INFO, "已成功绑定到源: " .. source_name)
        -- 立即应用初始参数
        update_filter()
    script_settings = settings
end

-- 定时器回调函数
function timer_callback()
    local current_time = os.clock() * 1000 -- 转换为毫秒
    local interval = obs.obs_data_get_int(script_settings, "update_interval")
    if current_time - last_update >= interval then
        update_filter()
        last_update = current_time
    end
end

-- 脚本加载时初始化
function script_load(settings)
    math.randomseed(os.time()) -- 初始化随机种子
    script_settings = settings
    obs.timer_add(timer_callback, 100) -- 每100毫秒检查一次
    obs.script_log(obs.LOG_INFO, "脚本已加载，定时器已启动")
end

-- 脚本卸载时清理
function script_unload()
    obs.timer_remove(timer_callback)
    if filter then
        obs.obs_source_release(filter)
    end
    obs.script_log(obs.LOG_INFO, "脚本已卸载")
end

