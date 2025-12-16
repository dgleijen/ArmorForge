local ARMOR = {}
local PLAYER_ARMOR = {}

local STORAGE = core.get_mod_storage()

-- Default
local DEFAULT_SLOTS = {"helmet", "chest", "leggings", "boots", "shield", "offhand"}
local DEFAULT_STATS = {speed=0, gravity=0, jump=0, armor=0, knockback=0, block=0}

-- Callbacks
local ON_EQUIP = {}
local ON_UNEQUIP = {}
local PRE_EQUIP = {}
local PRE_UNEQUIP = {}

-- Physics backend check
local MODPATH = core.get_modpath(core.get_current_modname()) 
local HAS_POVA  = MODPATH ~= nil and core.global_exists("pova")
local HAS_MONOIDS  = MODPATH ~= nil and core.global_exists("player_monoids")
local BUILTIN = dofile(core.get_modpath(core.get_current_modname()) .. "/physx.lua")
local check_mod = function()
    if HAS_POVA then
        return "pova"
    elseif HAS_MONOIDS then
        return "player_monoids"
    else
        return "builtin"
    end
end

local PHYSICS_MOD = check_mod()

-- Helper Functions
local PHYSICS_STRING = "armorforge:armor"

local function apply_physics(player)
    local stats = ARMOR.get_stats(player)
    local name = player:get_player_name()

    if PHYSICS_MOD == "pova" then
        pova.del_override(name, PHYSICS_STRING)
        pova.add_override(name, PHYSICS_STRING, {
            speed   = stats.speed,
            gravity = stats.gravity,
            jump    = stats.jump,
        })
        pova.do_override(player)

    elseif PHYSICS_MOD == "player_monoids" then
        for _, stat in ipairs({"jump", "speed", "gravity"}) do
            player_monoids[stat]:del_change(player, PHYSICS_STRING)
        end
        local overrides = {
            speed   = stats.speed,
            gravity = stats.gravity,
            jump    = stats.jump,
        }
        for key, value in pairs(overrides) do
            player_monoids[key]:add_change(player, value, PHYSICS_STRING)
        end

    else
        BUILTIN.del(name, PHYSICS_STRING)
        BUILTIN.add(name, PHYSICS_STRING, {
            speed   = stats.speed,
            gravity = stats.gravity,
            jump    = stats.jump,
        })
        BUILTIN.apply(player)
    end
end

local function get_inv_name(player)
    return "armorforge_" .. player:get_player_name()
end

local function is_valid_slot(slot)
    for _, s in ipairs(DEFAULT_SLOTS) do
        if s == slot then return true end
    end
    return false
end

local function clamp(x, minv, maxv)
    if x < minv then return minv end
    if x > maxv then return maxv end
    return x
end

function count_stats(player)
    local totals = table.copy(DEFAULT_STATS)
    local name = player:get_player_name()
    local equipped = PLAYER_ARMOR[name]
    if not equipped then return totals end

    for slot, stack in pairs(equipped) do
        if slot ~= "offhand" then
            local def = stack:get_definition()
            local a = def and def.armor
            if a then
                totals.speed     = totals.speed     + (a.speed or 0)
                totals.gravity   = totals.gravity   + (a.gravity or 0)
                totals.jump      = totals.jump      + (a.jump or 0)
                totals.armor     = totals.armor     + (a.armor or 0)
                totals.knockback = totals.knockback + (a.knockback or 0)
                totals.block     = totals.block     + (a.block or 0)
            end
        end
    end

    totals.speed   = clamp(totals.speed,   -10, 10)
    totals.gravity = clamp(totals.gravity,  0, 10)
    totals.jump    = clamp(totals.jump,    -10, 10)
    totals.armor   = clamp(totals.armor,    0, 95)
    totals.block   = clamp(totals.block,    0, 100)
    return totals
end


-- API
function ARMOR.get_stats(player)
    return count_stats(player)
end

function ARMOR.register_on_equip(func) table.insert(ON_EQUIP, func) end
function ARMOR.register_on_unequip(func) table.insert(ON_UNEQUIP, func) end
function ARMOR.register_pre_equip(func) table.insert(PRE_EQUIP, func) end
function ARMOR.register_pre_unequip(func) table.insert(PRE_UNEQUIP, func) end

function ARMOR.equip(player, stack, slot)
    if not player or not stack or stack:is_empty() or not is_valid_slot(slot) then
        return false
    end

    local name = player:get_player_name()
    PLAYER_ARMOR[name] = PLAYER_ARMOR[name] or {}

    local current = PLAYER_ARMOR[name][slot]
    if current and current:to_string() == stack:to_string() then
        -- No-op: same item already equipped
        return true
    end

    -- If something is equipped, unequip it first (with callbacks)
    if current and not current:is_empty() then
        for _, cb in ipairs(PRE_UNEQUIP) do
            if cb(player, current, slot) == false then return false end
        end
        PLAYER_ARMOR[name][slot] = nil
        for _, cb in ipairs(ON_UNEQUIP) do cb(player, current, slot) end
    end

    -- Pre-equip validation for the new item
    for _, cb in ipairs(PRE_EQUIP) do
        if cb(player, stack, slot) == false then
            return false
        end
    end

    -- Equip
    PLAYER_ARMOR[name][slot] = ItemStack(stack)

    -- Physics only if slot contributes stats
    if slot ~= "offhand" then
        apply_physics(player)
    end

    for _, cb in ipairs(ON_EQUIP) do
        cb(player, stack, slot)
    end

    return true
end

function ARMOR.unequip(player, slot)
    if not player or not is_valid_slot(slot) then return false end
    local name = player:get_player_name()
    local old_stack = PLAYER_ARMOR[name] and PLAYER_ARMOR[name][slot]

    for _, cb in ipairs(PRE_UNEQUIP) do
        if cb(player, old_stack, slot) == false then
            return false
        end
    end

    if PLAYER_ARMOR[name] then
        PLAYER_ARMOR[name][slot] = nil
    end

    if slot ~= "offhand" then
        apply_physics(player)
    end

    if old_stack and not old_stack:is_empty() then
        for _, cb in ipairs(ON_UNEQUIP) do
            cb(player, old_stack, slot)
        end
    end

    return true
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
            stack = stack:to_string(),
        })
    end
    return list
end

-- Itemstack management
function sync_detached(player)
    if not player then return end
    local inv_name = get_inv_name(player)
    local inv = core.get_inventory({type="detached", name=inv_name})
    if not inv then return end

    local equipped = ARMOR.get_equipped(player)
    for i, slot in ipairs(DEFAULT_SLOTS) do
        inv:set_stack("main", i, equipped[slot] or ItemStack(""))
    end
end

local function with_physics_suppressed(player, fn)
    local old_apply = apply_physics
    local suppressed = false
    apply_physics = function() suppressed = true end

    local ok = fn()

    apply_physics = old_apply
    if suppressed then
        old_apply(player) -- recompute once
    end
    return ok
end

-- Example: batch during restore
local function restore_equipped(player, item_list)
    if not player or not item_list then return false end
    return with_physics_suppressed(player, function()
        for _, entry in ipairs(item_list) do
            if entry.stack and entry.stack ~= "" then
                local stack = ItemStack(entry.stack)
                if not stack:is_empty() then
                    ARMOR.equip(player, stack, entry.slot)
                end
            end
        end
        return true
    end)
end


function restore_equipped_from_storage(player)
    if not player then return false end
    local name = player:get_player_name()
    local data = STORAGE:get_string("armorforge_" .. name)
    if data == "" then return false end
    local list = core.deserialize(data)
    if not list then return false end
    return restore_equipped(player, list)
end

local function save_equipped(player)
    if not player then return false end
    local name = player:get_player_name()
    local list = ARMOR.get_equipped_list(player)
    local data = core.serialize(list)
    STORAGE:set_string("armorforge_" .. name, data)
    return true
end

local function matches_slot(stack, slot)
    local def = stack:get_definition()
    return def and def.armor and def.armor.slot == slot
end

-- Define the inventory creation function
local function create_detached_inventory(player)
    local inv_name = get_inv_name(player)
    
    -- Check if inventory already exists
    if core.get_inventory({type="detached", name=inv_name}) then 
        return 
    end
    
    core.create_detached_inventory(inv_name, {
        allow_put = function(inv, listname, index, stack, player)
            local slot = DEFAULT_SLOTS[index]
            if matches_slot(stack, slot) then
                return stack:get_count()
            end
            return 0
        end,
        allow_take = function(inv, listname, index, stack, player)
            return stack:get_count()
        end,
        on_put = function(inv, listname, index, stack, player)
            local slot = DEFAULT_SLOTS[index]
            if matches_slot(stack, slot) then
                ARMOR.equip(player, stack, slot)
                sync_detached(player)
            end
        end,
        on_take = function(inv, listname, index, stack, player)
            local slot = DEFAULT_SLOTS[index]
            ARMOR.unequip(player, slot)
            sync_detached(player)
        end
    })
    
    -- Sync the inventory with current equipment
    sync_detached(player)
end

-- Save equipped armor when player leaves
core.register_on_leaveplayer(function(player)
    save_equipped(player)
end)

-- Restore equipped armor when player joins
core.register_on_joinplayer(function(player)
    restore_equipped_from_storage(player)
    create_detached_inventory(player)
    apply_physics(player)  -- Ensure physics are applied after restore
end)

-- HP and Knockback calculations with stats
core.register_on_player_hpchange(function(player, hp_change, reason)
    if hp_change < 0 then
        local stats = ARMOR.get_stats(player)

        local defense = stats.armor or 0
        if defense < 0 then defense = 0 end
        if defense > 95 then defense = 95 end

        local block = stats.block or 0
        if block > 0 and math.random(100) <= block then
            return 0
        end

        local incoming = -hp_change
        local reduced_mag = incoming * (1 - defense / 100)
        local final_mag = math.max(1, math.floor(reduced_mag + 0.0001))

        return -final_mag
    end

    return hp_change
end, true)

local old_knockback = core.calculate_knockback

function core.calculate_knockback(player, hitter, time_from_last_punch, tool_capabilities, dir, distance, damage)
    local knockback = old_knockback(player, hitter, time_from_last_punch, tool_capabilities, dir, distance, damage)

    local stats = ARMOR.get_stats(player)
    local defense = stats.armor or 0
    local block   = stats.block or 0

    if block > 0 and math.random(100) <= block then
        return {x=0, y=0, z=0}
    end

    if defense > 0 then
        knockback = vector.multiply(knockback, 1 - defense / 100)
    end

    return knockback
end

armorforge = {
    api = ARMOR,
    physics = BUILTIN,
}
