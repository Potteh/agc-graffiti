# AGC Graffiti v1.0.0 (QBCore)

## Installation
1. Extract the `agc-graffiti` directory into `resources/[agc]/agc-graffiti`.
2. Install/ensure `qb-core`, `qb-target`, `qb-inventory`, and `oxmysql` first. A compatible QBCore progressbar implementation is required.
3. In `qb-core/shared/items.lua` add the item definitions below. Add corresponding images to qb-inventory/html/images or use existing placeholders.
4. Database table is created automatically at resource startup; `sql/install.sql` is included for manual setup.
5. Add `ensure agc-graffiti` after its dependencies in server.cfg and restart the server.
6. Adjust `config.lua` for dispatch jobs, image host allowlist, artwork and limits.

```lua
['spraycan'] = {name='spraycan',label='Spray Can',weight=300,type='item',image='spraycan.png',unique=false,useable=true,shouldClose=true,description='Paint a wall tag'},
['graffiti_remover'] = {name='graffiti_remover',label='Graffiti Remover',weight=300,type='item',image='graffiti_remover.png',unique=false,useable=true,shouldClose=true,description='Clean graffiti'},
```

## Usage
- Use a `spraycan` item, or `/graffiti` while carrying a spray can. Look at a wall within 3 meters.
- Select text or image artwork, size and color; click Spray. The can is consumed after successful placement.
- Use `graffiti_remover` to toggle cleaning mode, then use qb-target on a tag. One remover is consumed for each successful cleanup.
- `/graffitidelete` deletes the nearest tag for QBCore admins.
- On spray completion, on-duty police/sheriff may receive a 60-second incident blip based on `DispatchChance`.
- Territory mechanics intentionally excluded.

## Important technical limitations
- Graffiti is rendered as a camera-facing DUI sprite positioned at a wall, **not** a true wall-projected decal. It can appear billboard-like at oblique angles. For real wall-conforming decals a custom renderer is required.
- Each visible tag creates a DUI texture; keep MaxGraffiti and RenderDistance conservative to avoid client performance issues.
- External HTTPS images can fail due to CSP, hotlink protection, or NUI restrictions. For production, configure `AllowedImageHosts` with trusted domains and moderate images. The server validates image URLs but does not proxy or scan them.
- The client raycast and animation are not independently verified server-side; the server enforces proximity, inventory, format, and quotas, but malicious clients may submit spoofed wall coordinates. For a public economy server, add server-authoritative placement checks/rate limiting and image moderation.
- This is a complete starter resource but has not been live-tested against your particular qb-core, qb-target, qb-inventory, and FiveM build.

## v1.1 Text graffiti update
Text tags now have angled outlined lettering, spray speckles and drips. Image graffiti is unchanged. Replace the resource and restart it; existing text tags also use the new appearance. Uses stylized system fonts, not a bundled graffiti typeface.

## v1.2 — graffiti lettering styles
Choose Wildstyle, Bubble Letters, Throw-Up or Tagging in the text graffiti editor. The editor includes a preview; the selected style is saved with the tag and restored after restarts. Existing graffiti defaults to Wildstyle. Database migration adds `font_style` automatically on resource start. No manual SQL import is required. These are stylized system-font treatments, not bespoke graffiti font files; exact appearance can vary with CEF font availability.

## v1.3 — QBCore, Qbox and ESX compatibility

Framework selection is automatic (`Config.Framework`); supported values `qb`, `qbox`, `esx`.
Inventory selection is automatic (`Config.Inventory`); supported values `qb`, `ox`, `esx`.
Target selection is automatic (`Config.Target`); supported values `qb`, `ox`.

**Recommended combinations**
- QBCore: qb-core + qb-inventory + qb-target + progressbar.
- Qbox: qbx_core + ox_inventory + ox_target + ox_lib.
- ESX Legacy: es_extended + ox_inventory + ox_target + ox_lib, OR native ESX inventory with ox_target.
- oxmysql is required for all frameworks. Start dependencies before agc-graffiti.
- On Qbox with qb-inventory, inventory compatibility varies by fork; ox_inventory is recommended.

**ox_inventory item definitions** (`ox_inventory/data/items.lua`):
```lua
['spraycan'] = {label='Spray Can',weight=300,stack=true,close=true,consume=0,
    client={export='agc-graffiti.useSpray'}},
['graffiti_remover'] = {label='Graffiti Remover',weight=300,stack=true,close=true,consume=0,
    client={export='agc-graffiti.useRemover'}},
```
Keep `consume=0` because the graffiti server removes an item **only after a successful placement/cleanup**. The `client.export` entries are required for ox_inventory item use.

**Native ESX inventory**: add `spraycan` and `graffiti_remover` to your ESX items table (format depends on ESX version); usable items register automatically.

**qb-inventory**: use the QBCore item definitions above. On Qbox prefer ox_inventory.

**Admin permission**: grant `add_ace group.admin agcgraffiti.admin allow` or use framework-specific admin permission. `/graffitidelete` requires authorization. `Config.AdminPermission` defaults to `admin`.

**Progress UI**: uses ox_lib if running, otherwise `progressbar` if running, otherwise a minimal timed animation fallback (Backspace to cancel). The fallback has no visual progress bar.

**Commands**: `/graffiti` opens the editor (requires a spraycan at server placement); `/graffiticlean` toggles cleaning mode (requires remover at server cleanup). Using items also opens/toggles these modes.

**Upgrade**: Replace the entire folder; no schema changes are required from v1.2. Existing tags and font styles are preserved. No live Qbox/ESX compatibility testing has been performed.
