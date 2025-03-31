obs = obslua

-- 动态获取脚本目录
local script_dir = script_path():match("(.*[/\\])")
local license_file_path = script_dir .. "license.key"
local last_time_file = script_dir .. "last_run.txt"
local license_expiration_date = "请激活使用完整功能，未激活只能看到轻微的晃动和模糊，色彩不生效"
local license_valid = false

-- 异或操作
local function xor(a, b)
    local result = 0
    local bit = 1
    for i = 0, 7 do
        local bit_a = (a % 2)
        local bit_b = (b % 2)
        if bit_a ~= bit_b then
            result = result + bit
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        bit = bit * 2
    end
    return result
end

local function xor_decrypt(data, key)
    local result = ""
    for i = 1, #data do
        local byte = string.byte(data, i)
        local key_byte = string.byte(key, (i - 1) % #key + 1)
        result = result .. string.char(xor(byte, key_byte))
    end
    return result
end

-- 哈希函数
local function simple_hash(str)
    local hash = 0
    for i = 1, #str do
        hash = (hash * 31 + string.byte(str, i)) % 2^32
    end
    return tostring(hash)
end

-- 许可证验证
local function verify_license(file_path)
    local file = io.open(file_path, "r")
    if not file then
        print("许可证文件未找到！请将 license.key 放入脚本目录。")
        return false
    end
    local content = file:read("*all")
    file:close()

    local encrypted_data, checksum = content:match("([^:]+):([^:]+)")
    if not encrypted_data or not checksum then
        print("许可证格式错误！")
        return false
    end

    local expected_checksum = simple_hash(encrypted_data)
    if checksum ~= expected_checksum then
        print("许可证文件被篡改！功能受限。")
        return false
    end

    local key = "Kj9pL2mNx7vQ4tRwY8zB5cF1dH3gJ6k"
    local decrypted_data = xor_decrypt(encrypted_data, key)
    local user_id, expiration = decrypted_data:match("([^:]+):([^:]+)")
    if not user_id or not expiration then
        print("许可证解密失败！")
        return false
    end

    local expiration_time = tonumber(expiration)
    if not expiration_time then
        print("许可证到期时间格式错误！")
        return false
    end

    local date_table = os.date("*t", expiration_time)
    license_expiration_date = string.format("%04d-%02d-%02d", date_table.year, date_table.month, date_table.day)
    print("许可证到期时间: " .. license_expiration_date)
    local current_time = os.time()
    return current_time <= expiration_time
end

-- 时间篡改检测
local last_check_time = 0
local time_check_interval = 10
local time_tampering_detected = false
local function check_time_tampering()
    local current_time = os.time()
    if current_time - last_check_time < time_check_interval then
        return not time_tampering_detected
    end
    last_check_time = current_time

    local file = io.open(last_time_file, "r")
    if file then
        local stored_time = tonumber(file:read("*all")) or 0
        file:close()
        if current_time < stored_time then
            print("检测到时间篡改！功能受限。")
            time_tampering_detected = true
            return false
        end
    end

    file = io.open(last_time_file, "w")
    if file then
        file:write(tostring(current_time))
        file:close()
    end
    return true
end

-- 脚本描述
function script_description()
    return "视频滤镜去重与晃动模糊效果脚本V1.0\n" ..
           "安装步骤：\n" ..
           "1.将 license.key 放入脚本目录。\n" ..
           "2 晃动模糊效果请添加名为 'zoom_blur_filter' 的用户定义着色器滤镜并选择 zoom_blur.shader，否则不生效。\n" ..
           "____________________________________________________________________________________________\n" ..
           "到期时间：" .. license_expiration_date .. "\n" ..
           "联系方式：V:LiAnChenglac/@B站大成子ONLYYO"
end

-- 脚本属性
function script_properties()
    local props = obs.obs_properties_create()
    local source_list = obs.obs_properties_add_list(props, "source", "视频源", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    obs.obs_property_list_add_string(source_list, "", "")
    local sources = obs.obs_enum_sources()
    if sources then
        for _, source in ipairs(sources) do
            local name = obs.obs_source_get_name(source)
            if bit.band(obs.obs_source_get_output_flags(source), obs.OBS_SOURCE_VIDEO) ~= 0 then
                obs.obs_property_list_add_string(source_list, name, name)
            end
        end
        obs.source_list_release(sources)
    end

    -- 滤镜去重属性
    obs.obs_properties_add_bool(props, "dedup_enabled", "启用滤镜去重滤镜")
    obs.obs_properties_add_bool(props, "dedup_enable_offset", "启用偏移调整")
    obs.obs_properties_add_bool(props, "dedup_enable_brightness", "启用亮度调整")
    obs.obs_properties_add_bool(props, "dedup_enable_contrast", "启用对比度调整")
    obs.obs_properties_add_bool(props, "dedup_enable_saturation", "启用饱和度调整")
    obs.obs_properties_add_float_slider(props, "dedup_min_offset", "最小偏移值", -1.0, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, "dedup_max_offset", "最大偏移值", -1.0, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, "dedup_min_brightness", "最小亮度", -1.0, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, "dedup_max_brightness", "最大亮度", -1.0, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, "dedup_min_contrast", "最小对比度", -1.0, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, "dedup_max_contrast", "最大对比度", -1.0, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, "dedup_min_saturation", "最小饱和度", 0.0, 2.0, 0.01)
    obs.obs_properties_add_float_slider(props, "dedup_max_saturation", "最大饱和度", 0.0, 2.0, 0.01)
    obs.obs_properties_add_int(props, "dedup_update_interval", "色彩去重更新间隔 (毫秒)", 100, 10000, 100)

    -- 晃动模糊属性
    obs.obs_properties_add_bool(props, "shake_enabled", "启用晃动模糊效果")
    obs.obs_properties_add_float_slider(props, "shake_amplitude", "晃动幅度", 0.0, 20.0, 0.1)
    obs.obs_properties_add_float_slider(props, "shake_frequency", "晃动频率", 0.01, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, "shake_blur_strength", "模糊强度（模糊）", 0.0, 1.0, 0.01)
    obs.obs_properties_add_int_slider(props, "shake_samples_value", "采样次数（模糊）", 0, 100, 1)
    obs.obs_properties_add_int_slider(props, "shake_speed_percent_value", "动画速度（模糊） (%)", 0, 100, 1)
    obs.obs_properties_add_float_slider(props, "shake_blur_speed_factor", "模糊晃动关联度", 0.0, 1.0, 0.01)

    return props
end

-- 默认参数
function script_defaults(settings)
    obs.obs_data_set_default_bool(settings, "dedup_enabled", true)
    obs.obs_data_set_default_bool(settings, "dedup_enable_offset", true)
    obs.obs_data_set_default_bool(settings, "dedup_enable_brightness", true)
    obs.obs_data_set_default_bool(settings, "dedup_enable_contrast", true)
    obs.obs_data_set_default_bool(settings, "dedup_enable_saturation", true)
    obs.obs_data_set_default_double(settings, "dedup_min_offset", -0.01)
    obs.obs_data_set_default_double(settings, "dedup_max_offset", 0.01)
    obs.obs_data_set_default_double(settings, "dedup_min_brightness", -0.05)
    obs.obs_data_set_default_double(settings, "dedup_max_brightness", 0.05)
    obs.obs_data_set_default_double(settings, "dedup_min_contrast", -0.03)
    obs.obs_data_set_default_double(settings, "dedup_max_contrast", 0.03)
    obs.obs_data_set_default_double(settings, "dedup_min_saturation", 0.99)
    obs.obs_data_set_default_double(settings, "dedup_max_saturation", 1.03)
    obs.obs_data_set_default_int(settings, "dedup_update_interval", 2000)

    obs.obs_data_set_default_bool(settings, "shake_enabled", true)
    obs.obs_data_set_default_double(settings, "shake_amplitude", 3.0)
    obs.obs_data_set_default_double(settings, "shake_frequency", 0.5)
    obs.obs_data_set_default_double(settings, "shake_blur_strength", 0.5)
    obs.obs_data_set_default_double(settings, "shake_blur_speed_factor", 0.2)
    obs.obs_data_set_default_int(settings, "shake_samples_value", 32)
    obs.obs_data_set_default_int(settings, "shake_speed_percent_value", 0)
end

-- 全局变量
local source_name = ""
local dedup_last_update = 0
local dedup_filter = nil
local settings = nil
local dedup_current_params = {offset = 0, brightness = 0, contrast = 0, saturation = 1}
local dedup_target_params = {offset = 0, brightness = 0, contrast = 0, saturation = 1}
local dedup_transition_time = 0
local dedup_transition_duration = 1000
local dedup_log_timer = 0
local shake_amplitude = 3.0
local shake_frequency = 0.5
local shake_blur_strength = 0.5
local shake_blur_speed_factor = 0.2
local shake_samples_value = 32
local shake_speed_percent_value = 0
local shake_enabled = true
local shake_timer = 0
local shake_log_timer = 0
local shake_offset_x = 0
local shake_offset_y = 0
local shake_velocity_x = 0
local shake_velocity_y = 0
local shake_damping = 0.95
local shake_sceneitem = nil

-- 工具函数
local function random_range(min, max)
    return min + (max - min) * math.random()
end

-- 滤镜去重函数
local function dedup_all_adjustments_disabled()
    if not settings then return true end
    return not obs.obs_data_get_bool(settings, "dedup_enable_offset") and
           not obs.obs_data_get_bool(settings, "dedup_enable_brightness") and
           not obs.obs_data_get_bool(settings, "dedup_enable_contrast") and
           not obs.obs_data_get_bool(settings, "dedup_enable_saturation")
end

local function dedup_update_filter()
    if not dedup_filter or not settings then
        print("[滤镜去重] 滤镜或设置未初始化，跳过更新")
        return
    end

    if not obs.obs_data_get_bool(settings, "dedup_enabled") or dedup_all_adjustments_disabled() then
        local source = obs.obs_get_source_by_name(source_name)
        if source and dedup_filter then
            obs.obs_source_filter_remove(source, dedup_filter)
            obs.obs_source_release(source)
        end
        if dedup_filter then
            obs.obs_source_release(dedup_filter)
            dedup_filter = nil
            print("[滤镜去重] 去重滤镜已关闭并移除")
        end
        return
    end

    dedup_log_timer = dedup_log_timer + 100
    if dedup_log_timer >= 2000 then
        local offset_status = obs.obs_data_get_bool(settings, "dedup_enable_offset") and "开启" or "关闭"
        local brightness_status = obs.obs_data_get_bool(settings, "dedup_enable_brightness") and "开启" or "关闭"
        local contrast_status = obs.obs_data_get_bool(settings, "dedup_enable_contrast") and "开启" or "关闭"
        local saturation_status = obs.obs_data_get_bool(settings, "dedup_enable_saturation") and "开启" or "关闭"
        print(string.format("[滤镜去重] 参数状态 - 偏移: %s, 亮度: %s, 对比度: %s, 饱和度: %s", offset_status, brightness_status, contrast_status, saturation_status))
    end

    if not obs.obs_data_get_bool(settings, "dedup_enable_offset") then dedup_current_params.offset = 0 end
    if not obs.obs_data_get_bool(settings, "dedup_enable_brightness") then dedup_current_params.brightness = 0 end
    if not obs.obs_data_get_bool(settings, "dedup_enable_contrast") then dedup_current_params.contrast = 0 end
    if not obs.obs_data_get_bool(settings, "dedup_enable_saturation") then dedup_current_params.saturation = 1 end

    local filter_settings = obs.obs_data_create()
    obs.obs_data_set_double(filter_settings, "color_add", dedup_current_params.offset)
    obs.obs_data_set_double(filter_settings, "brightness", dedup_current_params.brightness)
    obs.obs_data_set_double(filter_settings, "contrast", dedup_current_params.contrast)
    obs.obs_data_set_double(filter_settings, "saturation", dedup_current_params.saturation)
    obs.obs_source_update(dedup_filter, filter_settings)
    obs.obs_data_release(filter_settings)

    if dedup_log_timer >= 2000 then
        print(string.format("[滤镜去重] 滤镜参数 - 偏移: %.4f, 亮度: %.4f, 对比度: %.4f, 饱和度: %.4f",
            dedup_current_params.offset, dedup_current_params.brightness, dedup_current_params.contrast, dedup_current_params.saturation))
        dedup_log_timer = 0
    end
end

local function dedup_create_filter(source)
    if not source then
        print("[滤镜去重] 无效视频源")
        return false
    end
    if dedup_filter then
        print("[滤镜去重] 滤镜已存在，跳过创建")
        return true
    end
    local filter_settings = obs.obs_data_create()
    dedup_filter = obs.obs_source_create("color_filter", "VideoDeduplicationFilter", filter_settings, nil)
    if not dedup_filter then
        print("[滤镜去重] 无法创建滤镜")
        obs.obs_data_release(filter_settings)
        return false
    end
    obs.obs_source_filter_add(source, dedup_filter)
    obs.obs_data_release(filter_settings)
    print("[滤镜去重] 滤镜创建成功")
    return true
end

-- 晃动模糊函数
local function shake_update_filter(source)
    if not source then return end
    local filter = obs.obs_source_get_filter_by_name(source, "zoom_blur_filter")
    if not filter then
        if shake_log_timer >= 1.0 then
            print("[晃动模糊] 未找到 'zoom_blur_filter' 滤镜，请添加并选择 zoom_blur.shader")
            shake_log_timer = 0
        end
        return
    end

    local filter_settings = obs.obs_data_create()
    if shake_enabled and license_valid then
        local speed = math.sqrt(shake_velocity_x^2 + shake_velocity_y^2) / 0.1
        local blur_increment = math.sqrt(speed) * 0.075 * shake_blur_speed_factor
        local dynamic_blur = shake_blur_strength + blur_increment
        dynamic_blur = math.min(math.max(dynamic_blur, 0.0), 1.0)
        obs.obs_data_set_double(filter_settings, "magnitude", dynamic_blur)
        obs.obs_data_set_int(filter_settings, "samples", math.max(shake_samples_value, 1))
        obs.obs_data_set_int(filter_settings, "speed_percent", shake_speed_percent_value)

        if shake_log_timer >= 1.0 then
            print(string.format("[晃动模糊] 动态模糊: %.4f, 速度: %.4f", dynamic_blur, speed))
            shake_log_timer = 0
        end
    else
        obs.obs_data_set_double(filter_settings, "magnitude", 0.0)
        obs.obs_data_set_int(filter_settings, "samples", 1)
        obs.obs_data_set_int(filter_settings, "speed_percent", 0)
        if shake_log_timer >= 1.0 then
            print("[晃动模糊] 晃动模糊效果已关闭")
            shake_log_timer = 0
        end
    end
    obs.obs_source_update(filter, filter_settings)
    obs.obs_data_release(filter_settings)
    obs.obs_source_release(filter)
end

-- 脚本更新
function script_update(settings_data)
    settings = settings_data

    -- 更新视频源
    local new_source = obs.obs_data_get_string(settings, "source")
    if new_source ~= source_name then
        source_name = new_source
        if dedup_filter then
            local old_source = obs.obs_get_source_by_name(source_name)
            if old_source then
                obs.obs_source_filter_remove(old_source, dedup_filter)
                obs.obs_source_release(old_source)
            end
            obs.obs_source_release(dedup_filter)
            dedup_filter = nil
        end
        local source = obs.obs_get_source_by_name(source_name)
        if source then
            if obs.obs_data_get_bool(settings, "dedup_enabled") and not dedup_all_adjustments_disabled() and license_valid then
                dedup_create_filter(source)
            end
            shake_update_filter(source)
            obs.obs_source_release(source)
        end
    end

    -- 更新晃动模糊参数
    shake_enabled = obs.obs_data_get_bool(settings, "shake_enabled")
    shake_amplitude = obs.obs_data_get_double(settings, "shake_amplitude")
    shake_frequency = obs.obs_data_get_double(settings, "shake_frequency")
    shake_blur_strength = obs.obs_data_get_double(settings, "shake_blur_strength")
    shake_blur_speed_factor = obs.obs_data_get_double(settings, "shake_blur_speed_factor")
    shake_samples_value = obs.obs_data_get_int(settings, "shake_samples_value")
    shake_speed_percent_value = obs.obs_data_get_int(settings, "shake_speed_percent_value")

    local source = obs.obs_get_source_by_name(source_name)
    if source then
        dedup_update_filter() -- 检查开关状态并移除滤镜（如果需要）
        shake_update_filter(source)
        obs.obs_source_release(source)
    end

    local scene = obs.obs_frontend_get_current_scene()
    if scene then
        local scene_obj = obs.obs_scene_from_source(scene)
        shake_sceneitem = obs.obs_scene_find_source(scene_obj, source_name)
        if shake_sceneitem then
            local pos = obs.vec2()
            obs.vec2_set(pos, 0, 0)
            obs.obs_sceneitem_set_pos(shake_sceneitem, pos)
        end
        obs.obs_source_release(scene)
    end
end

-- 定时器回调
function timer_callback()
    if not settings then
        print("设置未初始化，跳过定时器回调")
        return
    end

    local source = obs.obs_get_source_by_name(source_name)
    if not source then
        return
    end

    -- 滤镜去重逻辑
    if obs.obs_data_get_bool(settings, "dedup_enabled") and license_valid then
        if not dedup_filter and not dedup_all_adjustments_disabled() then
            dedup_create_filter(source)
        end

        if dedup_filter then
            if not check_time_tampering() then
                dedup_target_params.offset = 0
                dedup_target_params.brightness = 0
                dedup_target_params.contrast = 0
                dedup_target_params.saturation = 1
            else
                if obs.obs_data_get_bool(settings, "dedup_enable_offset") then
                    dedup_target_params.offset = random_range(obs.obs_data_get_double(settings, "dedup_min_offset"), obs.obs_data_get_double(settings, "dedup_max_offset"))
                end
                if obs.obs_data_get_bool(settings, "dedup_enable_brightness") then
                    dedup_target_params.brightness = random_range(obs.obs_data_get_double(settings, "dedup_min_brightness"), obs.obs_data_get_double(settings, "dedup_max_brightness"))
                end
                if obs.obs_data_get_bool(settings, "dedup_enable_contrast") then
                    dedup_target_params.contrast = random_range(obs.obs_data_get_double(settings, "dedup_min_contrast"), obs.obs_data_get_double(settings, "dedup_max_contrast"))
                end
                if obs.obs_data_get_bool(settings, "dedup_enable_saturation") then
                    dedup_target_params.saturation = random_range(obs.obs_data_get_double(settings, "dedup_min_saturation"), obs.obs_data_get_double(settings, "dedup_max_saturation"))
                end
            end

            local current_time = os.clock() * 1000
            local interval = obs.obs_data_get_int(settings, "dedup_update_interval")
            if dedup_transition_time < dedup_transition_duration then
                dedup_transition_time = dedup_transition_time + 100
                local t = math.min(dedup_transition_time / dedup_transition_duration, 1)
                dedup_current_params.offset = dedup_current_params.offset + (dedup_target_params.offset - dedup_current_params.offset) * t
                dedup_current_params.brightness = dedup_current_params.brightness + (dedup_target_params.brightness - dedup_current_params.brightness) * t
                dedup_current_params.contrast = dedup_current_params.contrast + (dedup_target_params.contrast - dedup_current_params.contrast) * t
                dedup_current_params.saturation = dedup_current_params.saturation + (dedup_target_params.saturation - dedup_current_params.saturation) * t
                dedup_update_filter()
            end
            if current_time - dedup_last_update >= interval then
                dedup_transition_time = 0
                dedup_last_update = current_time
            end
        end
    else
        dedup_update_filter() -- 检查是否需要移除滤镜
    end

    -- 晃动模糊逻辑
    if shake_enabled then
        shake_timer = shake_timer + 0.1
        shake_log_timer = shake_log_timer + 0.1

        local dynamic_amplitude = shake_amplitude
        if not license_valid or not check_time_tampering() then
            dynamic_amplitude = math.min(shake_amplitude, 2.0)
            shake_blur_strength = math.min(shake_blur_strength, 0.3)
        end

        local force_x = random_range(-dynamic_amplitude, dynamic_amplitude) * 0.05
        local force_y = random_range(-dynamic_amplitude, dynamic_amplitude) * 0.05
        shake_velocity_x = (shake_velocity_x + force_x) * shake_damping
        shake_velocity_y = (shake_velocity_y + force_y) * shake_damping
        shake_offset_x = shake_offset_x + shake_velocity_x
        shake_offset_y = shake_offset_y + shake_velocity_y
        shake_offset_x = math.max(math.min(shake_offset_x, dynamic_amplitude), -dynamic_amplitude)
        shake_offset_y = math.max(math.min(shake_offset_y, dynamic_amplitude), -dynamic_amplitude)

        if shake_sceneitem then
            local pos = obs.vec2()
            obs.vec2_set(pos, shake_offset_x, shake_offset_y)
            obs.obs_sceneitem_set_pos(shake_sceneitem, pos)
        end

        shake_update_filter(source)
    else
        shake_update_filter(source) -- 确保关闭时更新日志
    end

    obs.obs_source_release(source)
end

-- 脚本加载
function script_load(settings_data)
    math.randomseed(os.time())
    settings = settings_data
    license_valid = verify_license(license_file_path)
    print("[加载] 脚本初始化，许可证状态: " .. (license_valid and "有效" or "无效"))
    obs.timer_add(timer_callback, 100)
end

-- 脚本卸载
function script_unload()
    obs.timer_remove(timer_callback)
    if dedup_filter then
        local source = obs.obs_get_source_by_name(source_name)
        if source then
            obs.obs_source_filter_remove(source, dedup_filter)
            obs.obs_source_release(source)
        end
        obs.obs_source_release(dedup_filter)
        dedup_filter = nil
        print("[滤镜去重] 卸载时移除滤镜")
    end
    print("[卸载] 脚本已卸载")
end