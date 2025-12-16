# ArmorForge API

## Features
- Slot-based equipment system (`helmet`, `chest`, `leggings`, `boots`, `shield`, `offhand`)
- Callback registration for **pre-equip/unequip** and **on-equip/unequip**
- Automatic persistence using `mod_storage` (save on leave, restore on join)
- Detached inventory integration with slot validation
- Stat aggregation (speed, gravity, jump, armor, knockback, block)
- Physics backend support (`pova`, `player_monoids`, or builtin fallback)
- Metadata preservation for equipped items
- HP reduction and knockback scaling based on stats
- Block chance support (damage/knockback negation)
- Batch restore with suppressed physics recomputation

---

## API Reference

### Callback Registration
```lua
armorforge.register_on_equip(func)
armorforge.register_on_unequip(func)
armorforge.register_pre_equip(func)
armorforge.register_pre_unequip(func)
```
- `func(player, stack, slot)` is called when equipping/unequipping.
- Pre-callbacks can **return false** to cancel the action.

---

### Equip / Unequip
```lua
armorforge.equip(player, stack, slot)
armorforge.unequip(player, slot)
```
- `equip` places an item into a slot and triggers callbacks.
- `unequip` removes an item from a slot and triggers callbacks.
- Physics are automatically updated for slots that contribute stats.

---

### Stats
```lua
armorforge.get_stats(player)
```
- Aggregates stats from all equipped items.
- Default stats:  
  `{speed=0, gravity=0, jump=0, armor=0, knockback=0, block=0}`
- Values are clamped to safe ranges:  
  - `speed` -10 → 10  
  - `gravity` 0 → 10  
  - `jump` -10 → 10  
  - `armor` 0 → 95  
  - `block` 0 → 100  

---

### Equipped Items
```lua
armorforge.get_equipped(player)
armorforge.get_equipped_in_slot(player, slot)
armorforge.has_equipped(player, slot)
armorforge.get_equipped_list(player)
```
- `get_equipped` → table of slot → ItemStack
- `get_equipped_in_slot` → stack in a specific slot
- `has_equipped` → boolean
- `get_equipped_list` → list of `{slot, item, stack}`

---

### Persistence Helpers
```lua
restore_equipped_from_storage(player)
save_equipped(player)
```
- Restores or saves equipped items using `mod_storage`.

---

## Example Usage

### Registering a Callback
```lua
armorforge.register_on_equip(function(player, stack, slot)
    minetest.chat_send_player(player:get_player_name(),
        "Equipped " .. stack:get_name() .. " in slot " .. slot)
end)
```

---

### Custom Pre-Equip Logic
```lua
armorforge.register_pre_equip(function(player, stack, slot)
    if stack:get_name() == "armor:forbidden_item" then
        return false -- cancel equip
    end
end)
```

---

### Equipping an Item in a Specific Slot
```lua
-- Equip a helmet
local player = minetest.get_player_by_name("Danny")
local helmet = ItemStack("armor:iron_helmet")
armorforge.equip(player, helmet, "helmet")

-- Equip a shield
local shield = ItemStack("armor:wooden_shield")
armorforge.equip(player, shield, "shield")

-- Equip an offhand item (no physics)
local torch = ItemStack("default:torch")
armorforge.equip(player, torch, "offhand")
```

---

### Unequipping from a Specific Slot
```lua
-- Remove whatever is in the chest slot
armorforge.unequip(player, "chest")
```

---

### Checking Equipped Items
```lua
-- Get the currently equipped helmet
local helmet_stack = armorforge.get_equipped_in_slot(player, "helmet")
if helmet_stack then
    minetest.chat_send_player(player:get_player_name(),
        "You are wearing: " .. helmet_stack:get_name())
end

-- Check if player has a shield equipped
if armorforge.has_equipped(player, "shield") then
    minetest.chat_send_player(player:get_player_name(), "Shield equipped!")
end
```

---

### Batch Restore Example
```lua
-- Restore a saved equipment list without recalculating physics each time
restore_equipped(player, {
    {slot="helmet", stack="armor:iron_helmet"},
    {slot="chest", stack="armor:iron_chestplate"},
    {slot="shield", stack="armor:wooden_shield"},
})
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
- Metadata is preserved when equipping/unequipping.
- Overflow handling: items are dropped if inventory is full.
- Physics backend is automatically selected (`pova`, `player_monoids`, or builtin).
- HP and knockback are reduced according to `armor` and `block` stats.

---

