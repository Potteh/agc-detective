local Framework, ready = nil, false
local recentShots, recentInjury = {}, {}
local kinds = {casing=true,blood=true,dna=true,fingerprint=true,tire=true,other=true}
local function detect()
 if Config.Framework ~= 'auto' then return Config.Framework end
 if GetResourceState('qbx_core')=='started' then return 'qbox' end
 if GetResourceState('qb-core')=='started' then return 'qb' end
 if GetResourceState('es_extended')=='started' then return 'esx' end
end
local function info(src)
 if Framework=='qb' then
  local p=exports['qb-core']:GetCoreObject().Functions.GetPlayer(src); if not p then return end
  local d=p.PlayerData; local j=d.job or {}; local c=d.charinfo or {}
  return {id=d.citizenid,job=j.name,grade=tonumber((j.grade or {}).level or j.grade) or 0,name=(c.firstname or '')..' '..(c.lastname or '')}
 elseif Framework=='qbox' then
  local p=exports.qbx_core:GetPlayer(src); if not p then return end
  local d=p.PlayerData; local j=d.job or {}; local c=d.charinfo or {}
  return {id=d.citizenid,job=j.name,grade=tonumber((j.grade or {}).level or j.grade) or 0,name=(c.firstname or '')..' '..(c.lastname or '')}
 elseif Framework=='esx' then
  local p=exports.es_extended:getSharedObject().GetPlayerFromId(src); if not p then return end
  local j=p.getJob(); return {id=p.identifier,job=j.name,grade=tonumber(j.grade) or 0,name=p.getName()}
 end
end
local function permitted(src)
 local p=info(src)
 return ready and p and Config.AllowedJobs[p.job] and p.grade >= Config.MinimumGrade,p
end
local function notify(src,s) TriggerClientEvent('agc-detective:notify',src,s) end
local function coords(src)
 local ped=GetPlayerPed(src); if not ped or ped==0 then return end
 return GetEntityCoords(ped)
end
local function near(src,x,y,z,dist)
 local pos=coords(src); return pos and #(pos-vector3(x,y,z))<=dist
end
local function lab(src)
 local pos=coords(src); if not pos then return false end
 for _,v in ipairs(Config.Labs) do if #(pos-v)<=Config.LabDistance then return true end end
 return false
end
local function audit(eid,actor,action,details)
 MySQL.insert.await('INSERT INTO agc_detective_custody (evidence_id,actor,action,details) VALUES (?,?,?,?)',{eid,actor,action,tostring(details or ''):sub(1,255)})
end
local function migrate()
 local ddl={
 [[CREATE TABLE IF NOT EXISTS agc_detective_cases (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,title VARCHAR(120) NOT NULL,status VARCHAR(24) NOT NULL DEFAULT 'open',created_by VARCHAR(100) NOT NULL,created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
 [[CREATE TABLE IF NOT EXISTS agc_detective_evidence (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,kind VARCHAR(32) NOT NULL,x DOUBLE NOT NULL,y DOUBLE NOT NULL,z DOUBLE NOT NULL,description VARCHAR(255),metadata LONGTEXT,collected_by VARCHAR(100) NULL,collected_at TIMESTAMP NULL,case_id INT UNSIGNED NULL,created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,INDEX (collected_by),INDEX (case_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
 [[CREATE TABLE IF NOT EXISTS agc_detective_custody (id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,evidence_id INT UNSIGNED NOT NULL,actor VARCHAR(100) NOT NULL,action VARCHAR(40) NOT NULL,details VARCHAR(255),created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,INDEX(evidence_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
 [[CREATE TABLE IF NOT EXISTS agc_detective_bags (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,evidence_id INT UNSIGNED NOT NULL UNIQUE,owner VARCHAR(100) NOT NULL,inventory_mode VARCHAR(20) NOT NULL DEFAULT 'virtual',bag_status VARCHAR(20) NOT NULL DEFAULT 'held',created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,INDEX(owner)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
 [[CREATE TABLE IF NOT EXISTS agc_detective_analyses (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,evidence_id INT UNSIGNED NOT NULL,analyst VARCHAR(100) NOT NULL,analysis_type VARCHAR(32) NOT NULL,signature VARCHAR(100) NOT NULL,match_count INT NOT NULL DEFAULT 0,created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,INDEX(evidence_id),INDEX(signature)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]
 }
 for i,sql in ipairs(ddl) do MySQL.query.await(sql); print(('[agc-detective] Schema %d/%d ready'):format(i,#ddl)) end
end
local function scenes()
 return MySQL.query.await(('SELECT id,kind,x,y,z,description,created_at FROM agc_detective_evidence WHERE collected_by IS NULL ORDER BY id DESC LIMIT %d'):format(math.min(500,Config.MaxSceneRows))) or {}
end
local function sync() TriggerClientEvent('agc-detective:sync',-1,scenes()) end
local function addEvidence(kind,pos,desc,meta)
 if not ready or not kinds[kind] or not pos then return end
 local id=MySQL.insert.await('INSERT INTO agc_detective_evidence (kind,x,y,z,description,metadata) VALUES (?,?,?,?,?,?)',{kind,pos.x,pos.y,pos.z,tostring(desc or kind):sub(1,255),json.encode(meta or {})})
 sync(); return id
end
CreateThread(function()
 while not detect() do Wait(1000) end
 Framework=detect()
 local ok,err=pcall(migrate)
 if not ok then print('[agc-detective] FATAL: auto SQL migration failed: '..tostring(err)); return end
 ready=true; print('[agc-detective] v0.2 ready | '..Framework..' | SQL auto-installed')
end)
RegisterNetEvent('agc-detective:requestSync',function()
 local src=source; if not ready then return end
 TriggerClientEvent('agc-detective:sync',src,scenes())
end)
-- Client shooting is a hint, not authoritative proof. Server verifies current weapon and proximity.
RegisterNetEvent('agc-detective:shot',function(weapon)
 local src=source; if not ready or type(weapon)~='number' then return end
 local now=GetGameTimer(); if recentShots[src] and now-recentShots[src]<Config.CasingCooldownMs then return end
 local ped=GetPlayerPed(src); if ped==0 or GetSelectedPedWeapon(ped)~=weapon or weapon==`WEAPON_UNARMED` then return end
 recentShots[src]=now; if math.random(100)>Config.ShotChance then return end
 local pos=coords(src); if not pos then return end
 local p=info(src)
 addEvidence('casing',pos,'Spent cartridge casing',{weapon=weapon,ballistic_signature=('weapon:%s'):format(weapon),source=p and p.id or 'unknown'})
end)
-- Blood only originates from an actual server-observed health drop. Client signal cannot supply identity/coords.
RegisterNetEvent('agc-detective:injured',function()
 local src=source; if not ready then return end
 local ped=GetPlayerPed(src); if ped==0 then return end
 local hp=GetEntityHealth(ped); local prev=recentInjury[src]
 recentInjury[src]={hp=hp,time=GetGameTimer()}
 if not prev or hp>=prev.hp or GetGameTimer()-prev.time>12000 or hp<=0 or math.random(100)>Config.BloodChance then return end
 local p=info(src); local pos=coords(src)
 if pos then addEvidence('blood',pos,'Blood trace',{dna_signature=p and ('person:'..p.id) or 'unknown',source=p and p.id or 'unknown'}) end
end)
AddEventHandler('playerDropped',function() recentShots[source]=nil; recentInjury[source]=nil end)
-- Fingerprints/DNA samples from trusted server resources only; client cannot arbitrarily assign signatures.
exports('CreateEvidence',function(kind,pos,description,metadata)
 if not kinds[kind] or type(pos)~='vector3' then return nil end
 return addEvidence(kind,pos,description,metadata)
end)
exports('CreateFingerprint',function(pos,identifier,description)
 if type(pos)~='vector3' or type(identifier)~='string' then return end
 return addEvidence('fingerprint',pos,description or 'Latent fingerprint',{fingerprint_signature='person:'..identifier})
end)
exports('CreateDNASample',function(pos,identifier,description)
 if type(pos)~='vector3' or type(identifier)~='string' then return end
 return addEvidence('dna',pos,description or 'Biological sample',{dna_signature='person:'..identifier})
end)
local function inventoryMode()
 if Config.Inventory~='auto' then return Config.Inventory end
 if Framework=='qb' and GetResourceState('qb-inventory')=='started' then return 'qb' end
 if GetResourceState('ox_inventory')=='started' then return 'ox' end
 if GetResourceState('qb-inventory')=='started' then return 'qb' end
 return 'virtual'
end
-- v0.2.2: inventory bags are a consumable empty container. The collected item
-- retains the same item name, but its info/metadata contains evidence_id.
local collecting = {}
local function isEmptyBag(item)
 if type(item)~='table' or item.name~=Config.ItemName then return false end
 local meta=item.info or item.metadata
 if type(meta)=='string' then
  local ok,decoded=pcall(json.decode,meta)
  if ok then meta=decoded end
 end
 return type(meta)~='table' or meta.evidence_id==nil
end
local function findEmptyQB(src)
 local core=exports['qb-core']:GetCoreObject()
 local player=core.Functions.GetPlayer(src)
 if not player then return nil,'player not loaded' end
 local items=player.PlayerData.items or {}
 -- Use the current inventory export when available, not just cached PlayerData.
 local ok,current=pcall(function() return exports['qb-inventory']:GetInventory(src) end)
 if ok and type(current)=='table' then
  if type(current.items)=='table' then current=current.items end
  items=current
 end
 for key,item in pairs(items) do
  if isEmptyBag(item) and tonumber(item.amount or item.count or 1)>0 then
   local slot=tonumber(item.slot) or tonumber(key)
   if slot then return slot end
  end
 end
 -- Some qb-inventory versions expose the current item through GetItemByName.
 local got,item=pcall(function() return exports['qb-inventory']:GetItemByName(src,Config.ItemName) end)
 if got and isEmptyBag(item) then return tonumber(item.slot) end
 if type(player.Functions.GetItemByName)=='function' then
  local fallback=player.Functions.GetItemByName(Config.ItemName)
  if isEmptyBag(fallback) then return tonumber(fallback.slot) end
 end
 return nil,('item not located (inventory export=%s, cached slots=%s)'):format(tostring(ok),tostring(#items))
end
RegisterCommand('detectivebagdebug',function(src)
 if src==0 then print('[agc-detective] Run /detectivebagdebug in game') return end
 local authorized=permitted(src)
 if not authorized and not IsPlayerAceAllowed(src,Config.AdminAce) then return end
 local mode=inventoryMode()
 local slot,detail=findEmptyQB(src)
 local msg=('Inventory=%s | item=%s | empty slot=%s | detail=%s'):format(mode,Config.ItemName,tostring(slot),tostring(detail or 'none'))
 print(('[agc-detective] bag debug player %s: %s'):format(src,msg))
 notify(src,msg)
end,false)
local function takeEmptyBag(src,mode)
 if mode=='qb' then
  local slot,detail=findEmptyQB(src)
  if not slot then print(('[agc-detective] QB bag lookup failed for %s: %s'):format(src,tostring(detail))); return false,'Empty bag not detected; run /detectivebagdebug' end
  local ok,removed=pcall(function() return exports['qb-inventory']:RemoveItem(src,Config.ItemName,1,slot,'agc-detective:collect') end)
  return ok and removed==true, 'Could not remove the empty evidence bag'
 elseif mode=='ox' then
  local slots=exports.ox_inventory:Search(src,'slots',Config.ItemName) or {}
  for _,entry in pairs(slots) do
   if not (entry.metadata or {}).evidence_id then
    local ok,removed=pcall(function() return exports.ox_inventory:RemoveItem(src,Config.ItemName,1,nil,entry.slot) end)
    return ok and removed==true,'Could not remove the empty evidence bag'
   end
  end
  return false,'You need an empty evidence bag'
 end
 return not Config.RequirePhysicalBag,'Physical evidence inventory unavailable'
end
local function addBag(src,mode,metadata)
 if mode=='qb' then
  local ok,result=pcall(function() return exports['qb-inventory']:AddItem(src,Config.ItemName,1,false,metadata,'agc-detective:collect') end)
  return ok and result==true
 elseif mode=='ox' then
  local ok,result=pcall(function() return exports.ox_inventory:AddItem(src,Config.ItemName,1,metadata) end)
  return ok and result~=false and result~=nil
 end
 return true
end
local function restoreEmpty(src,mode)
 if mode~='virtual' and not addBag(src,mode,{}) then
  print(('[agc-detective] WARNING: failed to restore empty bag for player %s; manual reimbursement required'):format(src))
  notify(src,'Inventory error: ask staff to restore your empty bag')
 end
end
RegisterNetEvent('agc-detective:collect',function(id)
 local src=source; local ok,p=permitted(src); if not ok then return notify(src,'Police authorization required') end
 id=tonumber(id); if not id or id%1~=0 or id<1 then return end
 if collecting[id] then return notify(src,'Evidence is already being collected') end
 collecting[id]=true
 local success,err=pcall(function()
  local rows=MySQL.query.await('SELECT id,kind,x,y,z,collected_by FROM agc_detective_evidence WHERE id=? LIMIT 1',{id})
  local e=rows and rows[1]; if not e or e.collected_by then return notify(src,'Evidence already collected') end
  if not near(src,e.x,e.y,e.z,Config.CollectionDistance) then return notify(src,'Move closer to the evidence') end
  local mode=inventoryMode()
  local taken,reason=takeEmptyBag(src,mode)
  if not taken then return notify(src,reason) end
  local changed=MySQL.update.await('UPDATE agc_detective_evidence SET collected_by=?,collected_at=NOW() WHERE id=? AND collected_by IS NULL',{p.id,id})
  if changed~=1 then restoreEmpty(src,mode); return notify(src,'Evidence already collected') end
  local metadata={evidence_id=id,kind=e.kind,label=('Evidence #%d'):format(id),sealed=true}
  if not addBag(src,mode,metadata) then
   MySQL.update.await('UPDATE agc_detective_evidence SET collected_by=NULL,collected_at=NULL WHERE id=? AND collected_by=?',{id,p.id})
   restoreEmpty(src,mode)
   return notify(src,'Could not create sealed bag; collection canceled')
  end
  MySQL.insert.await('INSERT INTO agc_detective_bags (evidence_id,owner,inventory_mode) VALUES (?,?,?)',{id,p.id,mode})
  audit(id,p.id,'collected','Bag: '..mode)
  notify(src,('Collected evidence #%d (%s bag)'):format(id,mode)); sync()
 end)
 collecting[id]=nil
 if not success then print('[agc-detective] Collection error: '..tostring(err)); notify(src,'Evidence collection failed; check server console') end
end)
local function dashboard(src)
 local ok=permitted(src); if not ok then return notify(src,'Police authorization required') end
 local cases=MySQL.query.await('SELECT id,title,status,created_at FROM agc_detective_cases ORDER BY id DESC LIMIT 100') or {}
 local evidence=MySQL.query.await('SELECT e.id,e.kind,e.description,e.collected_by,e.case_id,e.created_at,b.inventory_mode,b.bag_status FROM agc_detective_evidence e LEFT JOIN agc_detective_bags b ON b.evidence_id=e.id ORDER BY e.id DESC LIMIT 200') or {}
 local analyses=MySQL.query.await('SELECT id,evidence_id,analysis_type,signature,match_count,created_at FROM agc_detective_analyses ORDER BY id DESC LIMIT 100') or {}
 TriggerClientEvent('agc-detective:openDashboard',src,cases,evidence,analyses,lab(src))
end
RegisterNetEvent('agc-detective:dashboard',function() dashboard(source) end)
RegisterCommand(Config.Commands.dashboard,function(src) if src>0 then dashboard(src) end end,false)
RegisterNetEvent('agc-detective:createCase',function(title)
 local src=source; local ok,p=permitted(src); if not ok or type(title)~='string' then return end
 title=title:gsub('[%c]',''):sub(1,120); if #title<3 then return end
 MySQL.insert.await('INSERT INTO agc_detective_cases (title,created_by) VALUES (?,?)',{title,p.id}); dashboard(src)
end)
RegisterNetEvent('agc-detective:assignEvidence',function(eid,cid)
 local src=source; local ok,p=permitted(src); if not ok then return end
 eid,cid=tonumber(eid),tonumber(cid)
 if not eid or not cid or eid%1~=0 or cid%1~=0 or eid<1 or cid<1 then return end
 if not MySQL.scalar.await('SELECT id FROM agc_detective_cases WHERE id=?',{cid}) then return end
 local changed=MySQL.update.await('UPDATE agc_detective_evidence SET case_id=? WHERE id=? AND collected_by IS NOT NULL',{cid,eid})
 if changed==1 then audit(eid,p.id,'assigned','Case #'..cid) end
 dashboard(src)
end)
RegisterNetEvent('agc-detective:analyze',function(id)
 local src=source; local ok,p=permitted(src); if not ok or not lab(src) then return notify(src,'Use a forensic laboratory station') end
 id=tonumber(id); if not id or id%1~=0 or id<1 then return end
 local rows=MySQL.query.await('SELECT id,kind,metadata,collected_by FROM agc_detective_evidence WHERE id=? LIMIT 1',{id})
 local e=rows and rows[1]; if not e or not e.collected_by then return notify(src,'Collect evidence before analysis') end
 local meta=json.decode(e.metadata or '{}') or {}
 local key=({casing='ballistic_signature',blood='dna_signature',dna='dna_signature',fingerprint='fingerprint_signature',tire='tire_signature'})[e.kind]
 if not key then return notify(src,'This evidence type has no matching assay') end
 local signature=meta[key]
 if type(signature)~='string' or #signature==0 then return notify(src,'No usable signature; inconclusive') end
 local count=0
 -- Match existing evidence only; not a real biometric or firearm registry.
 local all=MySQL.query.await('SELECT id,kind,metadata FROM agc_detective_evidence WHERE kind=? AND id<>? LIMIT 1000',{e.kind,id}) or {}
 for _,other in ipairs(all) do local m=json.decode(other.metadata or '{}') or {}; if m[key]==signature then count=count+1 end end
 MySQL.insert.await('INSERT INTO agc_detective_analyses (evidence_id,analyst,analysis_type,signature,match_count) VALUES (?,?,?,?,?)',{id,p.id,e.kind,signature,count})
 audit(id,p.id,'analyzed',('Type %s, comparisons %d'):format(e.kind,count)); notify(src,'Lab analysis complete'); dashboard(src)
end)
RegisterNetEvent('agc-detective:custody',function(id)
 local src=source; local ok=permitted(src); if not ok then return end
 id=tonumber(id); if not id or id%1~=0 or id<1 then return end
 local rows=MySQL.query.await('SELECT actor,action,details,created_at FROM agc_detective_custody WHERE evidence_id=? ORDER BY id DESC LIMIT 50',{id}) or {}
 TriggerClientEvent('agc-detective:custodyResult',src,id,rows)
end)
-- Test tools are ACE restricted and disabled for ordinary players.
RegisterCommand(Config.Commands.print,function(src,args)
 if src==0 or not IsPlayerAceAllowed(src,Config.AdminAce) then return end
 local pos=coords(src); local p=info(src); if pos and p then addEvidence('fingerprint',pos,'Test latent print',{fingerprint_signature='person:'..p.id}) end
end,false)
RegisterCommand(Config.Commands.dna,function(src,args)
 if src==0 or not IsPlayerAceAllowed(src,Config.AdminAce) then return end
 local pos=coords(src); local p=info(src); if pos and p then addEvidence('dna',pos,'Test DNA swab',{dna_signature='person:'..p.id}) end
end,false)
