# ArmorForge API

## Features
- Slot-based equipment system (`helmet`, `chest`, `leggings`, `boots`, `shield`, `offhand`)
- Callback registration for **pre-equip/unequip** and **on-equip/unequip**
- Automatic persistence using `mod_storage` (save on leave, restore on join)
- Detached inventory integration with slot validation
- Stat aggregation (speed, gravity, jump, armor, knockback, block)
- Physics backend support (`pova`, `player_monoids`, or builtin fallback)
- **Built-in physics engine (`armorforge.physics`)** when no external backend is available  
  → Other mods using this API do not need to handle physics themselves — ArmorForge shares its physics system transparently
- Metadata preservation for equipped items
- HP reduction and knockback scaling based on stats
- Block chance support (damage/knockback negation)
- Batch restore with suppressed physics recomputation

---

## API Reference

### Callback Registration
```lua
armorforge.api.register_on_equip(func)
armorforge.api.register_on_unequip(func)
armorforge.api.register_pre_equip(func)
armorforge.api.register_pre_unequip(func)
```

---

### Equip / Unequip
```lua
armorforge.api.equip(player, stack, slot)
armorforge.api.unequip(player, slot)
```

---

### Stats
```lua
armorforge.api.get_stats(player)
```

---

### Equipped Items
```lua
armorforge.api.get_equipped(player)
armorforge.api.get_equipped_in_slot(player, slot)
armorforge.api.has_equipped(player, slot)
armorforge.api.get_equipped_list(player)
```

---

### Persistence Helpers
```lua
restore_equipped_from_storage(player)
save_equipped(player)
```

---

## Physics Backend

ArmorForge exposes its physics system under `armorforge.physics`.  
This backend is automatically used if neither `pova` nor `player_monoids` are available.

### Functions
```lua
armorforge.physics.add(name, key, def)
armorforge.physics.del(name, key)
armorforge.physics.apply(player)
```

- **add(name, key, def)** → Adds a physics override for a player under a unique key.  
- **del(name, key)** → Removes a physics override by key.  
- **apply(player)** → Applies all accumulated overrides to the player.

### Supported Override Fields
You can override any of the following physics properties:

- **Movement speeds**  
  - `speed`, `speed_walk`, `speed_climb`, `speed_crouch`, `speed_fast`
- **Jump & gravity**  
  - `jump`, `gravity`
- **Liquid behavior**  
  - `liquid_fluidity`, `liquid_fluidity_smooth`, `liquid_sink`
- **Acceleration**  
  - `acceleration_default`, `acceleration_air`, `acceleration_fast`
- **Sneak & movement flags**  
  - `sneak` (boolean)  
  - `sneak_glitch` (boolean)  
  - `new_move` (boolean)

### Override Layers
- **default** → Base values applied first.  
- **additive keys** → Each override adds to the current value.  
- **min** → Clamp values to a minimum.  
- **max** → Clamp values to a maximum.  
- **force** → Force values to exact numbers, overriding everything else.

### Behavior
- Overrides are merged together in order: `default` → additive → `min` → `max` → `force`.  
- Numbers are summed, booleans are OR’d, other values replace.  
- Automatically resets and applies overrides when players join/leave.  
- Other mods can safely add/remove physics changes without worrying about conflicts — ArmorForge shares its physics system.

---

## Example Usage

### Adding Physics Overrides
```lua
-- Give player extra jump and speed
armorforge.physics.add("Danny", "armor_bonus", {
    jump = 0.5,
    speed = 0.2,
})

-- Apply changes
armorforge.physics.apply(player)
```

### Clamping Values
```lua
-- Ensure gravity never drops below 0.5
armorforge.physics.add("Danny", "gravity_min", {
    gravity = 0.5,
})
armorforge.physics.apply(player)
```

### Forcing Values
```lua
-- Force sneak to always be enabled
armorforge.physics.add("Danny", "force_sneak", {
    sneak = true,
})
armorforge.physics.apply(player)
```

### Removing Overrides
```lua
-- Remove a specific override
armorforge.physics.del("Danny", "armor_bonus")
armorforge.physics.apply(player)
```

---

## Notes
- Items must define an `armor` table in their definition for stats:
```lua
armor = {
    speed = 0.1,
    gravity = -0.05,
    jump = 0.2,
    armor = 5,
    knockback = -0.1,
    block = 10,
}
```
- Physics backend is automatically selected (`pova`, `player_monoids`, or builtin).  
  → If neither is present, ArmorForge uses its **own physics engine** (`armorforge.physics`).  
  → Other mods using this API automatically share this system — no duplicate physics handling required.

---

