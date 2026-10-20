
Bridge = {}
local function started(n) return GetResourceState(n)=='started' end
local function choose(setting, variants)
    if setting and setting~='auto' then return setting end
    for _, v in ipairs(variants) do if started(v[2]) then return v[1] end end
    return nil
end
Bridge.framework=choose(Config.Framework,{{'qbox','qbx_core'},{'qb','qb-core'},{'esx','es_extended'}})
Bridge.inventory=choose(Config.Inventory,{{'ox','ox_inventory'},{'qb','qb-inventory'},{'esx','es_extended'}})
Bridge.target=choose(Config.Target,{{'ox','ox_target'},{'qb','qb-target'}})
local QB,ESX
if Bridge.framework=='qb' then QB=exports['qb-core']:GetCoreObject() end
if Bridge.framework=='esx' then ESX=exports['es_extended']:getSharedObject() end
if not Bridge.framework then error('[agc-graffiti] No supported framework found') end
if not Bridge.inventory then Bridge.inventory=Bridge.framework=='esx' and 'esx' or 'qb' end
function Bridge.player(src)
    if Bridge.framework=='qb' then return QB.Functions.GetPlayer(src) end
    if Bridge.framework=='qbox' then return exports.qbx_core:GetPlayer(src) end
    return ESX.GetPlayerFromId(src)
end
function Bridge.identity(src)
    local p=Bridge.player(src)
    if not p then return nil end
    if Bridge.framework=='esx' then return p.identifier, p.getName() or GetPlayerName(src) end
    local d=p.PlayerData
    local c=d.charinfo or {}
    return d.citizenid, ((c.firstname or '')..' '..(c.lastname or '')):gsub('^%s+',''):gsub('%s+$','')
end
function Bridge.job(src)
    local p=Bridge.player(src)
    if not p then return nil,false end
    if Bridge.framework=='esx' then
        local job=p.getJob()
        return job and job.name, job and (job.onduty==nil or job.onduty)
    end
    local job=p.PlayerData.job
    return job and job.name, job and (job.onduty~=false)
end
function Bridge.players()
    if Bridge.framework=='qb' then return QB.Functions.GetPlayers() end
    local t={}
    for _, id in ipairs(GetPlayers()) do t[#t+1]=tonumber(id) end
    return t
end
function Bridge.notify(src,msg,typ)
    TriggerClientEvent('agc-graffiti:client:notify',src,msg,typ)
end
function Bridge.count(src,item)
    if Bridge.inventory=='ox' then return exports.ox_inventory:GetItemCount(src,item) or 0 end
    local p=Bridge.player(src)
    if not p then return 0 end
    if Bridge.inventory=='esx' then
        local i=p.getInventoryItem(item)
        return i and (i.count or 0) or 0
    end
    if Bridge.framework=='qb' then
        local i=p.Functions.GetItemByName(item)
        return i and (i.amount or 0) or 0
    end
    local i=exports['qb-inventory']:GetItemByName(src,item)
    return i and (i.amount or 0) or 0
end
function Bridge.remove(src,item,count)
    if Bridge.inventory=='ox' then return exports.ox_inventory:RemoveItem(src,item,count) end
    local p=Bridge.player(src)
    if not p then return false end
    if Bridge.inventory=='esx' then
        if Bridge.count(src,item)<count then return false end
        p.removeInventoryItem(item,count)
        return true
    end
    if Bridge.framework=='qb' then return p.Functions.RemoveItem(item,count) end
    return exports['qb-inventory']:RemoveItem(src,item,count)
end
function Bridge.add(src,item,count)
    if Bridge.inventory=='ox' then return exports.ox_inventory:AddItem(src,item,count) end
    local p=Bridge.player(src)
    if not p then return false end
    if Bridge.inventory=='esx' then p.addInventoryItem(item,count); return true end
    if Bridge.framework=='qb' then return p.Functions.AddItem(item,count) end
    return exports['qb-inventory']:AddItem(src,item,count)
end
function Bridge.registerItem(item,event)
    if Bridge.inventory=='ox' then
        -- ox_inventory item use is configured via client.export in its items definitions.
        return
    end
    if Bridge.framework=='qb' then
        QB.Functions.CreateUseableItem(item,function(src) TriggerClientEvent(event,src) end)
    elseif Bridge.framework=='qbox' then
        exports.qbx_core:CreateUseableItem(item,function(src) TriggerClientEvent(event,src) end)
    else
        ESX.RegisterUsableItem(item,function(src) TriggerClientEvent(event,src) end)
    end
end
function Bridge.isAdmin(src)
    if src==0 then return true end
    if IsPlayerAceAllowed(src,'agcgraffiti.admin') or IsPlayerAceAllowed(src,'command.'..Config.AdminDeleteCommand) then return true end
    if Bridge.framework=='qb' then return QB.Functions.HasPermission(src,Config.AdminPermission) end
    if Bridge.framework=='qbox' then return exports.qbx_core:HasPermission(src,Config.AdminPermission) end
    local p=Bridge.player(src)
    return p and (p.getGroup()=='admin' or p.getGroup()=='superadmin') or false
end
print(('[agc-graffiti] framework=%s inventory=%s target=%s'):format(Bridge.framework,Bridge.inventory,Bridge.target or 'none'))
