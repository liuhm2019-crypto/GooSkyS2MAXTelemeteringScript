
-------  大贝壳 出品 V1.0  

local NAME = "DBK_S2Max"
local VERSION = "v1.0"
local TopValue = 10
local crsf_field = { "Vbat", "Curr", "Hspd", "Capa", "Bat%", "Tesc", "Tmcu", "1RSS", "2RSS", "RQly", "Thr", "Vbec", "ARM", "Gov", "Vcel","Alt" ,"FM" , "TxBt" , "RxBt"}
local TELE_ITEMS = #crsf_field


local value_min_max = {}
local field_id = {}
local bank_info = { current = 1, name = "Bank 1" }
local tg_pic_obj
local default_pic_obj
local title_pic_obj
local HoldOff_pic_obj
local HoldOn_pic_obj
local Feixing_pic_obj
local Bankone_pic_obj

-- 缓存变量
local cached_model_name = ""
local cached_pic_path = ""
local last_audio_time = 0
local led_cache = { last_start_color = 0, last_end_color = 0 }

local hold_locked = false
local button_pressed = false
local hold_previous_state = false

local second = { 0, 0, 0 }
local total_second = 0
local hours = 0
local minutes = { 0, 0 }
local seconds = { 0, 0 }
local power_max = { 0, 0 }


local options = {
    { "SquareColor", COLOR, WHITE },
    { "BackgroundColor", COLOR, BLACK },
    { "ValueColor", COLOR, GREEN },
    { "DispLED", BOOL, 0 },
    { "BankSwitch", SOURCE, 0 },
    { "HoldSwitch", SWITCH, 0 },
    { "FlightSwitch", SWITCH, 0 }
}

local radioH = 0
local radio_name, version = getVersion()

if version and string.find(version, "tx15") then
    radioH = 30
elseif version and string.find(version, "tx16s") then
    radioH = 0
else
    radioH = 0
end

local function create(zone, options)
    local widget = {
        zone = zone,
        options = options
    }

    for i = 1, TELE_ITEMS do
        value_min_max[i] = { 0, 0, 0 }
        field_id[i] = { 0, false }
    end

    cached_model_name = ""

    for k, v in pairs(crsf_field) do
        local field_info = getFieldInfo(v)
        if field_info ~= nil then
            field_id[k][1] = field_info.id
            field_id[k][2] = true
        else
            field_id[k][1] = 0
            field_id[k][2] = false
        end
    end

    for i = 1, #second do
        second[i] = 0
    end
    total_second = 0

    default_pic_obj = Bitmap.open("/WIDGETS/DBK_S2Max/s2maxmax.png")
    title_pic_obj = Bitmap.open("/WIDGETS/DBK_S2Max/title.jpg")
    HoldOff_pic_obj = Bitmap.open("/WIDGETS/DBK_S2Max/hold1.png")
    HoldOn_pic_obj = Bitmap.open("/WIDGETS/DBK_S2Max/hold2.png")
    Feixing_pic_obj = Bitmap.open("/WIDGETS/DBK_S2Max/Feiji.png")
    return widget
end

local function update(widget, options)
    widget.options = options
end

local function background(widget)
end

local function get_bank_info(widget)
    if widget.options.BankSwitch ~= 0 then
        local bank_value = getValue(widget.options.BankSwitch) or 0
        local bank_num = 1
        if bank_value < -300 then
            bank_num = 1
        elseif bank_value > 300 then
            bank_num = 3
        else
            bank_num = 2
        end
        bank_info.current = bank_num
        return
    end

    local fm_value = getValue(field_id[17][1])
    if fm_value ~= nil then
        local bank_num = math.floor(fm_value) + 1
        bank_info.current = math.max(1, math.min(6, bank_num))
        return
    end

    bank_info.current = 1
end

local function draw_rounded_rectangle(xs, ys, w, h, r, color)
    lcd.drawArc(xs + r, ys + r, r, 270, 360, color)
    lcd.drawArc(xs + r, ys + h - r, r, 180, 270, color)
    lcd.drawArc(xs + w - r, ys + r, r, 0, 90, color)
    lcd.drawArc(xs + w - r, ys + h - r, r, 90, 180, color)
    lcd.drawLine(xs + r, ys, xs + w - r, ys, SOLID, color)
    lcd.drawLine(xs + r, ys + h, xs + w - r, ys + h, SOLID, color)
    lcd.drawLine(xs, ys + r, xs, ys + h - r, SOLID, color)
    lcd.drawLine(xs + w, ys + r, xs + w, ys + h - r, SOLID, color)
end

local function drawBatteryRing(x, y, radius, voltage, max_voltage, thickness)
    thickness = thickness or 3
    local percentage = math.min(voltage / max_voltage * 100, 100)
    local inner_radius = radius - thickness

    local color = lcd.RGB(255 - percentage * 2.55, percentage * 2.55, 0)

    if percentage ~= 0 and percentage ~= 100 then
        lcd.drawAnnulus(x, y, inner_radius, radius, (100 - percentage) * 3.6, 360, color)
    end
    if percentage == 100 then
        lcd.drawAnnulus(x, y, inner_radius, radius, 1, 360, color)
        lcd.drawAnnulus(x, y, inner_radius, radius, -5, 5, color)
    end
end

local function fuel_percentage(xs, ys, capa, number, text_color)
    local color = lcd.RGB(255 - number * 2.55, number * 2.55, 0)
    if number ~= 0 and number ~= 100 then
        lcd.drawAnnulus(xs, ys, 45, 70, (100 - number) * 3.6, 360, color)
    end
    if number == 100 then
        lcd.drawAnnulus(xs, ys, 45, 70, 1, 360, color)
        lcd.drawAnnulus(xs, ys, 45, 70, -5, 5, color)
    end
    lcd.drawText(xs + 2, ys - 10, string.format("%d%%", number), CENTER + VCENTER + DBLSIZE + text_color)
    lcd.drawText(xs, ys + 15, string.format("%dmAh", capa), CENTER + VCENTER + text_color)
end

 


local function rqly_signal_bars(xs, ys, rqly_percent, default_color)
    local block_size = 5
    local block_spacing = 7
    rqly_percent = math.max(0, math.min(100, rqly_percent))
    local active_blocks = math.floor((rqly_percent + 19) / 20)
    for i = 1, 5 do
        local block_x = xs + (i - 1) * block_spacing
        local block_y = ys
        local block_color = default_color
        if rqly_percent > 0 and i <= active_blocks then
            if i == 1 then
                block_color = RED
            elseif i == 2 then
                block_color = ORANGE
            elseif i == 3 then
                block_color = YELLOW
            elseif i == 4 then
                block_color = lcd.RGB(173, 255, 47)
            else
                block_color = GREEN
            end
        end
        lcd.drawFilledRectangle(block_x, block_y, block_size, block_size, block_color)
    end
end



local function safe_play_tone(freq, length, pause, flags, freqIncr)
    local current_time = getTime()
    if current_time - last_audio_time > 10 then 
        last_audio_time = current_time
        playTone(freq, length, pause, flags or PLAY_NOW, freqIncr)
    end
end

local function refresh(widget, event, touchState)
    local screen_width =  LCD_W or widget.zone.w
    local screen_height =  LCD_H or widget.zone.h
    if event == nil then
    elseif event ~= 0 then
        if touchState then
            if event == EVT_TOUCH_FIRST then
                safe_play_tone(100, 50, 50)
            elseif event == EVT_TOUCH_TAP then
                safe_play_tone(200, 50, 50)
            end
        end
    end
    lcd.setColor(CUSTOM_COLOR, widget.options.BackgroundColor)
    local bg_color = lcd.getColor(CUSTOM_COLOR)
    lcd.setColor(CUSTOM_COLOR, widget.options.SquareColor)
    local square_color = lcd.getColor(CUSTOM_COLOR)
    lcd.setColor(CUSTOM_COLOR, widget.options.ValueColor)
    local value_color = lcd.getColor(CUSTOM_COLOR)


    if widget.options.DispLED == 1 and LED_STRIP_LENGTH and LED_STRIP_LENGTH > 0 then
        local start_color = widget.options.SquareColor
        local end_color = widget.options.ValueColor

        if led_cache.last_start_color ~= start_color or led_cache.last_end_color ~= end_color then
            led_cache.last_start_color = start_color
            led_cache.last_end_color = end_color

            local start_rgb565 = math.floor(start_color / 65536)
            local start_red = math.floor(start_rgb565 / 2048) * 8
            local start_green = (math.floor(start_rgb565 / 32) % 64) * 4
            local start_blue = (start_rgb565 % 32) * 8
            local end_rgb565 = math.floor(end_color / 65536)
            local end_red = math.floor(end_rgb565 / 2048) * 8
            local end_green = (math.floor(end_rgb565 / 32) % 64) * 4
            local end_blue = (end_rgb565 % 32) * 8

            for i = 0, LED_STRIP_LENGTH - 1 do
                local ratio = 0.5
                local ratio = (i % 2) / 1
                local red = start_red + (end_red - start_red) * ratio
                local green = start_green + (end_green - start_green) * ratio
                local blue = start_blue + (end_blue - start_blue) * ratio
                setRGBLedColor(i, math.floor(red), math.floor(green), math.floor(blue))
            end
            applyRGBLedColors()
        end
    elseif widget.options.DispLED == 0 and LED_STRIP_LENGTH and LED_STRIP_LENGTH > 0 then

        for i = 0, LED_STRIP_LENGTH - 1 do
            setRGBLedColor(i, 0, 0, 0)
        end
        applyRGBLedColors()

        led_cache.last_start_color = -1
        led_cache.last_end_color = -1
    end
    lcd.drawFilledRectangle(0, 0, screen_width, screen_height, bg_color)


    if title_pic_obj then
        lcd.drawBitmap(title_pic_obj, 0, 0)
    end
      
   
    
    
    local title_height = 25
    local current_time = getDateTime()
    local time_str = string.format("%02d:%02d:%02d", current_time.hour, current_time.min, current_time.sec)
    lcd.drawText(390, 13, time_str, BOLD + square_color)


    local current_model_name = model.getInfo().name
    if cached_model_name ~= current_model_name then
        cached_model_name = current_model_name
        cached_pic_path = "/WIDGETS/DBK_S2Max/"..cached_model_name..".png"

        if fstat(cached_pic_path) then
            tg_pic_obj = Bitmap.open(cached_pic_path)
        else
            tg_pic_obj = nil
        end
    end

    lcd.drawText(340, 250+radioH, cached_model_name, BOLD + square_color)

    local tx_voltage = getValue("tx-voltage") or getValue(field_id[18][1]) or 0
    local tx_battery_str = string.format("%.1fV", tx_voltage)

    local tx_color = value_color   
    if tx_voltage < 6.5 then
        tx_color = RED
    elseif tx_voltage >= 6.5 and tx_voltage <= 7.0 then
        tx_color = YELLOW
    end

    lcd.drawText(330, 13, "Tx", BOLD + square_color)
    lcd.drawText(350, 13, tx_battery_str, BOLD + tx_color)

    lcd.drawText(80, title_height / 2+TopValue, "Bank" , CENTER + VCENTER + square_color)

    lcd.drawText(170, title_height / 2+TopValue, "RSSI" , CENTER + VCENTER + square_color)
    get_bank_info(widget)

    local bank_color = square_color  
    if bank_info.current == 1 then
        bank_color = lcd.RGB(0, 100, 255)      
    elseif bank_info.current == 2 then
        bank_color = lcd.RGB(255, 165, 0)      
    elseif bank_info.current == 3 then
        bank_color = lcd.RGB(255, 255, 0)      
    end
    lcd.drawText(113, 30, tostring(bank_info.current), CENTER + VCENTER + BOLD + MIDSIZE + bank_color)

    local gov_status = (field_id[14][2] and value_min_max[14][1]) or 0

    
    local hold_active = false
    if widget.options.HoldSwitch ~= 0 then
        local switch_value = getSwitchValue(widget.options.HoldSwitch)
        if switch_value and switch_value ~= 0 and switch_value ~= false then
            hold_active = false
            if HoldOff_pic_obj then
                lcd.drawBitmap(HoldOff_pic_obj, 10, 17)
            end
        else
            hold_active = true
            if HoldOn_pic_obj then
                lcd.drawBitmap(HoldOn_pic_obj, 10, 17)
            end
        end


        if hold_active ~= hold_previous_state then
            second[1] = 0
            total_second = 0
            hold_previous_state = hold_active
        end
    end

   local x, y, r_out, r_in = 420, 200, 40, 28
   local color = COLOR_THEME_WARNING
   local bg    = COLOR_THEME_SECONDARY1

   if Feixing_pic_obj then
        lcd.drawBitmap(Feixing_pic_obj, 385, 152)
   end

    if widget.options.FlightSwitch ~= 0 then
        local switch_value = getSwitchValue(widget.options.FlightSwitch)
        if switch_value and switch_value ~= 0 and switch_value ~= false then
            lcd.drawFilledRectangle(390, 245, 22, 5, value_color)
        else
           lcd.drawFilledRectangle(426, 244, 22, 5, value_color)
        end
    else
         lcd.drawFilledRectangle(390, 245, 22, 5, value_color)
    end
    
   
   
   for k = 1, TELE_ITEMS do
        if field_id[k][2] then
            local get_value = getValue(field_id[k][1])
            value_min_max[k][1] = get_value  
            if not hold_active then
                if get_value > value_min_max[k][2] then
                    value_min_max[k][2] = get_value
                elseif get_value < value_min_max[k][3] then
                    value_min_max[k][3] = get_value
                end
            end
        end
    end


    power_max[2] = math.min(math.floor(value_min_max[1][1] * value_min_max[2][1]), 99999)
    if power_max[1] < power_max[2] then
        power_max[1] = power_max[2]
    end

    second[3] = getRtcTime()
    if second[2] ~= second[3] then
        second[2] = second[3]
        if hold_active then
            second[1] = second[1] + 1
            total_second = total_second + 1
        end
    end

    minutes[1] = string.format("%02d", math.floor(second[1] % 3600 / 60))
    seconds[1] = string.format("%02d", second[1] % 3600 % 60)
    hours = string.format("%02d", math.floor(total_second / 3600))
    minutes[2] = string.format("%02d", math.floor(total_second % 3600 / 60))
    seconds[2] = string.format("%02d", total_second % 3600 % 60)


    local battery_voltage = getValue(field_id[19][1]) or 0

    local battery_voltage_str = string.format("%.2fv", battery_voltage)
    drawBatteryRing(420, 85+TopValue, 40,10.49, 12.6, 13)
    lcd.drawText( 420, 94, battery_voltage, CENTER + VCENTER + value_color)

    

    local battery_percent = getValue(field_id[5][1]) or 0  
    local battery_capacity = getValue(field_id[4][1])  or 0  
    fuel_percentage(300, 150, battery_capacity, battery_percent, value_color)
    lcd.drawText(240, 250, "Time" , CENTER + VCENTER + square_color)
    local flight_time_str = string.format("%s:%s", minutes[1], seconds[1])
    lcd.drawText(310, 248, flight_time_str, CENTER + VCENTER + DBLSIZE + value_color)
   
    local rpm_value = getValue(field_id[16][1]) or 0  
    local rpm_str = "0"
    if rpm_value > 0 then
        rpm_str = string.format("%d", rpm_value)
    end
    lcd.drawText(97, 240, rpm_str, CENTER + VCENTER + DBLSIZE + BOLD + value_color)
    lcd.drawText(190, 250, "Rpm" , CENTER + VCENTER + square_color)
    lcd.drawFilledRectangle(20, 270, 435, 1, square_color)
     
    local rqly_percent = (field_id[10][2] and value_min_max[10][1]) or 0     
    rqly_signal_bars(200, 10+TopValue, rqly_percent, WHITE)

    if rqly_percent > 0 then
        lcd.drawText(175, 33+TopValue, string.format("%ddB", rqly_percent), CENTER + VCENTER  + value_color)
    else
        lcd.drawText(165, 33+TopValue, "---", CENTER + VCENTER + MIDSIZE + RED)
    end

    if tg_pic_obj then
        if version and string.find(version, "tx15") then
             lcd.drawBitmap(tg_pic_obj, 15, 70)
        else
             lcd.drawBitmap(tg_pic_obj, 250, 150+radioH)
        end
    else
        if default_pic_obj then
            lcd.drawBitmap(default_pic_obj, 15, 70)
        end
    end
     
    if version and string.find(version, "tx15") then
       
       local current_value = getValue(field_id[2][1]) or 0  
       local current_str = "0.0A"
       if current_value > 0 then
           current_str = string.format("%.1fA", current_value)
       end
       lcd.drawText(12, 270+TopValue, "Current", BOLD +  square_color)
       lcd.drawText(75, 270+TopValue, current_str, BOLD +  value_color)
       
       local power_value = battery_voltage * current_value  
       local power_str = "0.0W"
       if power_value > 0 then
           if power_value >= 1000 then
               power_str = string.format("%.1fkW", power_value / 1000)  
           else
               power_str = string.format("%.0fW", power_value)  
           end
       end
       lcd.drawText(125, 270+TopValue, "Power", BOLD +  square_color)
       lcd.drawText(180, 270+TopValue, power_str, BOLD +  value_color)
    end

    
end
return {
    name = NAME,
    options = options,
    create = create,
    update = update,
    refresh = refresh,
    background = background
}