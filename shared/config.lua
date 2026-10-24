Config = {}
Config.Framework = 'auto' -- auto/qb/qbox/esx
Config.AllowedJobs = { police=true, sheriff=true, state=true }
Config.MinimumGrade = 0
Config.CollectionDistance = 3.0
Config.SceneRenderDistance = 30.0
Config.LabDistance = 3.5
Config.MaxSceneRows = 250
Config.EvidenceLifetimeHours = 168
Config.CasingCooldownMs = 1800
Config.ShotChance = 80
Config.BloodChance = 65
Config.Commands = { dashboard='detective', blood='forensicblood', print='forensicprint', dna='forensicdna' }
Config.Inventory = 'auto' -- auto/qb/ox/virtual; virtual uses a persistent digital bag when physical adapter unavailable
Config.ItemName = 'agc_evidence_bag' -- register in inventory; see README
Config.RequirePhysicalBag = false -- true: collection fails unless inventory accepts bag
Config.Labs = { vector3(452.03,-973.12,30.69) } -- configure to match your MLO
Config.AdminAce = 'agc.detective.admin'
