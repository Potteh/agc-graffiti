local function started(n) return GetResourceState(n)=='started' end
local target=Config.Target
if target=='auto' then target=started('ox_target') and 'ox' or 'qb' end
local function notify(msg,typ)
    if started('ox_lib') then lib.notify({description=msg,type=typ=='primary' and 'inform' or typ}); return end
    if started('qb-core') then exports['qb-core']:GetCoreObject().Functions.Notify(msg,typ or 'primary'); return end
    if started('es_extended') then exports['es_extended']:getSharedObject().ShowNotification(msg); return end
    BeginTextCommandThefeedPost('STRING'); AddTextComponentSubstringPlayerName(msg); EndTextCommandThefeedPostTicker(false,false)
end
local function progress(label,duration,dict,anim,done,cancel)
    if started('ox_lib') then
        local ok=lib.progressBar({duration=duration,label=label,canCancel=true,disable={move=true,car=true,combat=true},
            anim={dict=dict,clip=anim,flag=49}})
        ClearPedTasks(PlayerPedId())
        if ok then done() else cancel() end
        return
    end
    if started('progressbar') then
        exports['progressbar']:Progress({name='agc_graffiti',duration=duration,label=label,useWhileDead=false,
            canCancel=true,controlDisables={disableMovement=true,disableCarMovement=true,disableCombat=true},
            animation={animDict=dict,anim=anim,flags=49}},function(cancelled)
                ClearPedTasks(PlayerPedId())
                if cancelled then cancel() else done() end
            end)
        return
    end
    -- Minimal standalone fallback with cancellable progress and animation.
    CreateThread(function()
        RequestAnimDict(dict)
        local deadline=GetGameTimer()+3000
        while not HasAnimDictLoaded(dict) and GetGameTimer()<deadline do Wait(0) end
        if HasAnimDictLoaded(dict) then TaskPlayAnim(PlayerPedId(),dict,anim,4.0,4.0,duration,49,0,false,false,false) end
        local untilTime=GetGameTimer()+duration
        while GetGameTimer()<untilTime do
            Wait(0)
            DisableControlAction(0,24,true); DisableControlAction(0,30,true); DisableControlAction(0,31,true)
            if IsControlJustPressed(0,177) then ClearPedTasks(PlayerPedId()); cancel(); return end
        end
        ClearPedTasks(PlayerPedId()); done()
    end)
end
local tags, duiCache = {}, {}
local uiOpen, busy, cleanMode = false, false, false
RegisterNetEvent('agc-graffiti:client:notify',notify)
local function rotToDir(rot)
    local z, x = math.rad(rot.z), math.rad(rot.x)
    return vector3(-math.sin(z)*math.abs(math.cos(x)), math.cos(z)*math.abs(math.cos(x)), math.sin(x))
end
local function wallHit()
    local cam = GetGameplayCamCoord()
    local dir = rotToDir(GetGameplayCamRot(2))
    local dst = cam + dir * 5.0
    local ray = StartShapeTestRay(cam.x,cam.y,cam.z,dst.x,dst.y,dst.z,17,PlayerPedId(),7)
    local _,hit,pos,normal = GetShapeTestResult(ray)
    if hit ~= 1 or math.abs(normal.z) > 0.5 or #(GetEntityCoords(PlayerPedId())-pos) > Config.MaxDistance then return nil end
    return {x=pos.x,y=pos.y,z=pos.z,nx=normal.x,ny=normal.y,nz=normal.z,heading=GetEntityHeading(PlayerPedId()),scale=Config.DefaultScale}
end
local function start()
    if uiOpen or busy then return end
    local hit = wallHit()
    if not hit then return notify('Look at a nearby vertical wall (within 3m).', 'error') end
    uiOpen = true
    SetNuiFocus(true,true)
    SendNUIMessage({action='open', position=hit, artwork=Config.AllowedArtwork, minScale=Config.MinScale, maxScale=Config.MaxScale})
end
RegisterNetEvent('agc-graffiti:client:start', start)
RegisterCommand(Config.PlaceCommand, start, false)
RegisterNUICallback('close', function(_, cb)
    uiOpen=false; SetNuiFocus(false,false); cb({ok=true})
end)
RegisterNUICallback('place', function(data,cb)
    if not uiOpen or busy then cb({ok=false}); return end
    local hit = wallHit()
    if not hit then notify('Aim at the wall again.', 'error'); cb({ok=false}); return end
    uiOpen=false; SetNuiFocus(false,false); busy=true
    hit.kind=data.kind; hit.content=data.content; hit.color=data.color; hit.font_style=data.fontStyle; hit.scale=tonumber(data.scale) or Config.DefaultScale
    cb({ok=true})
    progress('Spraying graffiti...',Config.SprayDuration,'switch@franklin@lamar_tagging_wall','lamar_tagging_wall_loop_lamar',function()
        busy=false
        TriggerServerEvent('agc-graffiti:server:place',hit)
    end,function()
        busy=false; notify('Spraying cancelled.','error')
    end)
end)
RegisterNetEvent('agc-graffiti:client:cleanMode', function()
    cleanMode = not cleanMode
    notify(cleanMode and 'Cleaning mode on: use target on a tag.' or 'Cleaning mode off.')
end)
local function nearestTag()
    local pos = GetEntityCoords(PlayerPedId())
    local best, distance
    for id, tag in pairs(tags) do
        local d = #(pos-vector3(tag.x,tag.y,tag.z))
        if d <= Config.MaxDistance and (not distance or d < distance) then best, distance = id, d end
    end
    return best
end
-- A small invisible interaction sphere per tag, recreated on synchronization.
local zones = {}
local function clearZones()
    for id,name in pairs(zones) do
        if target=='ox' then exports.ox_target:removeSphereZone(name)
        else exports['qb-target']:RemoveZone(name) end
    end
    zones={}
end
local function addZone(tag)
    local name='agc_graffiti_'..tag.id
    local function clean()
        if busy then return end
        busy=true
        progress('Cleaning graffiti...',Config.CleanDuration,'amb@world_human_maid_clean@base','base',function()
            busy=false
            TriggerServerEvent('agc-graffiti:server:remove',tag.id)
        end,function() busy=false end)
    end
    if target=='ox' then
        zones[tag.id]=exports.ox_target:addSphereZone({
            coords=vec3(tag.x,tag.y,tag.z),radius=0.85,debug=false,
            options={{name=name,icon='fas fa-soap',label='Remove Graffiti',distance=Config.MaxDistance,
                canInteract=function() return cleanMode and not busy end,onSelect=clean}}
        })
    else
        zones[tag.id]=name
        exports['qb-target']:AddCircleZone(name,vector3(tag.x,tag.y,tag.z),0.85,
            {name=name,useZ=true,debugPoly=false},
            {options={{icon='fas fa-soap',label='Remove Graffiti',action=clean,
                canInteract=function() return cleanMode and not busy end}},distance=Config.MaxDistance})
    end
end
local function removeZone(id)
    if not zones[id] then return end
    if target=='ox' then exports.ox_target:removeSphereZone(zones[id])
    else exports['qb-target']:RemoveZone(zones[id]) end
    zones[id]=nil
end
local function destroyDui(id)
    local c=duiCache[id]
    if c then DestroyDui(c.dui); duiCache[id]=nil end
end
RegisterNetEvent('agc-graffiti:client:sync',function(all)
    clearZones()
    for id in pairs(duiCache) do destroyDui(id) end
    tags=all or {}
    for _, tag in pairs(tags) do addZone(tag) end
end)
RegisterNetEvent('agc-graffiti:client:add',function(tag) tags[tag.id]=tag; addZone(tag) end)
RegisterNetEvent('agc-graffiti:client:remove',function(id)
    tags[id]=nil; destroyDui(id)
    removeZone(id)
end)
RegisterNetEvent('agc-graffiti:client:dispatch',function(pos)
    notify('Dispatch: possible graffiti vandalism reported.', 'error')
    local blip=AddBlipForCoord(pos.x,pos.y,pos.z)
    SetBlipSprite(blip,161); SetBlipColour(blip,1); SetBlipScale(blip,1.0)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentString('Graffiti report'); EndTextCommandSetBlipName(blip)
    SetTimeout(60000,function() RemoveBlip(blip) end)
end)
-- DUI draws custom artwork to a runtime texture. Native DrawSprite uses a wall-aligned
-- 3D transform via SetDrawOrigin, with normal-derived rotation. Works best on vertical walls.
local function escapeHtml(s)
    return tostring(s or ''):gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;'):gsub('"','&quot;'):gsub("'",'&#39;')
end
local function ensureDui(tag)
    if duiCache[tag.id] then return duiCache[tag.id] end
    local dict='agcg_'..tag.id
    local tex='tag'
    local html
    if tag.kind=='text' then
        html='<div style="color:'..tag.color..';font:900 82px Impact,Arial,sans-serif;text-shadow:3px 4px #111;overflow:hidden;overflow-wrap:anywhere;text-align:center">'..escapeHtml(tag.content)..'</div>'
    else
        html='<img src="'..escapeHtml(tag.content)..'" style="width:100%;height:100%;object-fit:contain" />'
    end
    local url='https://cfx-nui-agc-graffiti/html/texture.html?content='..''
    -- The texture page receives tag data through encoded fragment (no raw HTML injection).
    local payload=json.encode({kind=tag.kind,content=tag.content,color=tag.color,fontStyle=tag.font_style or "wildstyle"})
    local encoded=''
    for i=1,#payload do encoded=encoded..('%02X'):format(payload:byte(i)) end
    local dui=CreateDui('https://cfx-nui-agc-graffiti/html/texture.html#'..encoded,512,256)
    local txd=CreateRuntimeTxd(dict)
    CreateRuntimeTextureFromDuiHandle(txd,tex,GetDuiHandle(dui))
    duiCache[tag.id]={dui=dui,dict=dict,tex=tex}
    return duiCache[tag.id]
end
CreateThread(function()
    while true do
        local ped=PlayerPedId()
        local p=GetEntityCoords(ped)
        local close=false
        for id,tag in pairs(tags) do
            local d=#(p-vector3(tag.x,tag.y,tag.z))
            if d < Config.RenderDistance then
                close=true
                local c=ensureDui(tag)
                -- SetDrawOrigin sprites face the camera; this is a lightweight billboard
                -- positioned flush to the wall, not a fully projected wall decal.
                SetDrawOrigin(tag.x+tag.nx*0.025,tag.y+tag.ny*0.025,tag.z,0)
                DrawSprite(c.dict,c.tex,0,0,Config.DrawWidth*tag.scale/(d*0.10+1),Config.DrawHeight*tag.scale/(d*0.10+1),0,255,255,255,255)
                ClearDrawOrigin()
            elseif duiCache[id] then destroyDui(id) end
        end
        Wait(close and 0 or 750)
    end
end)
CreateThread(function()
    Wait(2500)
    TriggerServerEvent('agc-graffiti:server:requestSync')
end)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded',function()
    TriggerServerEvent('agc-graffiti:server:requestSync')
end)
RegisterNetEvent('esx:playerLoaded',function() TriggerServerEvent('agc-graffiti:server:requestSync') end)
RegisterNetEvent('QBX:Client:OnPlayerLoaded',function() TriggerServerEvent('agc-graffiti:server:requestSync') end)
RegisterCommand('graffiticlean',function() TriggerEvent('agc-graffiti:client:cleanMode') end,false)
AddEventHandler('onResourceStop',function(res)
    if res~=GetCurrentResourceName() then return end
    clearZones()
    for id in pairs(duiCache) do destroyDui(id) end
    SetNuiFocus(false,false)
end)

-- ox_inventory client exports for usable item definitions.
exports('useSpray',function(data,slot)
    exports.ox_inventory:useItem(data,function(used)
        if used then TriggerEvent('agc-graffiti:client:start') end
    end)
end)
exports('useRemover',function(data,slot)
    exports.ox_inventory:useItem(data,function(used)
        if used then TriggerEvent('agc-graffiti:client:cleanMode') end
    end)
end)
