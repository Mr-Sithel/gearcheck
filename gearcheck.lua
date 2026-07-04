addon.name = 'GearCheck'
addon.author = 'Sithel'
addon.version = '1.0'

require('common')
local chat        = require('chat')

local inventory = AshitaCore:GetMemoryManager():GetInventory()
local resources = AshitaCore:GetResourceManager()

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
-- Find correct LuAshitacast folder (Stutter-Free Native Scan)
-----------------------------------------------------------------------
local function findProfileFolder()
    -- Index 0 is always safely populated with your own character name
    local char = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0)
    if not char or char == "" then
        print(chat.header(addon.name):append(chat.message('\31\123Could not get character name.')))
        return nil
    end

    local base = string.format('%sconfig\\addons\\LuAshitacast\\', AshitaCore:GetInstallPath())
    
    -- Keep the native stutter-free folder indexing
    local directories = ashita.fs.get_directory(base)
    if not directories then
        print(chat.header(addon.name):append(chat.message('\31\123Failed to read LuAshitacast directory.')))
        return nil
    end

    local targetFolder = nil
    for _, folder in ipairs(directories) do
        if folder:lower():find(char:lower()) then
            targetFolder = folder
            break
        end
    end

    if not targetFolder then
        print(string.format('\31\5GearCheck: \31\123Could not locate LuAshitacast folder for %s.', char))
        return nil
    end

    return base .. targetFolder .. '\\'
end

-----------------------------------------------------------------------
-- Parsing Luashitacast profiles for gear
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

    -- Scan the entire file line by line
    for line in text:gmatch("[^\r\n]+") do
        local cleanLine = line:gsub("%s*%-%-.*$", "")

        if cleanLine ~= "" then
            local slot = cleanLine:match("%s*([%w_]+)%s*=")
            
            -- Matches standard slots OR dynamic custom item keys (Item1 through Item20)
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

    -------------------------------------------------------------------
    -- Print parsed count
    -------------------------------------------------------------------
    local count = 0
    for _ in pairs(gearNeeded) do count = count + 1 end

    local msg = string.format(
        '\31\207Parsed \31\204%d \31\207items from profile \31\204%s\31\207.lua',
        count,
        job or 'JOB'
    )

    print(chat.header(addon.name):append(chat.message(msg)))
    return gearNeeded
end

-----------------------------------------------------------------------
-- Load profile (text parse only)
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
-- Find item location in other containers
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
-- Main gearcheck logic
-----------------------------------------------------------------------
local function gearcheck(job)
    local gearNeeded = loadProfile(job)
    if not gearNeeded then
        print(chat.header(addon.name):append(chat.message('\31\207Aborting gear check... \31\38No job profile found')))
        return
    end

    local gearFound = scanContainers(MAIN_CONTAINERS)
    local missing = {}
    local missingColor = '\31\38'
    local locColor     = '\31\06'
    local itemColor    = '\31\36'

    for itemName,_ in pairs(gearNeeded) do
        if not gearFound[itemName] then
            local loc = findItemLocation(itemName)
            local locText = loc and (locColor .. loc) or (missingColor .. 'Not Found')

            table.insert(missing,
                string.format('%s\31\01 - %s%s', locText, itemColor, itemName)
            )
        end
    end

    if #missing == 0 then
        print(chat.header(addon.name):append(chat.message('\31\204All gear/items accounted for.')))
    else
        -------------------------------------------------------------------
        -- Sort order
        -------------------------------------------------------------------
        table.sort(missing, function(a, b)
            -- Changed internal string scanning to search for 'Not Found'
            local aNotFound = a:find('Not Found')
            local bNotFound = b:find('Not Found')

            if aNotFound and not bNotFound then return false end
            if bNotFound and not aNotFound then return true end
            return a < b
        end)
    
        for _,line in ipairs(missing) do
            print('\31\200' .. line)
        end
    end
end

-----------------------------------------------------------------------
-- Command handler
-----------------------------------------------------------------------
ashita.events.register('command', 'gearcheck_cmd', function(e)
    local args = e.command:args()
    if #args == 0 then return end

    local cmd = args[1]:lower()
    if cmd ~= '/gearcheck' and cmd ~= '/gc' then return end

    if args[2] and args[2]:lower() == 'validate' then
        local jobName = getCurrentJobName()
        if not jobName then
            print(chat.header(addon.name):append(chat.message('\31\123Could not determine your current job.')))
            --print(chat.header(addon.name):append(chat.message('\31\204/anon \31\207is the issue...')))
            return true
        end

        gearcheck(jobName)
        return true
    end

    if args[2] then
        local manualJob = args[2]:upper()
        -- Handle shorthand verification
        local valid = resources:GetString("jobs.names_abbr", manualJob)
        if not valid then
            -- Fallback verification check against actual game resources structure
            print(string.format('\31\200GearCheck: Unknown job "%s".', manualJob))
            return true
        end

        gearcheck(manualJob)
        return true
    end

    print(chat.header(addon.name):append(chat.message('\31\207Commands:')))
    print('\31\207 /gearcheck or /gc')
    print('\31\207 /gc validate \31\204(validate current job)')
    print('\31\207 /gc <job> \31\204(Ex: /gc sam)')

    return true
end)