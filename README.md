# AGC Detective v0.2.0 — DEVELOPMENT BUILD

## Install
1. Put `agc-detective` in resources.
2. Start `oxmysql` and QBCore (`qb-core`), Qbox (`qbx_core`), or ESX Legacy (`es_extended`) before this resource.
3. `ensure agc-detective` in server.cfg.
4. SQL tables are created automatically on startup with `CREATE TABLE IF NOT EXISTS` via oxmysql. No manual import required. Database user needs CREATE TABLE permission. Existing v0.1 data is retained.
5. Configure `Config.Labs` for your actual MLO.
6. Register the `agc_evidence_bag` inventory item in your chosen inventory. Otherwise digital bags remain functional when `RequirePhysicalBag=false`.

### qb-inventory item example (qb-core/shared/items.lua)
```lua
agc_evidence_bag = { name='agc_evidence_bag', label='Sealed Evidence Bag', weight=100, type='item', image='evidence.png', unique=true, useable=false, shouldClose=true, description='Forensic evidence; authoritative record in detective database' },
```
### ox_inventory item example (ox_inventory/data/items.lua)
```lua
['agc_evidence_bag'] = {label='Sealed Evidence Bag',weight=100,stack=false,close=true},
```
For ESX, use ox_inventory for physical evidence bags; without it, digital bags work.

## Commands
`/detective` police dashboard; `/forensicprint` and `/forensicdna` ACE-restricted development test evidence. Example: `add_ace group.admin agc.detective.admin allow`.

## Integration exports (server-side)
```lua
exports['agc-detective']:CreateEvidence('tire', vector3(x,y,z), 'Tire tread', {tire_signature='vehicle:plate123'})
exports['agc-detective']:CreateFingerprint(vector3(x,y,z), citizenIdentifier, 'Door handle print')
exports['agc-detective']:CreateDNASample(vector3(x,y,z), citizenIdentifier, 'Swab sample')
```
Only trusted server resources should call these exports. Fingerprint/DNA signatures are deterministic game identifiers, **not** actual biometric measurements. Ballistics v0.2 compares weapon model hash, not unique firearm serial numbers. No automatic fingerprint collection from arbitrary GTA props is claimed; instrument interactions via exports.

## Limitations / known issues
- Evidence is stored digitally even when physical inventory is unavailable. If physical AddItem succeeds but the concurrent database claim fails, a duplicate inventory item may remain; treat DB as source of truth and clean up such items manually. For production, implement a transaction/reservation workflow with compensation.
- Health-delta-based blood detection is best-effort and may miss rapid consecutive damage; server health validation mitigates forged events but does not guarantee an injury was observed.
- Inventory items are **not** a substitute for authoritative database custody; item transfer/drop does not update custody in v0.2.
- No actual camera/video capture, biometric matching, unique gun serial comparison, or procedural cold-case generator.
- NUI loads optional Google Fonts; falls back to Arial without internet.
- Framework compatibility is implemented but **not live-tested** on QBCore, Qbox, or ESX Legacy deployments.
- Database permissions must allow table creation. Tables are created on each startup if absent.
