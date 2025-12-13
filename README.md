## Features
- Slot-based equipment system (`helmet`, `chest`, `leggings`, `boots`, `shield`)
- Callback registration for **pre-equip/unequip** and **on-equip/unequip**
- Automatic persistence using `mod_storage`
- Detached inventory integration
- Stat aggregation (speed, gravity, jump, armor, knockback)
- Metadata preservation for equipped items
- 
## API Reference

### Callback Registration
```lua
ARMOR.register_on_equip(func)
ARMOR.register_on_unequip(func)
ARMOR.register_pre_equip(func)
ARMOR.register_pre_unequip(func)
```
- `func(player, stack, slot)` is called when equipping/unequipping.
- Pre-callbacks can **return false** to cancel the action.

---

### Equip / Unequip
```lua
ARMOR.equip(player, stack, slot)
ARMOR.unequip(player, slot)
```
- `equip` places an item into a slot and triggers callbacks.
- `unequip` removes an item from a slot, returns it to inventory or drops it, and triggers callbacks.

---

### Stats
```lua
ARMOR.count_stats(player)
ARMOR.get_stats(player)
```
- Aggregates stats from all equipped items.
- Default stats: `{speed=0, gravity=0, jump=0, armor=0, knockback=0}`

---

### Equipped Items
```lua
ARMOR.get_equipped(player)
ARMOR.get_equipped_in_slot(player, slot)
ARMOR.has_equipped(player, slot)
ARMOR.get_equipped_list(player)
```
- `get_equipped` → table of slot → ItemStack
- `get_equipped_in_slot` → stack in a specific slot
- `has_equipped` → boolean
- `get_equipped_list` → list of `{slot, item, stack}`

---

## Example Usage

### Registering a Callback
```lua
ARMOR.register_on_equip(function(player, stack, slot)
    minetest.chat_send_player(player:get_player_name(),
        "Equipped " .. stack:get_name() .. " in slot " .. slot)
end)
```

### Custom Pre-Equip Logic
```lua
ARMOR.register_pre_equip(function(player, stack, slot)
    if stack:get_name() == "armor:forbidden_item" then
        return false -- cancel equip
    end
end)
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
}
```
- Metadata is preserved when equipping/unequipping.
- Overflow handling: items are dropped if inventory is full.

