require("lib/managers/menu/raid_menu/raidguibase")
require("lib/managers/menu/raid_menu/controls/raidguicontrol")

--------------------------------------------------------------------------------

---@class StatsScreen
---@field new fun(self, ws, fullscreen_ws, node):StatsScreen
---@field super table
---@field _node table
---@field _root_panel table
StatsScreen = StatsScreen or class(RaidGuiBase)

local padding = 10
local row_h = 28
local heading_h = 52
local font = tweak_data.gui.fonts.din_compressed
local font_size = tweak_data.gui.font_sizes.extra_small
local heading_font_size = tweak_data.gui.font_sizes.medium

local function loc(id)
    return managers.localization:text(id)
end

local function number(value)
    local str = string.format("%d", math.floor((tonumber(value) or 0) + 0.5))
    local formatted = str:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return formatted
end

local function percent(part, total)
    if not total or total <= 0 then
        return "-"
    end
    return string.format("%.1f%%", (part or 0) / total * 100)
end

local function duration(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    return string.format("%dh %02dm", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
end

local function prettify(id)
    return (tostring(id):gsub("_", " "):gsub("(%a)([%w]*)", function(a, b)
        return a:upper() .. b
    end))
end

---@param id string
---@param name_id string|nil
local function localized_or_pretty(id, name_id)
    if name_id and managers.localization:exists(name_id) then
        return managers.localization:text(name_id)
    end
    return prettify(id)
end

local function weapon_name(id)
    if id == "turret_m2" then
        return loc("ss_turret_m2")
    end
    local tweak = tweak_data.weapon[id]
    return localized_or_pretty(id, tweak and tweak.name_id)
end

local function melee_name(id)
    -- melee with a firearm equipped is tracked as "weapon"
    if id == "weapon" then
        return loc("ss_weapon_bash")
    end
    local tweak = tweak_data.blackmarket.melee_weapons[id]
    return localized_or_pretty(id, tweak and tweak.name_id)
end

local function grenade_name(id)
    local tweak = tweak_data.projectiles[id]
    return localized_or_pretty(id, tweak and tweak.name_id)
end

-- levels that are shown (and summed up) as another level
local level_aliases = {
    ger_bridge_operation = "ger_bridge",
}

-- levels have no name of their own, the mission that uses the level does
local function level_name(id)
    for _, mission in pairs(tweak_data.operations.missions) do
        if mission.level_id == id and mission.name_id then
            return localized_or_pretty(id, mission.name_id)
        end
    end
    return prettify(id)
end

-- enemy ids are "<type>[_commander_backup][_<weapon>]", the weapon and backup variants are summed up into their type
local function enemy_group(id)
    id = id:gsub("_commander_backup", ""):gsub("_kar98$", ""):gsub("_mp38$", ""):gsub("_shotgun$", ""):gsub("_stg44$", "")
    return (id:gsub("_captain_b$", "_captain"))
end

local function enemy_name(group)
    local loc_id = "ss_enemy_" .. group
    if managers.localization:exists(loc_id) then
        return managers.localization:text(loc_id)
    end
    return prettify(group)
end

---@param tbl table|nil
---@param sort_by fun(v):number
---@return table[] @{id, value}, sorted descending
local function sorted_entries(tbl, sort_by)
    local result = {}
    for id, value in pairs(tbl or {}) do
        table.insert(result, { id = id, value = value })
    end
    table.sort(result, function(l, r)
        local ls, rs = sort_by(l.value), sort_by(r.value)
        if ls ~= rs then
            return ls > rs
        end
        return l.id < r.id
    end)
    return result
end

--------------------------------------------------------------------------------

function StatsScreen:init(ws, fullscreen_ws, node)
    StatsScreen.super.init(self, ws, fullscreen_ws, node, "stats_screen")
    self._root_panel.ctrls = self._root_panel.ctrls or {}
end

function StatsScreen:_set_initial_data()
    self._node.components.raid_menu_header:set_screen_name("raid_stats_screen")
end

function StatsScreen:_layout()
    self._object = self._root_panel:panel({})

    local header_height = self._node.components.raid_menu_header._screen_subtitle_label:bottom()
    local footer_height = self._node.components.raid_menu_footer._panel_h

    self._scroll = self._object:scrollable_area({
        name = "stats_screen_scroll",
        scroll_step = 35,
        x = padding,
        y = header_height + padding,
        w = self._object:w() - padding * 2,
        h = self._object:h() - header_height - footer_height - padding * 2,
    })

    self._content = self._scroll:get_panel()
    self._blocks = {}

    local ok, err = pcall(function()
        self:_build()
        self:_place_blocks()
    end)
    if not ok then
        log("[StatsScreen] " .. tostring(err))
    end

    self._scroll:setup_scroll_area()
end

-- sections are collected as blocks first and then placed into the shortest column
function StatsScreen:_add_heading(text)
    self._block = { heading = text, rows = {} }
    table.insert(self._blocks, self._block)
end

---@param cols string[] @first column is left aligned, the others are right aligned
---@param is_header boolean|nil
function StatsScreen:_add_row(cols, is_header)
    table.insert(self._block.rows, { cols = cols, is_header = is_header })
end

function StatsScreen:_place_blocks()
    local column_count = 3
    local gap = 40
    local column_w = (self._content:w() - gap * (column_count - 1)) / column_count
    local heights = {}
    for i = 1, column_count do
        heights[i] = 0
    end

    for _, block in ipairs(self._blocks) do
        local column = 1
        for i = 2, column_count do
            if heights[i] < heights[column] then
                column = i
            end
        end

        local x = (column - 1) * (column_w + gap)
        local y = heights[column]

        self._content:label({
            text = utf8.to_upper(block.heading),
            font = font,
            font_size = heading_font_size,
            color = tweak_data.gui.colors.raid_red,
            x = x,
            y = y,
            w = column_w,
            h = heading_h,
            vertical = "center",
        })
        y = y + heading_h

        for _, row in ipairs(block.rows) do
            local num_cols = #row.cols
            local color = row.is_header and tweak_data.gui.colors.raid_grey or tweak_data.gui.colors.raid_white
            local first_share = num_cols > 1 and ({ 0.6, 0.5, 0.4, 0.3 })[num_cols - 1] or 1
            local first_w = column_w * first_share
            local other_w = num_cols > 1 and (column_w - first_w) / (num_cols - 1) or 0

            for i, text in ipairs(row.cols) do
                self._content:label({
                    text = tostring(text),
                    font = font,
                    font_size = font_size,
                    color = color,
                    align = i == 1 and "left" or "right",
                    vertical = "center",
                    x = x + (i == 1 and 0 or first_w + (i - 2) * other_w),
                    y = y,
                    w = i == 1 and first_w or other_w,
                    h = row_h,
                })
            end
            y = y + row_h
        end

        heights[column] = y + 20
    end
end

function StatsScreen:_build()
    local stats = managers.statistics and managers.statistics._global
    if not stats then
        return
    end

    local killed = stats.killed or {}
    local total = killed.total or {}
    local shots = stats.shots_fired or {}
    local sessions = stats.sessions or {}
    local misc = stats.misc or {}
    local downed = stats.downed or {}

    self:_add_heading(loc("ss_overview"))
    self:_add_row({ loc("ss_play_time"), duration((stats.play_time and stats.play_time.minutes or 0) * 60) })
    self:_add_row({ loc("ss_sessions"), number(sessions.count) })
    self:_add_row({ loc("ss_kills"), number(total.count) })
    self:_add_row({ loc("ss_head_shots"), number(total.head_shots) })
    self:_add_row({ loc("ss_head_shot_rate"), percent(total.head_shots, total.count) })
    self:_add_row({ loc("ss_shots"), number(shots.total) })
    self:_add_row({ loc("ss_hits"), number(shots.hits) })
    self:_add_row({ loc("ss_accuracy"), percent(shots.hits, shots.total) })
    self:_add_row({ loc("ss_reloads"), number(stats.reloads and stats.reloads.count) })
    self:_add_row({ loc("ss_revives"), number(stats.revives and stats.revives.player_count) })
    self:_add_row({ loc("ss_bleed_outs"), number(downed.bleed_out) })
    self:_add_row({ loc("ss_deaths"), number(downed.death) })
    self:_add_row({ loc("ss_objectives"), number(stats.objectives and stats.objectives.count) })
    self:_add_row({ loc("ss_health_lost"), number(stats.health and stats.health.amount_lost) })
    self:_add_row({ loc("ss_dogtags"), number(misc.dogtags_collected) })
    self:_add_row({ loc("ss_loot_crates"), number(misc.open_loot_crate) })
    self:_add_row({ loc("ss_vehicle_kills"), number(stats.killed_by_vehicle and stats.killed_by_vehicle.count) })

    -- weapons
    local weapon_shots = stats.shots_by_weapon or {}
    self:_add_heading(loc("ss_weapons"))
    self:_add_row({ "", loc("ss_kills"), loc("ss_col_headshots"), loc("ss_col_accuracy") }, true)
    for _, entry in ipairs(sorted_entries(stats.killed_by_weapon, function(v) return v.count or 0 end)) do
        local weapon_shot = weapon_shots[entry.id] or {}
        self:_add_row({
            weapon_name(entry.id),
            number(entry.value.count),
            percent(entry.value.headshots, entry.value.count),
            percent(weapon_shot.hits, weapon_shot.total),
        })
    end

    -- melee / grenades
    self:_add_heading(loc("ss_melee"))
    for _, entry in ipairs(sorted_entries(stats.killed_by_melee, function(v) return v end)) do
        self:_add_row({ melee_name(entry.id), number(entry.value) })
    end

    self:_add_heading(loc("ss_grenades"))
    for _, entry in ipairs(sorted_entries(stats.killed_by_grenade, function(v) return v end)) do
        self:_add_row({ grenade_name(entry.id), number(entry.value) })
    end

    -- enemies
    local enemies = {}
    for id, value in pairs(killed) do
        if id ~= "total" then
            local group = enemy_group(id)
            local merged = enemies[group] or { count = 0, head_shots = 0 }
            merged.count = merged.count + (value.count or 0)
            merged.head_shots = merged.head_shots + (value.head_shots or 0)
            enemies[group] = merged
        end
    end
    self:_add_heading(loc("ss_enemies"))
    self:_add_row({ "", loc("ss_kills"), loc("ss_col_headshots") }, true)
    for _, entry in ipairs(sorted_entries(enemies, function(v) return v.count or 0 end)) do
        if (entry.value.count or 0) > 0 then
            self:_add_row({ enemy_name(entry.id), number(entry.value.count), percent(entry.value.head_shots, entry.value.count) })
        end
    end

    -- missions
    self:_add_heading(loc("ss_missions"))
    self:_add_row({ "", loc("ss_col_started"), loc("ss_col_completed"), loc("ss_col_quit"), loc("ss_col_time") }, true)
    local levels = {}
    for id, level in pairs(sessions.levels or {}) do
        id = level_aliases[id] or id
        local merged = levels[id] or {}
        for key, value in pairs(level) do
            merged[key] = (merged[key] or 0) + (tonumber(value) or 0)
        end
        levels[id] = merged
    end
    for _, entry in ipairs(sorted_entries(levels, function(v) return v.started or 0 end)) do
        local level = entry.value
        -- the game keeps an (empty) entry for every level it knows, e.g. custom raids: only list the ones played
        local played = (level.started or 0) > 0 or (level.completed or 0) > 0 or (level.quited or 0) > 0
        if played and not tostring(entry.id):find("^fake_mission") then
            self:_add_row({
                level_name(entry.id),
                number(level.started),
                number(level.completed),
                number(level.quited),
                duration(level.time),
            })
        end
    end

    -- characters
    self:_add_heading(loc("ss_characters"))
    for _, entry in ipairs(sorted_entries(sessions.characters, function(v) return v end)) do
        local loc_id = "ss_character_" .. entry.id
        self:_add_row({ managers.localization:exists(loc_id) and loc(loc_id) or prettify(entry.id), number(entry.value) })
    end
end

function StatsScreen:close()
    self._root_panel:clear()
    self._root_panel.ctrls = {}
end

--------------------------------------------------------------------------------

Hooks:Add("MenuComponentManagerInitialize", "MenuComponentManagerInitialize.StatsScreen",
    function(self)
        RaidMenuHelper:CreateMenu({
            name = "raid_stats_screen",
            name_id = "raid_stats_screen",
            inject_list = "raid_menu_left_options",
            inject_after = "network",
            icon = "menu_item_cards",
            class = StatsScreen,
        })
    end
)
