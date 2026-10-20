local QBCore = exports['qb-core']:GetCoreObject()
local tags = {}
local dispatchAt = {}
local ready = false
local function cleanString(s, max)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('[%c]', ' '):sub(1, max)
    return s
end
local function isValidUrl(s)
    if not s or #s > Config.MaxImageUrlLength then return false end
    local host = s:match('^https://([%w%.%-]+)(/[^%s]*)?$')
    if not host then return false end
    if #Config.AllowedImageHosts > 0 then
        for _, allowed in ipairs(Config.AllowedImageHosts) do
            if host:lower() == allowed:lower() then return true end
        end
        return false
    end
    return true
end
local function notify(src, msg, typ)
    TriggerClientEvent('QBCore:Notify', src, msg, typ or 'primary')
end
local function playerHasItem(src, name)
    local p = QBCore.Functions.GetPlayer(src)
    local item = p and p.Functions.GetItemByName(name)
    return item and (item.amount or 0) > 0
end
local function sync(src)
    if not ready then return end
    TriggerClientEvent('agc-graffiti:client:sync', src, tags)
end
CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `agc_graffiti` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT, `citizenid` VARCHAR(64) NOT NULL,
        `author_name` VARCHAR(128) NOT NULL, `kind` ENUM('text','image') NOT NULL,
        `content` VARCHAR(500) NOT NULL, `color` VARCHAR(7) NOT NULL DEFAULT '#ffffff',
        `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL,
        `nx` DOUBLE NOT NULL, `ny` DOUBLE NOT NULL, `nz` DOUBLE NOT NULL,
        `heading` DOUBLE NOT NULL DEFAULT 0, `scale` FLOAT NOT NULL DEFAULT 1,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), KEY `idx_citizenid` (`citizenid`), KEY `idx_coords` (`x`,`y`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
    local rows = MySQL.query.await('SELECT * FROM agc_graffiti ORDER BY id DESC LIMIT ?', {Config.MaxGraffiti}) or {}
    for _, row in ipairs(rows) do tags[row.id] = row end
    ready = true
    print(('[agc-graffiti] Loaded %d tags'):format(#rows))
end)
RegisterNetEvent('agc-graffiti:server:requestSync', function() sync(source) end)
QBCore.Functions.CreateUseableItem(Config.SprayItem, function(src)
    TriggerClientEvent('agc-graffiti:client:start', src)
end)
QBCore.Functions.CreateUseableItem(Config.CleanItem, function(src)
    TriggerClientEvent('agc-graffiti:client:cleanMode', src)
end)
RegisterNetEvent('agc-graffiti:server:place', function(data)
    local src = source
    local p = QBCore.Functions.GetPlayer(src)
    if not ready or not p or type(data) ~= 'table' then return end
    if not playerHasItem(src, Config.SprayItem) then return notify(src, 'You need a spray can.', 'error') end
    local ped = GetPlayerPed(src)
    local pos = GetEntityCoords(ped)
    local x,y,z = tonumber(data.x),tonumber(data.y),tonumber(data.z)
    local nx,ny,nz = tonumber(data.nx),tonumber(data.ny),tonumber(data.nz)
    local heading, scale = tonumber(data.heading),tonumber(data.scale)
    if not x or not y or not z or not nx or not ny or not nz or not heading or not scale then return end
    if #(pos - vector3(x,y,z)) > Config.MaxDistance + 1.5 then return end
    if math.abs(nx*nx+ny*ny+nz*nz-1) > 0.15 or math.abs(nz) > 0.5 then return end
    if scale < Config.MinScale or scale > Config.MaxScale then return end
    local kind = data.kind
    if kind ~= 'text' and kind ~= 'image' then return end
    local content = cleanString(data.content, kind == 'text' and Config.MaxTextLength or Config.MaxImageUrlLength)
    if not content or #content < 1 then return end
    if kind == 'image' and (not Config.AllowCustomImageUrls or not isValidUrl(content)) then
        local allowed = false
        for _, art in ipairs(Config.AllowedArtwork) do if art.url == content and isValidUrl(content) then allowed = true end end
        if not allowed then return notify(src, 'Image URL is not permitted.', 'error') end
    elseif kind == 'image' and not isValidUrl(content) then return notify(src, 'Use a valid HTTPS image URL.', 'error') end
    local color = cleanString(data.color, 7)
    if not color or not color:match('^#%x%x%x%x%x%x$') then color = '#ffffff' end
    local count, owned = 0, 0
    for _, tag in pairs(tags) do
        count = count + 1
        if tag.citizenid == p.PlayerData.citizenid then owned = owned + 1 end
        if #(vector3(tag.x,tag.y,tag.z)-vector3(x,y,z)) < 0.8 then return notify(src, 'Too close to another tag.', 'error') end
    end
    if count >= Config.MaxGraffiti or owned >= Config.MaxPerPlayer then return notify(src, 'Graffiti limit reached.', 'error') end
    local name = ((p.PlayerData.charinfo or {}).firstname or 'Unknown') .. ' ' .. ((p.PlayerData.charinfo or {}).lastname or '')
    local row = {citizenid=p.PlayerData.citizenid, author_name=name, kind=kind, content=content, color=color,
        x=x,y=y,z=z,nx=nx,ny=ny,nz=nz,heading=heading,scale=scale}
    -- Consume before committing so no free tags can be created.
    if not p.Functions.RemoveItem(Config.SprayItem, 1) then return notify(src, 'Spray can unavailable.', 'error') end
    local ok, id = pcall(function()
        return MySQL.insert.await('INSERT INTO agc_graffiti (citizenid,author_name,kind,content,color,x,y,z,nx,ny,nz,heading,scale) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
            {row.citizenid,row.author_name,row.kind,row.content,row.color,x,y,z,nx,ny,nz,heading,scale})
    end)
    if not ok or not id then
        p.Functions.AddItem(Config.SprayItem, 1)
        return notify(src, 'Unable to save graffiti.', 'error')
    end
    row.id = id
    tags[id] = row
    TriggerClientEvent('agc-graffiti:client:add', -1, row)
    notify(src, 'Graffiti sprayed!', 'success')
    local now = os.time()
    if math.random(100) <= Config.DispatchChance and now-(dispatchAt[src] or 0) >= Config.DispatchCooldown then
        dispatchAt[src] = now
        for _, pid in ipairs(QBCore.Functions.GetPlayers()) do
            local officer = QBCore.Functions.GetPlayer(pid)
            if officer and Config.DispatchJobs[officer.PlayerData.job.name] and officer.PlayerData.job.onduty then
                TriggerClientEvent('agc-graffiti:client:dispatch', pid, {x=x,y=y,z=z})
            end
        end
    end
end)
RegisterNetEvent('agc-graffiti:server:remove', function(id)
    local src = source
    local p = QBCore.Functions.GetPlayer(src)
    id = tonumber(id)
    local tag = id and tags[id]
    if not p or not tag then return end
    local pos = GetEntityCoords(GetPlayerPed(src))
    if #(pos - vector3(tag.x,tag.y,tag.z)) > Config.MaxDistance + 1.5 then return end
    if not playerHasItem(src, Config.CleanItem) then return notify(src, 'You need graffiti remover.', 'error') end
    local changed = MySQL.update.await('DELETE FROM agc_graffiti WHERE id = ?', {id})
    if not changed or changed < 1 then return end
    p.Functions.RemoveItem(Config.CleanItem, 1)
    tags[id] = nil
    TriggerClientEvent('agc-graffiti:client:remove', -1, id)
    notify(src, 'Graffiti removed.', 'success')
end)
QBCore.Commands.Add(Config.AdminDeleteCommand, 'Delete nearest graffiti (admin)', {}, false, function(src)
    local pos = GetEntityCoords(GetPlayerPed(src))
    local nearest, dist = nil, Config.MaxDistance
    for id, tag in pairs(tags) do
        local d = #(pos - vector3(tag.x,tag.y,tag.z))
        if d < dist then nearest, dist = id, d end
    end
    if not nearest then return notify(src, 'No nearby graffiti.', 'error') end
    MySQL.update.await('DELETE FROM agc_graffiti WHERE id = ?', {nearest})
    tags[nearest] = nil
    TriggerClientEvent('agc-graffiti:client:remove', -1, nearest)
    notify(src, 'Tag deleted.', 'success')
end, Config.AdminPermission)
AddEventHandler('playerDropped', function() dispatchAt[source] = nil end)
