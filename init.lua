
local ARMOR = {}
local PLAYER_ARMOR = {}
local storage = minetest.get_mod_storage()

ARMOR.slots = {"helmet", "chest", "leggings", "boots"}

function ARMOR.equip(player, stack, slot)
    if not player or not stack or stack:is_empty() then return false end
    local name = player:get_player_name()

    PLAYER_ARMOR[name] = PLAYER_ARMOR[name] or {}

    -- Detach any existing entity in this slot
    itemforge3d.detach_entity(player, nil, {id = slot})

    -- Return old stack if present
    local old_stack = PLAYER_ARMOR[name][slot]
    if old_stack and not old_stack:is_empty() then
        local inv = player:get_inventory()
        if inv and not inv:room_for_item("main", old_stack) then
            -- Drop at player’s feet if inventory is full
            minetest.add_item(player:get_pos(), old_stack)
        else
            inv:add_item("main", old_stack)
        end
    end

    -- Attach new armor piece
    itemforge3d.attach_entity(player, stack, {id = slot})

    -- Save equipped stack
    PLAYER_ARMOR[name][slot] = ItemStack(stack)

    return true
end

function ARMOR.unequip(player, slot)
    if not player then return false end
    local name = player:get_player_name()

    local old_stack = PLAYER_ARMOR[name] and PLAYER_ARMOR[name][slot]

    -- Detach entity
    itemforge3d.detach_entity(player, nil, {id = slot})

    -- Return old stack if present
    if old_stack and not old_stack:is_empty() then
        local inv = player:get_inventory()
        if inv and not inv:room_for_item("main", old_stack) then
            -- Drop at player’s feet if inventory is full
            minetest.add_item(player:get_pos(), old_stack)
        else
            inv:add_item("main", old_stack)
        end
    end

    if PLAYER_ARMOR[name] then
        PLAYER_ARMOR[name][slot] = nil
    end

    return true
end

function ARMOR.count_stats(player)
    local name = player:get_player_name()
    local equipped = PLAYER_ARMOR[name]
    if not equipped then
        return {speed=0, gravity=0, jump=0, armor=0, knockback=0}
    end

    local totals = {speed=0, gravity=0, jump=0, armor=0, knockback=0}

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
    if not player then return nil end
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
    local name = player:get_player_name()
    local inv_name = "armor_" .. name

    -- Remove old detached inventory if it exists
    if minetest.get_inventory({type="detached", name=inv_name}) then
        minetest.remove_detached_inventory(inv_name)
    end

    -- Create new detached inventory
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
            ARMOR.sync_detached(player) -- keep GUI in sync
        end,
        on_take = function(inv, listname, index, stack, player)
            local slot = ARMOR.slots[index]
            -- Only detach + clear slot, DO NOT re-add to inventory
            itemforge3d.detach_entity(player, nil, {id = slot})
            if PLAYER_ARMOR[name] then
                PLAYER_ARMOR[name][slot] = nil
            end
            ARMOR.sync_detached(player) -- keep GUI in sync
        end,
    })

    inv:set_size("main", #ARMOR.slots)

    -- Fill with currently equipped items
    ARMOR.sync_detached(player)

    return inv_name
end

-- Helper to sync detached inventory with actual equipped state
function ARMOR.sync_detached(player)
    if not player then return end
    local name = player:get_player_name()
    local inv = minetest.get_inventory({type="detached", name="armor_" .. name})
    if not inv then return end

    local equipped = ARMOR.get_equipped(player)
    for i, slot in ipairs(ARMOR.slots) do
        if equipped[slot] then
            inv:set_stack("main", i, equipped[slot])
        else
            inv:set_stack("main", i, ItemStack(nil))
        end
    end
end

minetest.register_chatcommand("armor", {
    description = "Open armor GUI",
    func = function(name)
        local fs = "size[8,9]" ..
                   "label[3,0;Armor Slots]" ..
                   "list[detached:armor_" .. name .. ";main;3,1;1,4;]" ..
                   "list[current_player;main;0,5;8,4;]" ..
                   "listring[detached:armor_" .. name .. ";main]" ..
                   "listring[current_player;main]"
        minetest.show_formspec(name, "armor:gui", fs)
    end,
})
armorforge3d = ARMOR