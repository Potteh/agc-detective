local evidence, opened, lastShot, lastHealth = {}, false, 0, nil
local function notify(msg)
 BeginTextCommandThefeedPost('STRING'); AddTextComponentSubstringPlayerName(msg); EndTextCommandThefeedPostTicker(false,false)
end
RegisterNetEvent('agc-detective:notify',notify)
RegisterNetEvent('agc-detective:sync',function(rows) evidence=rows or {} end)
RegisterNetEvent('agc-detective:openDashboard',function(cases,items,analyses,atLab)
 opened=true; SetNuiFocus(true,true)
 SendNUIMessage({action='open',cases=cases,evidence=items,analyses=analyses,atLab=atLab})
end)
RegisterNetEvent('agc-detective:custodyResult',function(id,rows)
 SendNUIMessage({action='custody',id=id,rows=rows})
end)
RegisterNUICallback('close',function(_,cb) opened=false; SetNuiFocus(false,false); cb({ok=true}) end)
RegisterNUICallback('createCase',function(d,cb) TriggerServerEvent('agc-detective:createCase',d.title); cb({ok=true}) end)
RegisterNUICallback('assign',function(d,cb) TriggerServerEvent('agc-detective:assignEvidence',d.eid,d.cid); cb({ok=true}) end)
RegisterNUICallback('analyze',function(d,cb) TriggerServerEvent('agc-detective:analyze',d.id); cb({ok=true}) end)
RegisterNUICallback('custody',function(d,cb) TriggerServerEvent('agc-detective:custody',d.id); cb({ok=true}) end)
RegisterNUICallback('refresh',function(_,cb) TriggerServerEvent('agc-detective:dashboard'); cb({ok=true}) end)
CreateThread(function()
 Wait(2500); TriggerServerEvent('agc-detective:requestSync')
 while true do
  local waitMs=800; local ped=PlayerPedId()
  if ped~=0 then
   local now=GetGameTimer()
   if IsPedShooting(ped) and now-lastShot>Config.CasingCooldownMs then
    lastShot=now; TriggerServerEvent('agc-detective:shot',GetSelectedPedWeapon(ped))
   end
   local hp=GetEntityHealth(ped)
   if lastHealth and hp<lastHealth and hp>0 then TriggerServerEvent('agc-detective:injured') end
   lastHealth=hp
   local pos=GetEntityCoords(ped); local nearest,dist=nil,Config.CollectionDistance
   for _,e in ipairs(evidence) do
    local d=#(pos-vector3(e.x,e.y,e.z))
    if d<Config.SceneRenderDistance then
     waitMs=0
     DrawMarker(2,e.x,e.y,e.z+0.16,0,0,0,0,0,0,0.15,0.15,0.15,55,201,209,180,false,true,2,false,nil,nil,false)
     if d<dist then nearest=e; dist=d end
    end
   end
   if nearest and not opened then
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(('Press ~INPUT_CONTEXT~ to bag evidence #%s (%s)'):format(nearest.id,nearest.kind))
    EndTextCommandDisplayHelp(0,false,true,-1)
    if IsControlJustReleased(0,38) then TriggerServerEvent('agc-detective:collect',nearest.id); Wait(450) end
   end
  end
  Wait(waitMs)
 end
end)
