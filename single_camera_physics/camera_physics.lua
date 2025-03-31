obs = obslua

function script_description()
    return "模拟真实镜头的晃动和缩放模糊效果。选择视频源后生效（需配合 zoom_blur.shader）。可通过开关启用/禁用。\n作者：@B站大成子ONLYYOU\nhttps://space.bilibili.com/341867068"
end

local source_name = ""
local shake_amplitude = 3.0
local shake_frequency = 0.5
local blur_strength = 0.5
local blur_speed_factor = 0.2
local samples_value = 32
local speed_percent_value = 0
local enable_script = true
local timer = 0
local log_timer = 0
local offset_x = 0
local offset_y = 0
local last_offset_x = 0
local last_offset_y = 0
local velocity_x = 0
local velocity_y = 0
local damping = 0.95

function script_properties()
    local props = obs.obs_properties_create()
    local p = obs.obs_properties_add_list(props, "source_name", "视频源", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    local sources = obs.obs_enum_sources()
    if sources ~= nil then
        for _, source in ipairs(sources) do
            local name = obs.obs_source_get_name(source)
            obs.obs_property_list_add_string(p, name, name)
        end
    end
    obs.source_list_release(sources)
    obs.obs_properties_add_bool(props, "enable_script", "启用脚本")
    obs.obs_properties_add_float_slider(props, "shake_amplitude", "晃动幅度", 0.0, 20.0, 0.1)
    obs.obs_properties_add_float_slider(props, "shake_frequency", "晃动频率", 0.01, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, "blur_strength", "模糊强度", 0.0, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, "blur_speed_factor", "模糊速度关联度", 0.0, 1.0, 0.01)
    obs.obs_properties_add_int_slider(props, "samples_value", "采样次数", 0, 100, 1)
    obs.obs_properties_add_int_slider(props, "speed_percent_value", "动画速度 (%)", 0, 100, 1)
    return props
end

function script_defaults(settings)
    obs.obs_data_set_default_bool(settings, "enable_script", true)
    obs.obs_data_set_default_double(settings, "shake_amplitude", 3.0)
    obs.obs_data_set_default_double(settings, "shake_frequency", 0.5)
    obs.obs_data_set_default_double(settings, "blur_strength", 0.5)
    obs.obs_data_set_default_double(settings, "blur_speed_factor", 0.2)
    obs.obs_data_set_default_int(settings, "samples_value", 32)
    obs.obs_data_set_default_int(settings, "speed_percent_value", 0)
end

function script_update(settings)
    source_name = obs.obs_data_get_string(settings, "source_name")
    enable_script = obs.obs_data_get_bool(settings, "enable_script")
    shake_amplitude = obs.obs_data_get_double(settings, "shake_amplitude")
    shake_frequency = obs.obs_data_get_double(settings, "shake_frequency")
    blur_strength = obs.obs_data_get_double(settings, "blur_strength")
    blur_speed_factor = obs.obs_data_get_double(settings, "blur_speed_factor")
    samples_value = obs.obs_data_get_int(settings, "samples_value")
    speed_percent_value = obs.obs_data_get_int(settings, "speed_percent_value")
    
    local scene = obs.obs_frontend_get_current_scene()
    if scene ~= nil then
        local scene_obj = obs.obs_scene_from_source(scene)
        sceneitem = obs.obs_scene_find_source(scene_obj, source_name)
        if sceneitem ~= nil then
            local pos = obs.vec2()
            if enable_script then
                obs.vec2_set(pos, 0, 0)
            else
                obs.vec2_set(pos, 0, 0)
            end
            obs.obs_sceneitem_set_pos(sceneitem, pos)
        end
        obs.obs_source_release(scene)
    end
    
    local source = obs.obs_get_source_by_name(source_name)
    if source ~= nil then
        local filter = obs.obs_source_get_filter_by_name(source, "zoom_blur_filter")
        if filter ~= nil then
            local filter_settings = obs.obs_data_create()
            if enable_script then
                obs.obs_data_set_double(filter_settings, "magnitude", blur_strength)
                obs.obs_data_set_int(filter_settings, "samples", math.max(samples_value, 1))
                obs.obs_data_set_int(filter_settings, "speed_percent", speed_percent_value)
            else
                obs.obs_data_set_double(filter_settings, "magnitude", 0.0)
                obs.obs_data_set_int(filter_settings, "samples", 1)
                obs.obs_data_set_int(filter_settings, "speed_percent", 0)
            end
            obs.obs_source_update(filter, filter_settings)
            obs.obs_data_release(filter_settings)
        end
        obs.obs_source_release(source)
    end
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

function script_tick(seconds)
    if not enable_script then return end
    
    timer = timer + seconds
    log_timer = log_timer + seconds
    
    local dynamic_amplitude = shake_amplitude * (0.8 + math.sin(timer * 0.5) * 0.2)
    local force_x = math.random(-dynamic_amplitude, dynamic_amplitude) * 0.05
    local force_y = math.random(-dynamic_amplitude, dynamic_amplitude) * 0.05
    
    velocity_x = (velocity_x + force_x) * damping
    velocity_y = (velocity_y + force_y) * damping
    offset_x = offset_x + velocity_x
    offset_y = offset_y + velocity_y
    
    offset_x = math.max(math.min(offset_x, dynamic_amplitude), -dynamic_amplitude)
    offset_y = math.max(math.min(offset_y, dynamic_amplitude), -dynamic_amplitude)
    
    if sceneitem ~= nil then
        local pos = obs.vec2()
        obs.vec2_set(pos, offset_x, offset_y)
        obs.obs_sceneitem_set_pos(sceneitem, pos)
    end
    
    local source = obs.obs_get_source_by_name(source_name)
    if source ~= nil then
        local filter = obs.obs_source_get_filter_by_name(source, "zoom_blur_filter")
        if filter ~= nil then
            local settings = obs.obs_data_create()
            local speed = math.sqrt(velocity_x^2 + velocity_y^2) / seconds
            local blur_increment = math.sqrt(speed) * 0.075 * blur_speed_factor  -- 修改：从 0.05 提高到 0.075，加快模糊响应
            local dynamic_blur = blur_strength + blur_increment
            dynamic_blur = math.min(math.max(dynamic_blur, 0.0), 1.0)
            obs.obs_data_set_double(settings, "magnitude", dynamic_blur)
            obs.obs_data_set_int(settings, "samples", math.max(samples_value, 1))
            obs.obs_data_set_int(settings, "speed_percent", speed_percent_value)
            obs.obs_source_update(filter, settings)
            
            if log_timer >= 1.0 then
                print("Dynamic blur: " .. dynamic_blur .. ", Speed: " .. speed)
                log_timer = 0
            end
            
            obs.obs_data_release(settings)
        else
            if log_timer >= 1.0 then
                print("Filter 'zoom_blur_filter' not found!")
                log_timer = 0
            end
        end
        obs.obs_source_release(source)
    end
    
    last_offset_x = offset_x
    last_offset_y = offset_y
end

function script_load(settings)
    timer = 0
    log_timer = 0
    offset_x = 0
    offset_y = 0
    last_offset_x = 0
    last_offset_y = 0
    velocity_x = 0
    velocity_y = 0
    script_update(settings)
end

function script_unload()
end