local ffi = require('ffi')
script_version('2.0.0');
script_author('https://vk.com/id620137656');

local imgui = require('mimgui');
local encoding = require('encoding');
encoding.default = 'CP1251'
u8 = encoding.UTF8
local keys = require('vkeys');
local sampev = require('lib.samp.events')
local effil = require('effil')

local lastSendKeyMessage = os.time()

local configName = imgui.new.char[32]('')
local sleepInactiveShutdownInt = imgui.new.int(30)
local newMessage = imgui.new.char[256]('')

local lastMessageTime = {}

local isAdvCommand = false

local update = {
    available = false,
    version = nil,
    download = nil
}

function asyncHttpRequest(method, url, args, resolve, reject)
    local request_thread = effil.thread(function (method, url, args)
        local requests = require 'requests'
        local result, response = pcall(requests.request, method, url, args)
        if result then
            response.json, response.xml = nil, nil
            return true, response
        else
            return false, response
        end
    end)(method, url, args)
    
    if not resolve then resolve = function() end end
    if not reject then reject = function() end end
    
    lua_thread.create(function()
        local runner = request_thread
        while true do
            local status, err = runner:status()
            if not err then
                if status == 'completed' then
                    local result, response = runner:get()
                    if result then
                        resolve(response)
                    else
                        reject(response)
                    end
                    return
                elseif status == 'canceled' then
                    return reject(status)
                end
            else
                return reject(err)
            end
            wait(0)
        end
    end)
end

function checkUpdates()
    local function onSuccess(response)
        if response.status_code == 200 then
            local data = decodeJson(response.text)
            if data and data.version and data.download then
                local currentVersion, _ = thisScript().version:gsub('%.', '')
                local currentVersion = tonumber(currentVersion)
                local newVersion, _ = data.version:gsub('%.', '')
                local newVersion = tonumber(newVersion)
                
                if newVersion > currentVersion then
                    update.available = true
                    update.version = data.version
                    update.download = data.download
                    sms('Доступно обновление {mc}' .. data.version .. '{FFFFFF}! Нажмите кнопку "Обновить" в меню для загрузки.')
                end
            end
        end
    end

    local function onError(error)
        print('Failed to check updates:', error)
    end

    asyncHttpRequest(
        'GET',
        'https://raw.githubusercontent.com/Matvey-Guzienko/autoad-samp/refs/heads/main/updates.json',
        { headers = { ['content-type'] = 'application/json' } },
        onSuccess,
        onError
    )
end

function json()
    local filePath = "autoad.json"
    local filePath = getWorkingDirectory()..'\\config\\'..(filePath:find('(.+).json') and filePath or filePath..'.json')
    local class = {}
    if not doesDirectoryExist(getWorkingDirectory()..'\\config') then
        createDirectory(getWorkingDirectory()..'\\config')
    end
    
    function class:Save(tbl)
        if tbl then
            local F = io.open(filePath, 'w')
            F:write(encodeJson(tbl) or {})
            F:close()
            return true, 'ok'
        end
        return false, 'table = nil'
    end

    function class:Load(defaultTable)
        if not doesFileExist(filePath) then
            class:Save(defaultTable or {})
        end
        local F = io.open(filePath, 'r+')
        local TABLE = decodeJson(F:read() or {})
        F:close()
        for def_k, def_v in next, defaultTable do
            if TABLE[def_k] == nil then
                TABLE[def_k] = def_v
            end
        end
        return TABLE
    end

    return class
end

local chatTypes = {
    {id = 's', name = 'Крик (/s)', maxLength = 99},
    {id = 'jb', name = 'НРП Чат-Работы (/jb)', maxLength = 87},
    {id = 'j', name = 'РП Чат-работы (/j)', maxLength = 100},
    {id = 'vr', name = 'VIP-чат (/vr)', maxLength = 105},
    {id = 'fb', name = 'НРП Чат-Нелегал. (/fb)', maxLength = 90},
    {id = 'f', name = 'РП Чат-Нелегал. (/f)', maxLength = 90},
    {id = 'fam', name = 'Семейный (/fam)', maxLength = 89},
    {id = 'rb', name = 'НРП Чат-Гос. (/rb)', maxLength = 90},
    {id = 'al', name = 'Семейный Альянс (/al)', maxLength = 94},
    {id = 'ad', name = 'Объявления (/ad)', maxLength = 80}, 
    {id = 'gd', name = 'Чат коалиции (/gd)', maxLength = 100},
}

local defaultADV = {
    ["s"] = {
        ["enabled"] = false,
        ["delay"] = 30,
        ["messages"] = {},
        ["lineDelay"] = 1
    },
    ["j"] = {
        ["enabled"] = false,
        ["delay"] = 30,
        ["messages"] = {},
        ["lineDelay"] = 1
    },
    ["vr"] = {
        ["enabled"] = false,
        ["delay"] = 30,
        ["messages"] = {},
        ["lineDelay"] = 1,
        ["vrAdvertisementSend"] = true
    },
    ["fb"] = {
        ["enabled"] = false,
        ["delay"] = 30,
        ["messages"] = {},
        ["lineDelay"] = 1
    },
    ["f"] = {
        ["enabled"] = false,
        ["delay"] = 30,
        ["messages"] = {},
        ["lineDelay"] = 1
    },
    ["fam"] = {
        ["enabled"] = false,
        ["delay"] = 30,
        ["messages"] = {},
        ["lineDelay"] = 1
    },
    ["rb"] = {
        ["enabled"] = false,
        ["delay"] = 30,
        ["messages"] = {},
        ["lineDelay"] = 1
    },
    ["al"] = {
        ["enabled"] = false,
        ["delay"] = 30,
        ["messages"] = {},
        ["lineDelay"] = 1
    },
    ["jb"] = {
        ["enabled"] = false,
        ["delay"] = 30,
        ["messages"] = {},
        ["lineDelay"] = 1
    },
    ["ad"] = {
        ["enabled"] = false,
        ["delay"] = 30,
        ["messages"] = {},
        ["lineDelay"] = 1,
        ["centr"] = 0,
        ["type"] = 0
    },
    ["gd"] = {
        ["enabled"] = false,
        ["delay"] = 30,
        ["messages"] = {},
        ["lineDelay"] = 1
    },
}

local adCenters = {
    u8("Автоматически"),
    "SF",
    "LV",
    "LS"
}
local centerIndex = imgui.new['const char*'][#adCenters](adCenters)

local adTypes = {
    u8("Обычное"),
    "VIP",
    u8("Реклама бизнеса")
}
local adTypeIndex = imgui.new['const char*'][#adTypes](adTypes)

local settings = json():Load({
    ["main"] = {
        ["enabled"] = false,
        ["inactiveShutdown"] = false,
        ["sleepInactiveShutdown"] = 30,
        ["activeConf"] = 1
    },
    ["configs"] = {
        {
            ["name"] = "Основной",
            ["adv"] = defaultADV
        }
    }
})

local ui_meta = {
    __index = function(self, v)
        if v == "switch" then
            local switch = function()
                if self.process and self.process:status() ~= "dead" then
                    return false -- // Предыдущая анимация ещё не завершилась!
                end
                self.timer = os.clock()
                self.state = not self.state

                self.process = lua_thread.create(function()
                    local bringFloatTo = function(from, to, start_time, duration)
                        local timer = os.clock() - start_time
                        if timer >= 0.00 and timer <= duration then
                            local count = timer / (duration / 100)
                            return count * ((to - from) / 100)
                        end
                        return (timer > duration) and to or from
                    end

                    while true do wait(0)
                        local a = bringFloatTo(0.00, 1.00, self.timer, self.duration)
                        self.alpha = self.state and a or 1.00 - a
                        if a == 1.00 then break end
                    end
                end)
                return true -- // Состояние окна изменено!
            end
            return switch
        end
 
        if v == "alpha" then
            return self.state and 1.00 or 0.00
        end
    end
}

local menu = { state = false, duration = 0.5 }
setmetatable(menu, ui_meta)

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    theme()
end)

imgui.OnFrame(
    function() return menu.alpha > 0.00 end,
    function(cls)
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 800, 400
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        cls.HideCursor = not menu.state
        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, menu.alpha)
        if imgui.Begin('AutoAdByDiscq192 | ' .. thisScript().version .. ' | BETA', _, imgui.WindowFlags.NoResize) then
            imgui.BeginChild('::configChild', imgui.ImVec2(-(resX / 3), -30), true)
                for index, config in ipairs(settings.configs) do
                    if imgui.ButtonActivated(index == settings.main.activeConf, u8(config.name) .. "##" .. index, imgui.ImVec2(-30, 20)) then
                        settings.main.activeConf = index
                        json():Save(settings)
                    end

                    if index > 1 then
                        imgui.SameLine()
                        if imgui.Button(u8'X##'..index, imgui.ImVec2(20, 20)) then
                            table.remove(settings.configs, index)
                            if settings.main.activeConf >= index then
                                settings.main.activeConf = 1
                            end
                            json():Save(settings)
                        end
                    end
                end
            imgui.EndChild()

            imgui.SameLine()

            imgui.BeginChild('::chatSelectChild', imgui.ImVec2(150, -30), true, imgui.WindowFlags.NoScrollbar)
                for _, chat in ipairs(chatTypes) do
                    if imgui.ButtonActivated(selectedChat == chat.id, u8(chat.name), imgui.ImVec2(-1, 20)) then
                        selectedChat = chat.id
                    end
                end
            imgui.EndChild()

            imgui.SameLine()

            imgui.BeginChild('::mainChild', imgui.ImVec2(0, -30), true)
                if selectedChat then
                    local chat = chatTypes[1]
                    for _, c in ipairs(chatTypes) do
                        if c.id == selectedChat then
                            chat = c
                            break
                        end
                    end

                    imgui.Text(u8'Настройки для: ' .. u8(chat.name))
                    imgui.Separator()

                    if imgui.Checkbox(u8'Включить##'..chat.id, imgui.new.bool(settings.configs[settings.main.activeConf].adv[chat.id].enabled)) then
                        settings.configs[settings.main.activeConf].adv[chat.id].enabled = not settings.configs[settings.main.activeConf].adv[chat.id].enabled
                        settings.main.enabled = false
                        json():Save(settings)
                    end

                    imgui.PushItemWidth(100)
                    local delay = imgui.new.int(settings.configs[settings.main.activeConf].adv[chat.id].delay)
                    if imgui.InputInt(u8'Задержка между повторами##'..chat.id, delay) then
                        settings.configs[settings.main.activeConf].adv[chat.id].delay = delay[0]
                        if settings.configs[settings.main.activeConf].adv[chat.id].delay < 1 then 
                            settings.configs[settings.main.activeConf].adv[chat.id].delay = 1 
                        end
                        settings.main.enabled = false
                        json():Save(settings)
                    end
                    imgui.Tooltip(u8'Устанавливает время ожидания между отправкой сообщений (в секундах)')

                    if chat.id ~= 'ad' then
                        local lineDelay = imgui.new.int(settings.configs[settings.main.activeConf].adv[chat.id].lineDelay or 1)
                        if imgui.InputInt(u8'Задержка между строчками##'..chat.id, lineDelay) then
                            settings.configs[settings.main.activeConf].adv[chat.id].lineDelay = lineDelay[0]
                            if settings.configs[settings.main.activeConf].adv[chat.id].lineDelay < 1 then 
                                settings.configs[settings.main.activeConf].adv[chat.id].lineDelay = 1 
                            end
                            json():Save(settings)
                        end
                        imgui.Tooltip(u8'Устанавливает задержку между отправкой строк в\nмногострочных сообщениях (в секундах)')
                    end
                    imgui.PopItemWidth()

                    if chat.id == 'ad' then
                        imgui.PushItemWidth(150)

                        local centrint = imgui.new.int(settings.configs[settings.main.activeConf].adv[chat.id].centr)
                        if imgui.Combo("##adCenter", centrint, centerIndex, #adCenters) then
                            settings.configs[settings.main.activeConf].adv[chat.id].centr = centrint[0]
                            json():Save(settings)
                        end
                        imgui.Tooltip(u8'Выберите город, в котором будет размещено объявление.\nПри выборе "Автоматически" объявление будет размещено в городе,\nгде последний раз редактировали объявление')
                        
                        imgui.SameLine()
                        
                        local adTypeInt = imgui.new.int(settings.configs[settings.main.activeConf].adv[chat.id].type)
                        if imgui.Combo("##adType", adTypeInt, adTypeIndex, #adTypes) then
                            settings.configs[settings.main.activeConf].adv[chat.id].type = adTypeInt[0]
                            json():Save(settings)
                        end
                        imgui.Tooltip(u8'Выберите тип объявления: обычное, VIP или реклама бизнеса')
                        imgui.PopItemWidth()
                    end

                    if chat.id == 'vr' then
                        if imgui.Checkbox(u8'Отправка рекламой в випчат', imgui.new.bool(settings.configs[settings.main.activeConf].adv[chat.id].vrAdvertisementSend)) then
                            settings.configs[settings.main.activeConf].adv[chat.id].vrAdvertisementSend = not settings.configs[settings.main.activeConf].adv[chat.id].vrAdvertisementSend
                            settings.main.enabled = false
                            json():Save(settings)
                        end
                        imgui.Tooltip(u8'При активности скрипт будет автоматически\nоплачивать рекламу в VIP чат')
                    end
                    
                    imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(0.1, 0.1, 0.1, 1.0))
                    if imgui.BeginChild('Messages##'..chat.id, imgui.ImVec2(-1, 150), true) then
                        for i, msg in ipairs(settings.configs[settings.main.activeConf].adv[chat.id].messages) do
                            if imgui.Button(u8'X##'..chat.id..i, imgui.ImVec2(20, 20)) then
                                table.remove(settings.configs[settings.main.activeConf].adv[chat.id].messages, i)
                                settings.main.enabled = false
                                json():Save(settings)
                            end
                            imgui.SameLine()
                            imgui.Text(u8(msg))
                        end
                        imgui.EndChild()
                    end
                    imgui.PopStyleColor()

                    imgui.PushItemWidth(-1)
                    imgui.InputTextWithHint('##newMsg'..chat.id, u8'Введите новое сообщение...', newMessage, 256)
                    if imgui.Button(u8'Добавить сообщение##'..chat.id, imgui.ImVec2(-1, 25)) then
                        local msg = u8:decode(ffi.string(newMessage))
                        if #msg > 0 then
                            if chat.id == 'ad' then
                                if #msg > chat.maxLength then
                                    sms('Сообщение слишком длинное! Максимум ' .. chat.maxLength .. ' символов.')
                                elseif #settings.configs[settings.main.activeConf].adv[chat.id].messages == 0 then
                                    settings.configs[settings.main.activeConf].adv[chat.id].messages = {msg}
                                else
                                    sms('Для объявления можно добавлять только одно сообщение!')
                                end
                            else
                                if #msg > chat.maxLength then
                                    sms('Сообщение слишком длинное! Максимум ' .. chat.maxLength .. ' символов.')
                                else
                                    settings.configs[settings.main.activeConf].adv[chat.id].messages = settings.configs[settings.main.activeConf].adv[chat.id].messages or {}
                                    table.insert(settings.configs[settings.main.activeConf].adv[chat.id].messages, msg)
                                end
                            end
                            if #msg <= chat.maxLength then
                                settings.main.enabled = false
                                json():Save(settings)
                            end
                        end
                    end
                    imgui.PopItemWidth()
                else
                    imgui.TextColored(imgui.ImVec4(0.7, 0.7, 0.7, 1.0), u8"Выберите тип чата слева")
                end
            imgui.EndChild()

            if imgui.Button(u8'Создать', imgui.ImVec2(-(resX / 3), 20)) then
                imgui.OpenPopup('##createConfigPopup')
            end

            imgui.SameLine()

            if imgui.Checkbox(u8'Включить скрипт', imgui.new.bool(settings.main.enabled)) then
                settings.main.enabled = not settings.main.enabled
                json():Save(settings)
            end

            imgui.SameLine()

            if imgui.Checkbox(u8'Отключать при не активности', imgui.new.bool(settings.main.inactiveShutdown)) then
                settings.main.inactiveShutdown = not settings.main.inactiveShutdown
                json():Save(settings)
            end
            imgui.Tooltip(u8'При включении этой опции скрипт будет автоматически приостанавливаться,\nесли не обнаружит активность игрока')

            if settings.main.inactiveShutdown then
                imgui.SameLine()
                imgui.PushItemWidth(100)
                sleepInactiveShutdownInt[0] = settings.main.sleepInactiveShutdown
                if imgui.InputInt(u8'Время до отключения (минуты)', sleepInactiveShutdownInt) then
                    settings.main.sleepInactiveShutdown = sleepInactiveShutdownInt[0]
                    if settings.main.sleepInactiveShutdown < 1 then settings.main.sleepInactiveShutdown = 1 end
                    json():Save(settings)
                end
                imgui.Tooltip(u8'Время в минутах, после которого скрипт приостановит\nработу при отсутствии активности')
                imgui.PopItemWidth()
            end
        end

        if imgui.BeginPopupModal('##createConfigPopup', _, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoTitleBar) then
            imgui.SetWindowSizeVec2(imgui.ImVec2(200, 120))
            imgui.SetWindowPosVec2(imgui.ImVec2(resX / 2 - 100, resY / 2 - 50))
            
            imgui.PushItemWidth(-1)
            imgui.InputTextWithHint('##configName', u8'Название конфигурации', configName, 32, imgui.InputTextFlags.AutoSelectAll)
            imgui.PopItemWidth()
            
            if imgui.Button(u8'Создать', imgui.ImVec2(-1, 25)) then
                if #u8:decode(ffi.string(configName)) > 0 then
                    table.insert(settings.configs, {
                        ["name"] = u8:decode(ffi.string(configName)),
                        ["vrAdvertisementSend"] = true,
                        ["adv"] = defaultADV
                    })
                    json():Save(settings)
                    imgui.CloseCurrentPopup()
                end
            end
            
            imgui.Separator()

            if imgui.Button(u8'Закрыть', imgui.ImVec2(-1, 25)) then
                imgui.CloseCurrentPopup()
            end
            imgui.EndPopup()
        end

        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 300, update.available and 150 or 100
        
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY - sizeY - 10), imgui.Cond.Always, imgui.ImVec2(0.5, 0))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.Always)
        
        if imgui.Begin('##info', _, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoTitleBar) then
            imgui.TextColored(imgui.ImVec4(0.7, 0.7, 0.7, 1.0), u8"Разработчик:")
            imgui.Link("https://vk.com/id620137656", u8"VK: vk.com/id620137656")
            imgui.Link("https://t.me/discq192", u8"Telegram: @discq192")
            
            if update.available then
                imgui.Separator()
                imgui.TextColored(imgui.ImVec4(1, 0.8, 0, 1), u8"Доступно обновление " .. update.version)
                if imgui.Button(u8"Обновить", imgui.ImVec2(-1, 25)) then
                    os.execute('explorer ' .. update.download)
                end
            end
        end
        imgui.End()
        
        imgui.PopStyleVar()
    end
)

function sampev.onShowDialog(id, style, title, button1, button2, text)
    local currentConfig = settings.configs[settings.main.activeConf]
    
    if id == 25623 and currentConfig.adv.vr.enabled then
        sampSendDialogResponse(id, currentConfig.adv.vr.vrAdvertisementSend and 1 or 0, 65535, "")
        return false
    end

    if (currentConfig.adv.ad.enabled and settings.main.enabled) or isAdvCommand then
        if title:find("Выберите радиостанцию") and text:find("Радиостанция") then
            local lines = {}
            for line in text:gmatch("[^\r\n]+") do
                if not line:find("{[a-fA-F0-9]+}") then
                    table.insert(lines, line)
                end
            end

            local function getSeconds(line)
                local total = 0
                if line:find("час") then
                    local h, m, s = line:match("(%d+) час (%d+) мин (%d+) сек")
                    total = h * 3600 + m * 60 + s
                elseif line:find("мин") then
                    local m, s = line:match("(%d+) мин (%d+) сек")
                    total = m * 60 + s
                elseif line:find("сек") then
                    total = tonumber(line:match("(%d+) сек"))
                end
                return total
            end

            local times = {
                getSeconds(lines[1]),
                getSeconds(lines[2]),
                getSeconds(lines[3])
            }

            local response
            if currentConfig.adv.ad.centr == 0 then
                local minTime = math.min(table.unpack(times))
                if minTime == times[1] then
                    response = 0 -- LS
                    sms('/ad - Последняя редакция была в Радиоцентре Лос-Сантос')
                elseif minTime == times[2] then
                    response = 1 -- LV
                    sms('/ad - Последняя редакция была в Радиоцентре Лас-Вентурас')
                else
                    response = 2 -- SF
                    sms('/ad - Последняя редакция была в Радиоцентре Сан-Фиерро')
                end
            else
                -- Ручной выбор города
                response = currentConfig.adv.ad.centr == 1 and 2 or -- SF
                          currentConfig.adv.ad.centr == 2 and 1 or -- LV
                          currentConfig.adv.ad.centr == 3 and 0    -- LS
            end
            
            sampSendDialogResponse(id, 1, response, "")
            return false
        end

        if title:find("Подача объявления") and text:find("Выберите тип объявления") then
            local response = currentConfig.adv.ad.type == 0 and 0 or -- Обычное
                           currentConfig.adv.ad.type == 1 and 1 or -- VIP
                           3                                        -- Реклама бизнеса
            
            sampSendDialogResponse(id, 1, response, "")
            return false
        end

        if title:find("Подача объявления %| Подтверждение") then
            sampSendDialogResponse(id, 1, 65535, "")
            lastMessageTime.ad = os.time()
            isAdvCommand = false
            return false
        end
    end

    if id == 15379 and currentConfig.adv.ad.enabled and settings.main.enabled then
        lastMessageTime.ad = os.time() + currentConfig.adv.ad.delay
        sms('/ad - Объявление не отредактировали, повторная попытка через {mc}'.. currentConfig.adv.ad.delay .. ' секунд')
        sampSendDialogResponse(id, 0, 65535, "")
        return false
    end
end


function sampev.onConnectionClosed()
    settings.main.enabled = false
    json():Save(settings)
end

function sampev.onConnectionRejected()
    settings.main.enabled = false
    json():Save(settings)
end

function onWindowMessage(msg, wparam, lparam)
    if msg == 0x100 or msg == 0x101 or msg == 523 or msg == 513 or msg == 516 then
        if (wparam == keys.VK_ESCAPE and menu.state) and not isPauseMenuActive() then
            consumeWindowMessage(true, false);
            if msg == 0x101 then menu.switch() end
        end
        lastSendKeyMessage = os.time()

        if stateLastSendKeyMessage then
            sms('Работа скрипта {mc}возобновлена{FFFFFF}!')
            stateLastSendKeyMessage = false
        end
    end
end

function main()
    while true do if isSampAvailable() and sampIsLocalPlayerSpawned() then break end wait(0) end
    
    checkUpdates()
    
    sms("Успешно загружено! Активация: {mc}/autoad")

    sampRegisterChatCommand('autoad', function()
        menu.switch()
    end)

    sampRegisterChatCommand('adv', function (arg)
        if #arg < 1 then
            sms('Использование команды: {mc}/adv [message]')
        elseif #arg < 20 or #arg > 80 then
            sms('В тексте объявления должно быть от 20 до 80 символов.')
        else
            
            isAdvCommand = true
            sampSendChat('/ad ' .. arg)
        end
    end)

    wait(3000)

    while true do
        if settings.main.enabled then
            if not stateLastSendKeyMessage and settings.main.inactiveShutdown and os.time() - lastSendKeyMessage > tonumber(settings.main.sleepInactiveShutdown) * 60 then
                stateLastSendKeyMessage = true
                sms('Состояние скрипта {mc}приостоновлено{FFFFFF}! Обнаружена не активность в течение {mc}' .. settings.main.sleepInactiveShutdown * 60 .. '{FFFFFF} секунд!')
            elseif not stateLastSendKeyMessage then
                local currentConfig = settings.configs[settings.main.activeConf]
                for _, chatType in ipairs(chatTypes) do
                    local chatId = chatType.id
                    local chatSettings = currentConfig.adv[chatId]
                    
                    if not lastMessageTime[chatId] then
                        lastMessageTime[chatId] = 0
                    end
                    
                    if chatSettings.enabled and #chatSettings.messages > 0 then
                        if os.time() - lastMessageTime[chatId] >= chatSettings.delay then
                            for _, message in ipairs(chatSettings.messages) do
                                if chatId == 'vr' then
                                    sampSendChat('/vr ' .. message)
                                else
                                    sampSendChat('/' .. chatId .. ' ' .. message)
                                end
                                
                                wait(chatSettings.lineDelay * 1000)
                            end
                            
                            lastMessageTime[chatId] = os.time()
                        end
                    end
                end
            end
        end
        wait(100)
    end
end

function imgui.Link(link, text)
    text = text or link
    local tSize = imgui.CalcTextSize(text)
    local p = imgui.GetCursorScreenPos()
    local DL = imgui.GetWindowDrawList()
    local col = { 0xFFFF7700, 0xFFFF9900 }
    if imgui.InvisibleButton("##" .. link, tSize) then os.execute("explorer " .. link) end
    local color = imgui.IsItemHovered() and col[1] or col[2]
    DL:AddText(p, color, text)
    DL:AddLine(imgui.ImVec2(p.x, p.y + tSize.y), imgui.ImVec2(p.x + tSize.x, p.y + tSize.y), color)
end

function imgui.ButtonActivated(activated, ...)
    if activated then
        imgui.PushStyleColor(imgui.Col.Button, imgui.GetStyle().Colors[imgui.Col.TextSelectedBg])
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.GetStyle().Colors[imgui.Col.TextSelectedBg])
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.GetStyle().Colors[imgui.Col.TextSelectedBg])

        local btn = imgui.Button(...)

        imgui.PopStyleColor(3)
        return btn
    else
        return imgui.Button(...)
    end
end

function imgui.Tooltip(text)
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.Text(text)
        imgui.EndTooltip()
    end
end

function sms(text)
	local text = text:gsub('{mc}', '{3487ff}')
	sampAddChatMessage('[AutoAdByDiscq192] {FFFFFF}' .. tostring(text), 0x3487ff)
end

function theme()

	imgui.SwitchContext()
	local style = imgui.GetStyle()
	local colors = style.Colors
	local clr = imgui.Col
	local ImVec4 = imgui.ImVec4
	local ImVec2 = imgui.ImVec2

	--style.WindowPadding = ImVec2(5, 5) -- 
	--style.FramePadding = ImVec2(5, 5)
	style.WindowRounding = 4.0
	style.WindowTitleAlign = imgui.ImVec2(0.5, 0.84)
	style.ChildRounding = 2.0
	style.FrameRounding = 4.0
	style.ItemSpacing = imgui.ImVec2(10.0, 10.0)
	--style.ItemInnerSpacing = ImVec2(8, 6)
	--style.IndentSpacing = 25.0
	style.ScrollbarSize = 18.0
	style.ScrollbarRounding = 0
	style.GrabMinSize = 8.0
	style.GrabRounding = 1.0

	colors[clr.Text] = ImVec4(0.95, 0.96, 0.98, 1.00)
	colors[clr.TextDisabled] = ImVec4(0.50, 0.50, 0.50, 1.00)

	colors[clr.TitleBgActive] = ImVec4(0.07, 0.11, 0.13, 1.00) --ImVec4(0.08, 0.10, 0.12, 0.90)
	colors[clr.TitleBg] = colors[clr.TitleBgActive]
	colors[clr.TitleBgCollapsed] = ImVec4(0.00, 0.00, 0.00, 0.51)

	colors[clr.WindowBg]		= colors[clr.TitleBgActive]
	colors[clr.ChildBg] = ImVec4(0.07, 0.11, 0.13, 1.00)

	colors[clr.PopupBg] = ImVec4(0.08, 0.08, 0.08, 1.00)
	colors[clr.Border] = ImVec4(0.43, 0.43, 0.50, 0.50)
	colors[clr.BorderShadow] = ImVec4(0.00, 0.00, 0.00, 0.00)
	
	 
	colors[clr.Separator] = colors[clr.Border]
	colors[clr.SeparatorHovered] = colors[clr.Border]
	colors[clr.SeparatorActive] = colors[clr.Border]

	colors[clr.MenuBarBg] = ImVec4(0.15, 0.18, 0.22, 1.00)

	colors[clr.CheckMark] = ImVec4(0.00, 0.50, 0.50, 1.00)

	colors[clr.SliderGrab] = ImVec4(0.28, 0.56, 1.00, 1.00)
	colors[clr.SliderGrabActive] = ImVec4(0.37, 0.61, 1.00, 1.00)

	colors[clr.Button] = ImVec4(0.15, 0.20, 0.24, 1.00)
	colors[clr.ButtonHovered] = ImVec4(0.20, 0.25, 0.29, 1.00)
	colors[clr.ButtonActive] = colors[clr.ButtonHovered]

	colors[clr.ScrollbarBg] = ImVec4(0.02, 0.02, 0.02, 0.39)
	colors[clr.ScrollbarGrab] = colors[clr.Button]
	colors[clr.ScrollbarGrabHovered] = colors[clr.ButtonHovered]
	colors[clr.ScrollbarGrabActive] = colors[clr.ButtonHovered]

	colors[clr.FrameBg] = colors[clr.Button]
	colors[clr.FrameBgHovered] = colors[clr.ButtonHovered]
	colors[clr.FrameBgActive] = colors[clr.ButtonHovered]

	-- colors[clr.ComboBg] = ImVec4(0.35, 0.35, 0.35, 1.00)

	colors[clr.Header] = colors[clr.Button]
	colors[clr.HeaderHovered] = colors[clr.ButtonHovered]
	colors[clr.HeaderActive] = colors[clr.HeaderHovered]

	colors[clr.ResizeGrip] = ImVec4(0.26, 0.59, 0.98, 0.25)
	colors[clr.ResizeGripHovered] = ImVec4(0.26, 0.59, 0.98, 0.67)
	colors[clr.ResizeGripActive] = ImVec4(0.06, 0.05, 0.07, 1.00)

	-- colors[clr.CloseButton] = ImVec4(0.40, 0.39, 0.38, 0.16)
	-- colors[clr.CloseButtonHovered] = imgui.ImVec4(0.50, 0.25, 0.00, 1.00)
	-- colors[clr.CloseButtonActive] = colors[clr.CloseButtonHovered]

	colors[clr.PlotLines] = ImVec4(0.61, 0.61, 0.61, 1.00)
	colors[clr.PlotLinesHovered] = ImVec4(1.00, 0.43, 0.35, 1.00)

	colors[clr.PlotHistogram] = ImVec4(0.90, 0.70, 0.00, 1.00)
	colors[clr.PlotHistogramHovered] = ImVec4(1.00, 0.60, 0.00, 1.00)

	-- colors[clr.TextSelectedBg] = colors[clr.CloseButtonHovered]

	-- colors[clr.ModalWindowDarkening] = ImVec4(1.00, 0.98, 0.95, 0.73)
end
