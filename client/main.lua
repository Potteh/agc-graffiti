local QBCore = exports['qb-core']:GetCoreObject()
local tags, duiCache = {}, {}
local uiOpen, busy, cleanMode = false, false, false
local function notify(msg, typ) QBCore.Functions.Notify(msg, typ or 'primary') end
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
    hit.kind=data.kind; hit.content=data.content; hit.color=data.color; hit.scale=tonumber(data.scale) or Config.DefaultScale
    cb({ok=true})
    QBCore.Functions.Progressbar('agc_graffiti_spray','Spraying graffiti...',Config.SprayDuration,false,true,
        {disableMovement=true,disableCarMovement=true,disableCombat=true},
        {animDict='switch@franklin@lamar_tagging_wall',anim='lamar_tagging_wall_loop_lamar',flags=49}, {}, {}, function()
            ClearPedTasks(PlayerPedId())
            busy=false
            TriggerServerEvent('agc-graffiti:server:place',hit)
        end, function()
            ClearPedTasks(PlayerPedId()); busy=false; notify('Spraying cancelled.', 'error')
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
    for id, name in pairs(zones) do exports['qb-target']:RemoveZone(name) end
    zones={}
end
local function addZone(tag)
    local name='agc_graffiti_'..tag.id
    zones[tag.id]=name
    exports['qb-target']:AddCircleZone(name,vector3(tag.x,tag.y,tag.z),0.85,{name=name,useZ=true,debugPoly=false},
        {options={{icon='fas fa-soap',label='Remove Graffiti',action=function()
            if busy then return end
            busy=true
            QBCore.Functions.Progressbar('agc_graffiti_clean','Cleaning graffiti...',Config.CleanDuration,false,true,
                {disableMovement=true,disableCarMovement=true,disableCombat=true},
                {animDict='amb@world_human_maid_clean@base',anim='base',flags=49},{},{},function()
                    busy=false; ClearPedTasks(PlayerPedId())
                    TriggerServerEvent('agc-graffiti:server:remove',tag.id)
                end,function() busy=false; ClearPedTasks(PlayerPedId()) end)
        end,canInteract=function() return cleanMode and not busy end}},distance=Config.MaxDistance})
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
    if zones[id] then exports['qb-target']:RemoveZone(zones[id]); zones[id]=nil end
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
    local payload=json.encode({kind=tag.kind,content=tag.content,color=tag.color})
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
AddEventHandler('onResourceStop',function(res)
    if res~=GetCurrentResourceName() then return end
    clearZones()
    for id in pairs(duiCache) do destroyDui(id) end
    SetNuiFocus(false,false)
end)
