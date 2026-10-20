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
