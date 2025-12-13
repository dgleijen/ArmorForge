local ARMOR = {}
local PLAYER_ARMOR = {}
local storage = minetest.get_mod_storage()

ARMOR.slots = {"helmet", "chest", "leggings", "boots", "shield"}
ARMOR.on_equip_callbacks = {}
ARMOR.on_unequip_callbacks = {}
ARMOR.pre_equip_callbacks = {}
ARMOR.pre_unequip_callbacks = {}

ARMOR.default_stats = {speed=0, gravity=0, jump=0, armor=0, knockback=0}

local function get_inv_name(player)
    return "armorforge3d_" .. player:get_player_name()
end

local function is_valid_slot(slot)
    for _, s in ipairs(ARMOR.slots) do
        if s == slot then return true end
    end
    return false
end

-- Callback registration
function ARMOR.register_on_equip(func)
    table.insert(ARMOR.on_equip_callbacks, func)
end

function ARMOR.register_on_unequip(func)
    table.insert(ARMOR.on_unequip_callbacks, func)
end

function ARMOR.register_pre_equip(func)
    table.insert(ARMOR.pre_equip_callbacks, func)
end

function ARMOR.register_pre_unequip(func)
    table.insert(ARMOR.pre_unequip_callbacks, func)
end

function ARMOR.equip(player, stack, slot)
    if not player or not stack or stack:is_empty() or not is_valid_slot(slot) then
        return false
    end
    for _, cb in ipairs(ARMOR.pre_equip_callbacks) do
        if cb(player, stack, slot) == false then
            return false
        end
    end

    local name = player:get_player_name()
    PLAYER_ARMOR[name] = PLAYER_ARMOR[name] or {}
    PLAYER_ARMOR[name][slot] = ItemStack(stack)

    for _, cb in ipairs(ARMOR.on_equip_callbacks) do
        cb(player, stack, slot)
    end

    return true
end

function ARMOR.unequip(player, slot)
    if not player or not is_valid_slot(slot) then return false end
    local name = player:get_player_name()
    local old_stack = PLAYER_ARMOR[name] and PLAYER_ARMOR[name][slot]

    for _, cb in ipairs(ARMOR.pre_unequip_callbacks) do
        if cb(player, old_stack, slot) == false then
            return false
        end
    end

    if PLAYER_ARMOR[name] then
        PLAYER_ARMOR[name][slot] = nil
    end

    if old_stack and not old_stack:is_empty() then
        local inv = player:get_inventory()
        if inv and inv:room_for_item("main", old_stack) then
            inv:add_item("main", old_stack)
        else
            minetest.item_drop(old_stack, player, player:get_pos())
        end

        for _, cb in ipairs(ARMOR.on_unequip_callbacks) do
            cb(player, old_stack, slot)
        end
    end

    return true
end

function ARMOR.count_stats(player)
    local name = player:get_player_name()
    local equipped = PLAYER_ARMOR[name]
    local totals = table.copy(ARMOR.default_stats)

    if not equipped then return totals end

    for slot, stack in pairs(equipped) do
        local def = stack:get_definition()
        if def and def.armor then
            totals.speed     = totals.speed     + (def.armor.speed or 0)
            totals.gravity   = totals.gravity   + (def.armor.gravity or 0)
            totals.jump      = totals.jump      + (def.armor.jump or 0)
            totals.armor     = totals.armor     + (def.armor.armor or 0)
            totals.knockback = totals.knockback + (def.armor.knockback or 0)
        end
    end

    return totals
end

function ARMOR.get_stats(player)
    return ARMOR.count_stats(player)
end

function ARMOR.get_equipped(player)
    if not player then return {} end
    local name = player:get_player_name()
    local equipped = PLAYER_ARMOR[name]
    if not equipped then return {} end
    local out = {}
    for slot, stack in pairs(equipped) do
        out[slot] = ItemStack(stack)
    end
    return out
end

function ARMOR.get_equipped_in_slot(player, slot)
    if not player or not is_valid_slot(slot) then return nil end
    local name = player:get_player_name()
    local equipped = PLAYER_ARMOR[name]
    if not equipped then return nil end
    return equipped[slot]
end

function ARMOR.has_equipped(player, slot)
    return ARMOR.get_equipped_in_slot(player, slot) ~= nil
end

function ARMOR.get_equipped_list(player)
    if not player then return {} end
    local name = player:get_player_name()
    local equipped = PLAYER_ARMOR[name]
    if not equipped then return {} end

    local list = {}
    for slot, stack in pairs(equipped) do
        table.insert(list, {
            slot = slot,
            item = stack:get_name(),
            stack = ItemStack(stack),
        })
    end
    return list
end

function ARMOR.restore_equipped(player, item_list)
    if not player or not item_list then return false end
    for _, entry in ipairs(item_list) do
        if entry.stack and not entry.stack:is_empty() then
            ARMOR.equip(player, entry.stack, entry.slot)
        end
    end
    return true
end

function ARMOR.save_equipped(player)
    if not player then return false end
    local name = player:get_player_name()
    local list = ARMOR.get_equipped_list(player)
    local data = minetest.serialize(list)
    storage:set_string("armor_" .. name, data)
    return true
end

function ARMOR.restore_equipped_from_storage(player)
    if not player then return false end
    local name = player:get_player_name()
    local data = storage:get_string("armor_" .. name)
    if data == "" then return false end
    local list = minetest.deserialize(data)
    if not list then return false end
    return ARMOR.restore_equipped(player, list)
end

function ARMOR.create_detached_inventory(player)
    if not player then return nil end
    local inv_name = get_inv_name(player)

    if minetest.get_inventory({type="detached", name=inv_name}) then
        minetest.remove_detached_inventory(inv_name)
    end

    local inv = minetest.create_detached_inventory(inv_name, {
        allow_put = function(inv, listname, index, stack, player)
            return stack:get_count()
        end,
        allow_take = function(inv, listname, index, stack, player)
            return stack:get_count()
        end,
        on_put = function(inv, listname, index, stack, player)
            local slot = ARMOR.slots[index]
            ARMOR.equip(player, stack, slot)
            ARMOR.sync_detached(player)
        end,
        on_take = function(inv, listname, index, stack, player)
            local slot = ARMOR.slots[index]
            ARMOR.unequip(player, slot)
            ARMOR.sync_detached(player)
        end
    })

    inv:set_size("main", #ARMOR.slots)
    ARMOR.sync_detached(player)
    return inv_name
end

function ARMOR.sync_detached(player)
    if not player then return end
    local inv = minetest.get_inventory({type="detached", name=get_inv_name(player)})
    if not inv then return end

    local equipped = ARMOR.get_equipped(player)
    for i, slot in ipairs(ARMOR.slots) do
        inv:set_stack("main", i, equipped[slot] or ItemStack(""))
    end
end

core.register_on_leaveplayer(function(player)
    ARMOR.save_equipped(player)
end)

core.register_on_joinplayer(function(player)
    ARMOR.restore_equipped_from_storage(player)
    ARMOR.create_detached_inventory(player)
end)

armorforge3d = ARMOR