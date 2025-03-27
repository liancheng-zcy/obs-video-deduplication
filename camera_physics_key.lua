obs = obslua

-- 动态获取脚本目录
local script_dir = script_path():match("(.*[/\\])")
local license_file_path = script_dir .. "license.key"
local last_time_file = script_dir .. "last_run.txt"
local license_expiration_date = "未知"
local license_valid = false

-- 纯 Lua 实现的异或操作
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

local function xor_encrypt(data, key)
    local result = ""
    for i = 1, #data do
        local byte = string.byte(data, i)
        local key_byte = string.byte(key, (i - 1) % #key + 1)
        result = result .. string.char(xor(byte, key_byte))
    end
    return result
end

local function xor_decrypt(data, key)
    return xor_encrypt(data, key)
end

-- 简单的哈希函数
local function simple_hash(str)
    local hash = 0
    for i = 1, #str do
        hash = (hash * 31 + string.byte(str, i)) % 2^32
    end
    return tostring(hash)
end

-- 许可证验证函数
local function verify_license(file_path)
    print("尝试读取文件: " .. file_path)
    local file = io.open(file_path, "r")
    if not file then
        print("许可证文件未找到！请将 license.key 放入脚本目录。")
        return false
    end
    local content = file:read("*all")
    file:close()

    -- 解析加密内容和校验和
    local encrypted_data, checksum = content:match("([^:]+):([^:]+)")
    if not encrypted_data or not checksum then
        print("许可证格式错误！")
        return false
    end

    -- 验证校验和
    local expected_checksum = simple_hash(encrypted_data)
    if checksum ~= expected_checksum then
        print("许可证文件被篡改！功能受限。")
        return false
    end

    -- 解密数据
    local key = "my_secret_key_123"
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

    -- 转换为人类可读的日期
    local date_table = os.date("*t", expiration_time)
    license_expiration_date = string.format("%04d-%02d-%02d", date_table.year, date_table.month, date_table.day)
    print("许可证到期时间: " .. license_expiration_date .. " V：LiAnChenglac")

    local current_time = os.time()
    if current_time > expiration_time then
        print("许可证已过期！请联系作者续费。")
        return false
    end
    return true
end

-- 在全局作用域中调用 verify_license，确保 license_expiration_date 在 script_description 调用前被设置
license_valid = verify_license(license_file_path)

function script_description()
    return "模拟真实镜头的晃动和缩放模糊效果。选择视频源后生效（需配合 zoom_blur.shader）。\n" ..
           "安装步骤：\n" ..
           "1. 将脚本加载到 OBS 脚本菜单。\n" ..
           "2. 将 zoom_blur.shader 放入 OBS Shader 目录。\n" ..
           "3. 为视频源添加名为 'zoom_blur_filter' 的用户定义着色器滤镜，选择 zoom_blur.shader。\n" ..
           "4. 将 license.key 放入脚本目录。\n" ..
           "参数：视频源、启用脚本、晃动幅度、晃动频率、模糊强度、模糊速度关联度、采样次数、动画速度。\n" ..
           "作者：@B站大成子ONLYYOU\nhttps://space.bilibili.com/341867068\n" ..
           "----\n" ..
           "到期时间：" .. license_expiration_date .. "\n" ..
           "作者联系方式：LiAnChenglac"
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
local sceneitem = nil

-- 时间篡改检测函数
local last_check_time = 0
local time_check_interval = 10
local time_tampering_detected = false
local function check_time_tampering()
    local current_time = os.time()
    if current_time - last_check_time < time_check_interval then
        return not time_tampering_detected
    end
    last_check_time = current_time

    -- 读取 last_run.txt
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

    -- 写入 last_run.txt
    file = io.open(last_time_file, "w")
    if file then
        file:write(tostring(current_time))
        file:close()
    else
        print("无法写入 last_run.txt 文件，跳过时间校验。")
    end
    time_tampering_detected = false
    return true
end

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
            obs.vec2_set(pos, 0, 0)
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
    
    if not license_valid or not check_time_tampering() then
        blur_strength = math.min(blur_strength, 0.3)
        shake_amplitude = math.min(shake_amplitude, 2.0)
    end
    
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
            local blur_increment = math.sqrt(speed) * 0.075 * blur_speed_factor
            local dynamic_blur = blur_strength + blur_increment
            dynamic_blur = math.min(math.max(dynamic_blur, 0.0), 1.0)
            obs.obs_data_set_double(settings, "magnitude", dynamic_blur)
            obs.obs_data_set_int(settings, "samples", math.max(samples_value, 1))
            obs.obs_data_set_int(settings, "speed_percent", speed_percent_value)
            obs.obs_source_update(filter, settings)
            
            if log_timer >= 1.0 then
                print("动态模糊: " .. dynamic_blur .. ", 速度: " .. speed)
                log_timer = 0
            end
            
            obs.obs_data_release(settings)
        else
            if log_timer >= 1.0 then
                print("未找到 'zoom_blur_filter' 滤镜！请为视频源添加名为 'zoom_blur_filter' 的用户定义着色器滤镜，并选择 zoom_blur.shader。")
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