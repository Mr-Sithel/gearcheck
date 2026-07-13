addon.name    = 'GearCheck'
addon.author  = 'Sithel'
addon.version = '1.1'

require('common')
local chat     = require('chat')
local imgui    = require('imgui')
local settings = require('settings')

local inventory = AshitaCore:GetMemoryManager():GetInventory()
local resources = AshitaCore:GetResourceManager()

-----------------------------------------------------------------------
-- XIUI Theme Loader
-----------------------------------------------------------------------
local default_settings = T{
    theme = 'gold',
}
local gearcheck_settings = settings.load(default_settings)

local function loadTheme(name)
    return require('data/theme_' .. name)
end

local theme = loadTheme(gearcheck_settings.theme)

settings.register('settings', 'gearcheck_settings_update', function(new_settings)
    gearcheck_settings = new_settings
end)

local function SaveSettings()
    settings.save()
end

-----------------------------------------------------------------------
-- Containers
-----------------------------------------------------------------------
local MAIN_CONTAINERS = {0, 8, 10, 11, 12, 13, 14, 15, 16}
local OTHER_CONTAINERS = {
    {id=1, name='Safe'},
    {id=2, name='Storage'},
    {id=4, name='Locker'},
    {id=5, name='Satchel'},
    {id=6, name='Sack'},
    {id=7, name='Case'},
    {id=3, name='Temporary'},
}

-----------------------------------------------------------------------
-- UI State
-----------------------------------------------------------------------
local ui_state = {
    is_open      = { true },
    results      = {},
    current_job  = ' - ',
    parsed_count = 0,
    activeTab    = 1,
    error_message = nil,
}

-----------------------------------------------------------------------
-- Get current job name
-----------------------------------------------------------------------
local function getCurrentJobName()
    local player = AshitaCore:GetMemoryManager():GetPlayer()
    if not player then return nil end

    local jobId = player:GetMainJob()
    if not jobId or jobId == 0 then return nil end

    return resources:GetString("jobs.names_abbr", jobId)
end

-----------------------------------------------------------------------
-- Find LuAshitacast folder
-----------------------------------------------------------------------
local function findProfileFolder()
    local char = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0)
    if not char or char == "" then
        print(chat.header(addon.name):append(chat.message('\31\123Could not get character name.')))
        return nil
    end

    local base = string.format('%sconfig\\addons\\LuAshitacast\\', AshitaCore:GetInstallPath())
    local directories = ashita.fs.get_directory(base)
    if not directories then
        print(chat.header(addon.name):append(chat.message('\31\123Failed to read LuAshitacast directory.')))
        return nil
    end

    for _, folder in ipairs(directories) do
        if folder:lower():find(char:lower()) then
            return base .. folder .. '\\'
        end
    end

    print(string.format('\31\5GearCheck: \31\123Could not locate LuAshitacast folder for %s.', char))
    return nil
end

-----------------------------------------------------------------------
-- Parse LuAshitacast profile
-----------------------------------------------------------------------
local function parseProfileSets(path, job)
    local file = io.open(path, 'r')
    if not file then return nil end

    local text = file:read('*a')
    file:close()

    local gearNeeded = {}
    local validSlots = {
        Main=true, Sub=true, Range=true, Ammo=true,
        Head=true, Neck=true, Ear1=true, Ear2=true,
        Body=true, Hands=true, Ring1=true, Ring2=true,
        Back=true, Waist=true, Legs=true, Feet=true,
    }

    for line in text:gmatch("[^\r\n]+") do
        local cleanLine = line:gsub("%s*%-%-.*$", "")
        if cleanLine ~= "" then
            local slot = cleanLine:match("%s*([%w_]+)%s*=")
            if slot and (validSlots[slot] or slot:match("^Item%d+$")) then
                local protectedLine = cleanLine:gsub("\\'", "\001")
                for rawItem in protectedLine:gmatch("'([^']+)'") do
                    if rawItem ~= "Name" then
                        local item = rawItem:gsub("\001", "'"):gsub("\\", ""):gsub("^%s*(.-)%s*$", "%1")
                        local resItem = resources:GetItemByName(item)
                        if resItem ~= nil then
                            gearNeeded[item] = 1
                        end
                    end
                end
            end
        end
    end

    local count = 0
    for _ in pairs(gearNeeded) do count = count + 1 end

    return gearNeeded
end

-----------------------------------------------------------------------
-- Load profile
-----------------------------------------------------------------------
local function loadProfile(job)
    local folder = findProfileFolder()
    if not folder then return nil end

    local path = string.format('%s%s.lua', folder, job)
    return parseProfileSets(path, job)
end

-----------------------------------------------------------------------
-- Scan inventory + wardrobes
-----------------------------------------------------------------------
local function scanContainers(containerList)
    local found = {}

    for _,containerId in ipairs(containerList) do
        for i = 0, inventory:GetContainerCountMax(containerId) do
            local itemEntry = inventory:GetContainerItem(containerId, i)
            if itemEntry and itemEntry.Id ~= 0 and itemEntry.Id ~= 65535 then
                local item = resources:GetItemById(itemEntry.Id)
                if item and item.Name and item.Name[1] then
                    found[item.Name[1]] = true
                end
            end
        end
    end

    return found
end

-----------------------------------------------------------------------
-- Find item location
-----------------------------------------------------------------------
local function findItemLocation(itemName)
    for _,c in ipairs(OTHER_CONTAINERS) do
        for i = 0, inventory:GetContainerCountMax(c.id) do
            local itemEntry = inventory:GetContainerItem(c.id, i)
            if itemEntry and itemEntry.Id ~= 0 and itemEntry.Id ~= 65535 then
                local item = resources:GetItemById(itemEntry.Id)
                if item and item.Name and item.Name[1] == itemName then
                    return c.name
                end
            end
        end
    end
    return nil
end

-----------------------------------------------------------------------
-- Clear UI Parse
-----------------------------------------------------------------------
local function ui_clear()
    ui_state.results = {}
    ui_state.parsed_count = 0
    ui_state.current_job = "-"
    ui_state.error_message = {}
end

-----------------------------------------------------------------------
-- Chat GearCheck 
-----------------------------------------------------------------------
local function gearcheck(job)
    local gearNeeded = loadProfile(job)
    if not gearNeeded then
        print(chat.header(addon.name):append(chat.message('\31\207Aborting gear check... \31\38No job profile found')))
        return
    end

    local gearFound = scanContainers(MAIN_CONTAINERS)
    local missing = {}

    for itemName,_ in pairs(gearNeeded) do
        if not gearFound[itemName] then
            local loc = findItemLocation(itemName)
            local locText = loc and ('\31\06' .. loc) or '\31\38Not Found'
            table.insert(missing, string.format('%s\31\01 - \31\36%s', locText, itemName))
        end
    end

    if #missing == 0 then
        print(chat.header(addon.name):append(chat.message('\31\204All gear/items accounted for.')))
    else
        table.sort(missing)
        for _,line in ipairs(missing) do
            print('\31\200' .. line)
        end
    end
end

-----------------------------------------------------------------------
-- UI Validation 
-----------------------------------------------------------------------
local function ui_validate(job)
    ui_state.results = {}
    ui_state.current_job = job

    local gearNeeded = loadProfile(job)
    if not gearNeeded then
        ui_state.parsed_count = 0
        ui_state.results = {}
        ui_state.error_message = "NO JOB PROFILE FOUND!\n\nEnsure LuAshitaCast is installed and a\nprofile exists for this job.\n\nPath:\n\n...config\\addons\\LuAshitacast\\\n   <charname>\\<job>.lua"
        return
    end

    ui_state.error_message = nil


    local gearFound = scanContainers(MAIN_CONTAINERS)

    local count = 0
    for _ in pairs(gearNeeded) do count = count + 1 end
    ui_state.parsed_count = count

    for itemName,_ in pairs(gearNeeded) do
        if not gearFound[itemName] then
            local loc = findItemLocation(itemName)
            table.insert(ui_state.results, {
                item = itemName,
                location = loc or "Not Found",
                is_found = loc ~= nil
            })
        end
    end

    table.sort(ui_state.results, function(a, b)
        if a.is_found ~= b.is_found then
            return a.is_found
        end
        return a.item < b.item
    end)
end

-----------------------------------------------------------------------
-- ImGui Window
-----------------------------------------------------------------------
ashita.events.register('d3d_present', 'gearcheck_ui_render', function()
    if not ui_state.is_open[1] then return end

    imgui.SetNextWindowSize({300, 455}, ImGuiCond_Always)

    theme.push()

    if imgui.Begin('GearCheck', ui_state.is_open) then

        -- Validate Button
        if imgui.Button('Validate Current Job', { -1, 24 }) then
            local job = getCurrentJobName()
            if job then
                ui_validate(job)
            else
                ui_state.current_job = "Unknown"
            end
        end

        -- Clear Button
        if imgui.Button('Clear', { -1, 24 }) then
            ui_clear()
        end

        -- Settings Button
        if imgui.Button('Settings', { -1, 24 }) then
            ui_state.activeTab = 2
        end

        imgui.Separator()

        ---------------------------------------------------------
        -- TAB 1: RESULTS
        ---------------------------------------------------------
        if ui_state.activeTab == 1 then

            imgui.Text('Job Profile:')
            imgui.SameLine()
            imgui.TextColored(theme.colors.good, ui_state.current_job)

            imgui.Text('Total Profile Items Parsed:')
            imgui.SameLine()
            imgui.TextColored(theme.colors.good, tostring(ui_state.parsed_count))

            imgui.Separator()

            imgui.BeginChild('ResultsList', { -1, -1 })

            if ui_state.error_message then
                imgui.TextColored(theme.colors.bad, ui_state.error_message)
                imgui.EndChild()
                imgui.End()
                theme.pop()
                return
            end

            if #ui_state.results == 0 and ui_state.parsed_count > 0 then
                imgui.TextColored(theme.colors.good, "All Gear / Items accounted for.")
            else
                for _, res in ipairs(ui_state.results) do
                    if res.is_found then
                        imgui.TextColored(theme.colors.good, string.format('[%s]', res.location))
                    else
                        imgui.TextColored(theme.colors.bad, '[Not Found]')
                    end
                    imgui.SameLine(90)
                    imgui.Text(res.item)
                end
            end

            imgui.EndChild()

        ---------------------------------------------------------
        -- TAB 2: SETTINGS
        ---------------------------------------------------------
        else
            imgui.Text("Theme")
            imgui.SameLine()
            imgui.TextDisabled("(?)")
            if imgui.IsItemHovered() then
                imgui.SetTooltip("Choose a color theme for GearCheck.")
            end

            local themes = { 'blue', 'gold', 'red', 'gray' }
            local current = gearcheck_settings.theme

            imgui.PushItemWidth(140)
            if imgui.BeginCombo("##gc_theme_select", current) then
                for _, t in ipairs(themes) do
                    local selected = (t == current)
                    if imgui.Selectable(t, selected) then
                        gearcheck_settings.theme = t
                        SaveSettings()
                        theme = loadTheme(t)
                    end
                    if selected then imgui.SetItemDefaultFocus() end
                end
                imgui.EndCombo()
            end
            imgui.PopItemWidth()
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            imgui.Text("Print Commands:")
            imgui.TextDisabled("/gc ui")
            if imgui.IsItemHovered() then
                imgui.SetTooltip("Opens UI Window")
            end
            imgui.TextDisabled("/gc validate")
            if imgui.IsItemHovered() then
                imgui.SetTooltip("(Validates Current Job)")
            end
            imgui.TextDisabled("/gc <job>")
            if imgui.IsItemHovered() then
                imgui.SetTooltip("Ex. /gc sam (Manually validates SAM Job Profile)")
            end

            imgui.Spacing()
            imgui.Text("Disclaimer:")
            imgui.TextDisabled("Parses LuAshitaCast job profiles\nto determine gear needed for your\ncurrent job.")
            imgui.TextDisabled("Manually move missing gear, nothing\nis automatically moved or equipped.")
            imgui.Separator()
            imgui.Spacing()


            if imgui.Button("Back to Results", { -1, 24 }) then
                ui_state.activeTab = 1
            end
        end

        imgui.End()
    end

    theme.pop()
end)

-----------------------------------------------------------------------
-- Command handler
-----------------------------------------------------------------------
ashita.events.register('command', 'gearcheck_cmd', function(e)
    local args = e.command:args()
    if #args == 0 then return end

    local cmd = args[1]:lower()
    if cmd ~= '/gearcheck' and cmd ~= '/gc' then return end

    -- UI toggle
    if args[2] and args[2]:lower() == 'ui' then
        ui_state.is_open[1] = not ui_state.is_open[1]
        return true
    end

    -- Validate current job (chat)
    if args[2] and args[2]:lower() == 'validate' then
        local jobName = getCurrentJobName()
        if not jobName then
            print(chat.header(addon.name):append(chat.message('\31\123Could not determine your current job.')))
            return true
        end
        local gearNeeded = loadProfile(jobName)
        if gearNeeded then
            local count = 0
            for _ in pairs(gearNeeded) do count = count + 1 end

            print(chat.header(addon.name):append(chat.message(
                string.format('\31\207Parsed \31\204%d \31\207items from profile \31\204%s.lua', count, jobName)
            )))
        end

        gearcheck(jobName)
        return true
    end

    -- Manual job
    if args[2] then
        local manualJob = args[2]:upper()
        local jobId = nil

        -- Validate job abbreviation
        for id = 1, 22 do
            local abbr = resources:GetString("jobs.names_abbr", id)
            if abbr and abbr:upper() == manualJob then
                jobId = id
                break
            end
        end

        if not jobId then
            print(string.format('\31\200GearCheck: Unknown job "%s".', manualJob))
            return true
        end

        -- Convert jobId → jobName (THF, MNK, etc.)
        local jobName = resources:GetString("jobs.names_abbr", jobId)

        local gearNeeded = loadProfile(jobName)
        if gearNeeded then
            local count = 0
            for _ in pairs(gearNeeded) do count = count + 1 end

            print(chat.header(addon.name):append(chat.message(
                string.format('\31\207Parsed \31\204%d \31\207items from profile \31\204%s.lua', count, jobName)
            )))
        end

        gearcheck(jobName)
        return true
    end

    -- Help
    print(chat.header(addon.name):append(chat.message('\31\207Commands:')))
    print('\31\207 /gc validate')
    print('\31\207 /gc ui')
    print('\31\207 /gc <job>')

    return true
end)
