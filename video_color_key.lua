obs = obslua

-- 动态获取脚本目录
local script_dir = script_path():match("(.*[/\\])")
local license_file_path = script_dir .. "license.key"
local last_time_file = script_dir .. "last_run.txt"
local license_expiration_date = "请激活使用完整功能"
local license_valid = false

-- 异或操作，与 Python 脚本保持一致
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

-- 哈希函数，与 Python 脚本一致
local function simple_hash(str)
    local hash = 0
    for i = 1, #str do
        hash = (hash * 31 + string.byte(str, i)) % 2^32
    end
    return tostring(hash)
end

-- 许可证验证函数
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

    local key = "Kj9pL2mNx7vQ4tRwY8zB5cF1dH3gJ6k"  -- 新密钥，与 Python 脚本一致
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
    if current_time > expiration_time then
        print("许可证已过期！请联系作者续费。")
        return false
    end
    return true
end

license_valid = verify_license(license_file_path)

-- 时间篡改检测
local last_check_time = 0
local time_check_interval = 10 -- 每 10 秒检查一次
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
    time_tampering_detected = false
    return true
end

-- 脚本描述
function script_description()
    return "一个OBS脚本，用于动态调整滤镜参数，实现视频去重效果。\n" ..
           "安装步骤：\n" ..
           "1. 将脚本加载到 OBS 脚本菜单。\n" ..
           "2. 将 license.key 放入脚本目录。\n" ..
           "参数：视频源、启用脚本、最小/最大偏移值、亮度、对比度、饱和度、更新间隔。\n" ..
           "作者：@B站大成子ONLYYOU\nhttps://space.bilibili.com/341867068\n" ..
           "----------------------------------------------\n" ..
           "到期时间：" .. license_expiration_date .. "\n" ..
           "----------------------------------------------\n" ..
           "联系方式：LiAnChenglac\n" ..
           "\n最佳实践建议：\n" ..
           "1、视频源：使用1080p以上高质量视频源。\n" ..
           "2、参数调整：\n" ..
           "  偏移：-0.01到0.01，若偏暖可设为-0.015到0.0（偏冷）。\n" ..
           "  亮度：-0.05到0.05，若偏暗可设为-0.02到0.08。\n" ..
           "  对比度：-0.03到0.03，若细节少可设为-0.05到0.05。\n" ..
           "  饱和度：0.99到1.03，若颜色淡可设为1.0到1.05。\n" ..
           "3、关闭某项：取消勾选'启用偏移调整'等，或将最小/最大值设为0。\n" ..
           "4、更新间隔：默认2000ms，若需平滑可设为1000ms（不低于500ms）。\n" ..
           "5、许可证：确保license.key在脚本目录，勿改系统时间。\n" ..
           "6、性能：避免运行多个高负载脚本。\n" ..
           "7、排查问题：\n" ..
           "  闪烁：减小参数范围或增加更新间隔。\n" ..
           "  失真：减小偏移/饱和度范围，检查素材亮度。\n"..
        " 如果你无法掌控色彩，请调小范围，或者调大更新间隔。或者关闭某些项，开启其中一两项"
end

-- 脚本属性
function script_properties()
    local props = obs.obs_properties_create()
    local sources = obs.obs_enum_sources()
    if sources then
        local list = obs.obs_properties_add_list(props, "source", "选择视频源", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
        obs.obs_property_list_add_string(list, "", "")
        for _, source in ipairs(sources) do
            local name = obs.obs_source_get_name(source)
            local flags = obs.obs_source_get_output_flags(source)
            if bit.band(flags, obs.OBS_SOURCE_VIDEO) ~= 0 then
                obs.obs_property_list_add_string(list, name, name)
            end
        end
        obs.source_list_release(sources)
    end

    obs.obs_properties_add_bool(props, "enabled", "启用动态色彩滤镜")
    obs.obs_properties_add_bool(props, "enable_offset", "启用偏移调整")
    obs.obs_properties_add_bool(props, "enable_brightness", "启用亮度调整")
    obs.obs_properties_add_bool(props, "enable_contrast", "启用对比度调整")
    obs.obs_properties_add_bool(props, "enable_saturation", "启用饱和度调整")
    obs.obs_properties_add_float_slider(props, "min_offset", "最小偏移值", -1.0, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, "max_offset", "最大偏移值", -1.0, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, "min_brightness", "最小亮度", -1.0, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, "max_brightness", "最大亮度", -1.0, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, "min_contrast", "最小对比度", -1.0, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, "max_contrast", "最大对比度", -1.0, 1.0, 0.01)
    obs.obs_properties_add_float_slider(props, "min_saturation", "最小饱和度", 0.0, 2.0, 0.01)
    obs.obs_properties_add_float_slider(props, "max_saturation", "最大饱和度", 0.0, 2.0, 0.01)
    obs.obs_properties_add_int(props, "update_interval", "更新时间 (毫秒)", 100, 10000, 100)

    return props
end

-- 默认参数
function script_defaults(settings)
    obs.obs_data_set_default_bool(settings, "enabled", true)
    obs.obs_data_set_default_bool(settings, "enable_offset", true)
    obs.obs_data_set_default_bool(settings, "enable_brightness", true)
    obs.obs_data_set_default_bool(settings, "enable_contrast", true)
    obs.obs_data_set_default_bool(settings, "enable_saturation", true)
    obs.obs_data_set_default_double(settings, "min_offset", -0.01)
    obs.obs_data_set_default_double(settings, "max_offset", 0.01)
    obs.obs_data_set_default_double(settings, "min_brightness", -0.05)
    obs.obs_data_set_default_double(settings, "max_brightness", 0.05)
    obs.obs_data_set_default_double(settings, "min_contrast", -0.03)
    obs.obs_data_set_default_double(settings, "max_contrast", 0.03)
    obs.obs_data_set_default_double(settings, "min_saturation", 0.99)
    obs.obs_data_set_default_double(settings, "max_saturation", 1.03)
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
local transition_duration = 1000
local log_timer = 0

-- 随机值生成
function random_range(min, max)
    return min + (max - min) * math.random()
end

-- 重置参数
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

-- 检查是否所有配置项都关闭
function all_adjustments_disabled()
    return not obs.obs_data_get_bool(script_settings, "enable_offset") and
           not obs.obs_data_get_bool(script_settings, "enable_brightness") and
           not obs.obs_data_get_bool(script_settings, "enable_contrast") and
           not obs.obs_data_get_bool(script_settings, "enable_saturation")
end

-- 更新滤镜（修复日志，添加开关状态）
function update_filter()
    if not filter or not script_settings then return end

    -- 如果所有配置项都关闭，移除滤镜
    if all_adjustments_disabled() then
        local source = obs.obs_get_source_by_name(source_name)
        if source then
            obs.obs_source_filter_remove(source, filter)
            obs.obs_source_release(source)
        end
        obs.obs_source_release(filter)
        filter = nil
        print("所有调整项已关闭，滤镜已移除，恢复OBS默认效果")
        return
    end

    -- 激活前日志
    log_timer = log_timer + 100
    if log_timer >= 2000 then
        local offset_status = obs.obs_data_get_bool(script_settings, "enable_offset") and "开启" or "关闭"
        local brightness_status = obs.obs_data_get_bool(script_settings, "enable_brightness") and "开启" or "关闭"
        local contrast_status = obs.obs_data_get_bool(script_settings, "enable_contrast") and "开启" or "关闭"
        local saturation_status = obs.obs_data_get_bool(script_settings, "enable_saturation") and "开启" or "关闭"
    end

    -- 强制设置关闭项的参数为OBS默认值
    if not obs.obs_data_get_bool(script_settings, "enable_offset") then
        current_params.offset = 0
    end
    if not obs.obs_data_get_bool(script_settings, "enable_brightness") then
        current_params.brightness = 0
    end
    if not obs.obs_data_get_bool(script_settings, "enable_contrast") then
        current_params.contrast = 0
    end
    if not obs.obs_data_get_bool(script_settings, "enable_saturation") then
        current_params.saturation = 1
    end

    local settings = obs.obs_data_create()
    obs.obs_data_set_double(settings, "color_add", current_params.offset)
    obs.obs_data_set_double(settings, "brightness", current_params.brightness)
    obs.obs_data_set_double(settings, "contrast", current_params.contrast)
    obs.obs_data_set_double(settings, "saturation", current_params.saturation)
    obs.obs_source_update(filter, settings)
    obs.obs_data_release(settings)

    -- 激活后日志
    if log_timer >= 2000 then
        local offset_status = obs.obs_data_get_bool(script_settings, "enable_offset") and "开启" or "关闭"
        local brightness_status = obs.obs_data_get_bool(script_settings, "enable_brightness") and "开启" or "关闭"
        local contrast_status = obs.obs_data_get_bool(script_settings, "enable_contrast") and "开启" or "关闭"
        local saturation_status = obs.obs_data_get_bool(script_settings, "enable_saturation") and "开启" or "关闭"
        print(string.format("滤镜激活后参数 - 偏移: %.4f (%s), 亮度: %.4f (%s), 对比度: %.4f (%s), 饱和度: %.4f (%s)",
            current_params.offset, offset_status,
            current_params.brightness, brightness_status,
            current_params.contrast, contrast_status,
            current_params.saturation, saturation_status))
        log_timer = 0
    end
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
        obs.script_log(obs.LOG_ERROR, "无法创建滤镜")
        obs.obs_data_release(filter_settings)
        return false
    end
    obs.obs_source_filter_add(source, filter)
    obs.obs_data_release(filter_settings)
    return true
end

-- 脚本更新（处理许可证未激活的情况）
function script_update(settings)
    script_settings = settings
    local new_source_name = obs.obs_data_get_string(settings, "source")
    local enabled = obs.obs_data_get_bool(settings, "enabled")

    if new_source_name == "" then
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

    if new_source_name ~= source_name then
        source_name = new_source_name
        local source = obs.obs_get_source_by_name(source_name)
        if not source then return end

        if filter then
            local old_source = obs.obs_get_source_by_name(source_name)
            if old_source then
                obs.obs_source_filter_remove(old_source, filter)
                obs.obs_source_release(old_source)
            end
            obs.obs_source_release(filter)
            filter = nil
        end

        reset_params()
        -- 只有在许可证有效且启用时才创建滤镜
        if enabled and not all_adjustments_disabled() and license_valid and create_filter(source) then
            update_filter()
        end
        obs.obs_source_release(source)
    elseif enabled and not filter and not all_adjustments_disabled() and license_valid then
        local source = obs.obs_get_source_by_name(source_name)
        if source and create_filter(source) then
            update_filter()
        end
        if source then obs.obs_source_release(source) end
    elseif (not enabled or all_adjustments_disabled() or not license_valid) and filter then
        local source = obs.obs_get_source_by_name(source_name)
        if source then
            obs.obs_source_filter_remove(source, filter)
            obs.obs_source_release(source)
        end
        obs.obs_source_release(filter)
        filter = nil
        print("脚本已禁用、所有调整项关闭或许可证未激活，滤镜已移除，恢复OBS默认效果")
    end
end

-- 定时器回调（处理许可证未激活的情况）
function timer_callback()
    if not script_settings or not obs.obs_data_get_bool(script_settings, "enabled") then return end

    -- 如果所有配置项都关闭或许可证未激活，移除滤镜并跳过更新
    if all_adjustments_disabled() or not license_valid then
        if filter then
            local source = obs.obs_get_source_by_name(source_name)
            if source then
                obs.obs_source_filter_remove(source, filter)
                obs.obs_source_release(source)
            end
            obs.obs_source_release(filter)
            filter = nil
            print("所有调整项已关闭或许可证未激活，滤镜已移除，恢复OBS默认效果")
        end
        return
    end

    -- 如果滤镜不存在，尝试创建（仅在许可证有效时）
    if not filter then
        local source = obs.obs_get_source_by_name(source_name)
        if source and create_filter(source) then
            update_filter()
        end
        if source then obs.obs_source_release(source) end
        return
    end

    -- 确保关闭的项参数为OBS默认值
    if not obs.obs_data_get_bool(script_settings, "enable_offset") then
        target_params.offset = 0
        current_params.offset = 0
    end
    if not obs.obs_data_get_bool(script_settings, "enable_brightness") then
        target_params.brightness = 0
        current_params.brightness = 0
    end
    if not obs.obs_data_get_bool(script_settings, "enable_contrast") then
        target_params.contrast = 0
        current_params.contrast = 0
    end
    if not obs.obs_data_get_bool(script_settings, "enable_saturation") then
        target_params.saturation = 1
        current_params.saturation = 1
    end

    -- 设置目标参数（仅在许可证有效且时间未篡改时应用用户设置范围）
    if not check_time_tampering() then
        -- 时间篡改时不更新参数，保持默认值
        target_params.offset = 0
        target_params.brightness = 0
        target_params.contrast = 0
        target_params.saturation = 1
    else
        if obs.obs_data_get_bool(script_settings, "enable_offset") then
            target_params.offset = random_range(obs.obs_data_get_double(script_settings, "min_offset"), obs.obs_data_get_double(script_settings, "max_offset"))
        end
        if obs.obs_data_get_bool(script_settings, "enable_brightness") then
            target_params.brightness = random_range(obs.obs_data_get_double(script_settings, "min_brightness"), obs.obs_data_get_double(script_settings, "max_brightness"))
        end
        if obs.obs_data_get_bool(script_settings, "enable_contrast") then
            target_params.contrast = random_range(obs.obs_data_get_double(script_settings, "min_contrast"), obs.obs_data_get_double(script_settings, "max_contrast"))
        end
        if obs.obs_data_get_bool(script_settings, "enable_saturation") then
            target_params.saturation = random_range(obs.obs_data_get_double(script_settings, "min_saturation"), obs.obs_data_get_double(script_settings, "max_saturation"))
        end
    end

    local current_time = os.clock() * 1000
    local interval = obs.obs_data_get_int(script_settings, "update_interval")

    -- 过渡更新
    if transition_time < transition_duration then
        transition_time = transition_time + 100
        local t = math.min(transition_time / transition_duration, 1)
        local prev_offset = current_params.offset
        local prev_brightness = current_params.brightness
        local prev_contrast = current_params.contrast
        local prev_saturation = current_params.saturation
        current_params.offset = prev_offset + (target_params.offset - prev_offset) * t
        current_params.brightness = prev_brightness + (target_params.brightness - prev_brightness) * t
        current_params.contrast = prev_contrast + (target_params.contrast - prev_contrast) * t
        current_params.saturation = prev_saturation + (target_params.saturation - prev_saturation) * t
        update_filter()
    end

    if current_time - last_update >= interval then
        transition_time = 0
        last_update = current_time
    end
end

-- 脚本加载
function script_load(settings)
    math.randomseed(os.time())
    script_settings = settings
    obs.timer_add(timer_callback, 100)
end

-- 脚本卸载
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
end