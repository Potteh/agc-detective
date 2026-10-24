# AGC Detective v0.2.2 — qb-inventory evidence bag fix

The previous v0.2.0 collection routine attempted to ADD a sealed bag but did not recognize or consume the empty bag already in inventory. This version checks item slots for an `agc_evidence_bag` without `info.evidence_id`, consumes exactly one, and creates a sealed bag with `info.evidence_id` metadata. It keeps the digital evidence database and cross-framework bridges.

**qb-inventory:** Set `unique=true` for `agc_evidence_bag` in `qb-core/shared/items.lua` to preserve individual bag metadata; restart the server after modifying item definitions. Existing unsealed bags have no `evidence_id` and count as empty.

**ox_inventory:** Empty bags have no `metadata.evidence_id`; sealed bags do. ESX Legacy can use ox_inventory or digital-only fallback. For digital-only collection set `Config.Inventory='virtual'` and `Config.RequirePhysicalBag=false`.

**Installation:** Replace your current `agc-detective` folder, preserve custom config edits, then `restart agc-detective`. SQL tables are auto-created via oxmysql; no manual SQL import or data reset. Use `/detective` to verify records.

**Testing:** Give yourself two empty bags; fire a weapon; collect one casing with E; confirm one empty bag consumed, one sealed bag received with evidence ID, and matching record in the dashboard. Repeat with a second casing. A sealed bag must not be accepted as an empty bag.

**Caution:** Inventory and database writes are not one atomic transaction. The resource attempts compensation when an inventory call fails, but crashes between operations or exceptional database failures may require administrator reconciliation. Inventory transfer/drop does not update custody records. Live testing on QBCore, Qbox and ESX is still required.

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


## v0.2.3 qb-inventory diagnostics
- More robust detection of empty evidence bags from current qb-inventory exports, cached slots, and QBCore player functions.
- Run `/detectivebagdebug` in-game as an authorized police officer to see selected inventory mode and detected slot. The server console also logs this.
- On QBCore, qb-inventory takes precedence when both inventory resources are started.
- Existing database tables and records are untouched.
- If the command still reports no empty slot, share the server console line, plus your qb-inventory version/fork.
