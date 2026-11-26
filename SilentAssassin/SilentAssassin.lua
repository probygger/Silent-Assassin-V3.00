-------------------------------------------------
--  Menu Logic
-------------------------------------------------
_G.SilentAssassin = _G.SilentAssassin or {}
SilentAssassin._path = ModPath
SilentAssassin._loc_path = ModPath .. "loc/"
SilentAssassin._data_path = SavePath .. "silentassassin.txt"
SilentAssassin.settings = {}
SilentAssassin.localPagersUsed = 0

function SilentAssassin:Load()
    self.settings["num_pagers"] = 2
    self.settings["num_pagers_per_player"] = 2
    self.settings["enabled"] = true
    self.settings["stealth_kill_enabled"] = true
    self.settings["pager_bonus_enabled"] = false
    self.settings["matchmaking_filter"] = 1
    self.settings["pager_detection_threshold"] = 1

    local file = io.open(self._data_path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        if content and content ~= "" then
            local decoded = json.decode(content)
            if type(decoded) == "table" then
                for k, v in pairs(decoded) do
                    self.settings[k] = v
                end
            end
        end
    end
end

function SilentAssassin:Save()
    local file = io.open(self._data_path, "w+")
    if file then
        file:write(json.encode(self.settings))
        file:close()
    end
end

function SilentAssassin:getCompleteTable()
    local tbl = {}
    for i, v in pairs(SilentAssassin.settings) do
        if i == "num_pagers" then
            tbl[i] = v + 1
        elseif i == "num_pagers_per_player" then
            tbl[i] = v + 1
        elseif i == "pager_detection_threshold" then
            tbl[i] = v * 100
        else
            tbl[i] = v
        end
    end
    return tbl
end

function setNumPagers(this, item)
    SilentAssassin.settings["num_pagers"] = item:value() - 1
end

function setNumPagersPerPlayer(this, item)
    SilentAssassin.settings["num_pagers_per_player"] = item:value() - 1
end

function setEnabled(this, item)
    local value = item:value() == "on" and true or false
    SilentAssassin.settings["enabled"] = value
end

function setStealthKillEnabled(this, item)
    local value = item:value() == "on" and true or false
    SilentAssassin.settings["stealth_kill_enabled"] = value
end

function setMatchmakingFilter(this, item)
    SilentAssassin.settings["matchmaking_filter"] = item:value()
end

function setEnablePagerBonusToggle(this, item)
    local value = item:value() == "on" and true or false
    SilentAssassin.settings["pager_bonus_enabled"] = value
end

function setPagerDetectionThreshold(this, item)
    local value = item:value() / 100
    SilentAssassin.settings["pager_detection_threshold"] = value
end

function calculateStageStealthBonus()
    if getLocalPagersAnswered() == 0 then
        return 0.02
    end
    return 0
end

function calculateLevelStealthBonus()
    local numPagers = getNumPagers()
    local numPagersPerPlayer = math.min(numPagers, getNumPagersPerPlayer())
    local difficultyBonus = 0
    local parPagers = isStealthKillEnabled() and 2 or 4

    difficultyBonus = difficultyBonus + ((parPagers - numPagers) * 0.02)
    difficultyBonus = difficultyBonus + ((numPagers - numPagersPerPlayer) * 0.01)

    local missionBonus
    if managers.groupai and managers.groupai:state() then
        missionBonus = (numPagers - managers.groupai:state():get_nr_successful_alarm_pager_bluffs()) * 0.01
    else
        missionBonus = numPagers * 0.01
    end

    local playerBonus = (getLocalPagersAnswered() == 0) and 0.02 or 0
    return difficultyBonus + missionBonus + playerBonus
end

-- Load localization strings
Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_SilentAssassin", function(loc)
    local lang
    for _, mod in pairs(BLT and BLT.Mods:Mods() or {}) do
        if mod:GetName() == "ChnMod" and mod:IsEnabled() then
            lang = "zh-cn"
        end
    end

    if not lang and file.GetFiles(SilentAssassin._loc_path) then
        for _, filename in pairs(file.GetFiles(SilentAssassin._loc_path)) do
            local str = filename:match('^(.*).json$')
            if str and Idstring(str) and Idstring(str):key() == SystemInfo:language():key() then
                lang = str
                break
            end
        end
    end

    if not lang then
        lang = "english"
    end

    local path = SilentAssassin._loc_path .. lang .. ".json"
    if io.file_is_readable(path) then
        loc:load_localization_file(path)
    else
        loc:load_localization_file(SilentAssassin._loc_path .. "english.json")
    end
end)

-- Set up the menu
Hooks:Add("MenuManagerInitialize", "MenuManagerInitialize_SilentAssassin", function(menu_manager)
    MenuCallbackHandler.SilentAssassin_setNumPagers = setNumPagers
    MenuCallbackHandler.SilentAssassin_setNumPagersPerPlayer = setNumPagersPerPlayer
    MenuCallbackHandler.SilentAssassin_enabledToggle = setEnabled
    MenuCallbackHandler.SilentAssassin_killPagerEnabledToggle = setStealthKillEnabled
    MenuCallbackHandler.SilentAssassin_enablePagerBonusToggle = setEnablePagerBonusToggle
    MenuCallbackHandler.SilentAssassin_setMatchmakingFilter = setMatchmakingFilter
    MenuCallbackHandler.SilentAssassin_setPagerDetectionThreshold = setPagerDetectionThreshold

    MenuCallbackHandler.SilentAssassin_Close = function(this)
        SilentAssassin:Save()
    end

    SilentAssassin:Load()
    MenuHelper:LoadFromJsonFile(SilentAssassin._path .. "options.txt", SilentAssassin, SilentAssassin:getCompleteTable())
end)

function getNumPagers()
    if SilentAssassin.settings["num_pagers"] == nil then
        SilentAssassin:Load()
    end
    return SilentAssassin.settings["num_pagers"]
end

function getNumPagersPerPlayer()
    if SilentAssassin.settings["num_pagers_per_player"] == nil then
        SilentAssassin:Load()
    end
    return SilentAssassin.settings["num_pagers_per_player"]
end

function getEffectiveNumPagersPerPlayer()
    local numPerPlayer = getNumPagersPerPlayer()
    local numPagers = getNumPagers()
    local numPlayers = 1
    if managers.network and managers.network:session() then
        numPlayers = math.max(1, managers.network:session():amount_of_players())
    end
    return math.max(numPerPlayer, math.ceil(numPagers / numPlayers))
end

function isSAEnabled()
    if SilentAssassin.settings["enabled"] == nil then
        SilentAssassin:Load()
    end
    return SilentAssassin.settings["enabled"]
end

function isStealthKillEnabled()
    if SilentAssassin.settings["stealth_kill_enabled"] == nil then
        SilentAssassin:Load()
    end
    return SilentAssassin.settings["stealth_kill_enabled"]
end

function getPagerDetectionThreshold()
    if SilentAssassin.settings["pager_detection_threshold"] == nil then
        SilentAssassin:Load()
    end
    return SilentAssassin.settings["pager_detection_threshold"]
end

function isPagerBonusEnabled()
    return false
end

function getMatchmakingFilter()
    if SilentAssassin.settings["matchmaking_filter"] == nil then
        SilentAssassin:Load()
    end
    return SilentAssassin.settings["matchmaking_filter"]
end

function addLocalPagerAnswered()
    SilentAssassin.localPagersUsed = SilentAssassin.localPagersUsed + 1
end

function getLocalPagersAnswered()
    return SilentAssassin.localPagersUsed
end

-------------------------------------------------
--  Handler for damage received & Stealth kills
-------------------------------------------------
if RequiredScript == "lib/units/enemies/cop/copbrain" then
    if not _CopBrain_clbk_damage then
        _CopBrain_clbk_damage = CopBrain.clbk_damage
    end

    function CopBrain:clbk_damage(my_unit, damage_info)
        if _CopBrain_clbk_damage then
            self._cop_pager_ready = true
            _CopBrain_clbk_damage(self, my_unit, damage_info)
        end
    end

    if not _CopBrain_clbk_death then
        _CopBrain_clbk_death = CopBrain.clbk_death
    end

    function CopBrain:clbk_death(my_unit, damage_info)
        if managers.groupai and managers.groupai:state() and managers.groupai:state():whisper_mode() then
            if isSAEnabled() and isStealthKillEnabled() then
                local notice_progress = 0
                if self._logic_data and self._logic_data.detected_attention_objects then
                    for _, obj in pairs(self._logic_data.detected_attention_objects) do
                        if obj.notice_progress then
                            notice_progress = math.max(notice_progress, obj.notice_progress)
                        end
                    end
                end

                if notice_progress > getPagerDetectionThreshold() then
                    self._cop_pager_ready = true
                end

                local is_cool = self._unit and alive(self._unit) and self._unit:movement() and self._unit:movement():cool()
                if not self._cop_pager_ready and is_cool then
                    if self._unit:unit_data() then
                        self._unit:unit_data().has_alarm_pager = false
                    end
                end
            end
        end
        _CopBrain_clbk_death(self, my_unit, damage_info)
    end

-------------------------------------------------
--  Setting number of pagers
-------------------------------------------------
elseif RequiredScript == "lib/units/interactions/interactionext" then
    if not _IntimitateInteractionExt_at_interact_start then
        _IntimitateInteractionExt_at_interact_start = IntimitateInteractionExt._at_interact_start
    end

    function IntimitateInteractionExt:_at_interact_start(player, timer)
        if managers.groupai and managers.groupai:state() and managers.groupai:state():whisper_mode() then
            if self.tweak_data == "corpse_alarm_pager" then
                if Network:is_server() and not self._in_progress then
                    local bluffChance = {}
                    local numPagers = getNumPagers()

                    if not player:base().num_answered then
                        player:base().num_answered = 0
                    end

                    player:base().num_answered = player:base().num_answered + 1
                    local tableValue = (player:base().num_answered <= getEffectiveNumPagersPerPlayer()) and 1 or 0

                    for i = 0, (numPagers - 1), 1 do
                        table.insert(bluffChance, tableValue)
                    end
                    table.insert(bluffChance, 0)

                    tweak_data.player.alarm_pager["bluff_success_chance"] = bluffChance
                    tweak_data.player.alarm_pager["bluff_success_chance_w_skill"] = bluffChance
                    if player:base().is_local_player then
                        addLocalPagerAnswered()
                    end
                end
            end
        end
        _IntimitateInteractionExt_at_interact_start(self, player, timer)
    end

elseif RequiredScript == "lib/managers/jobmanager" then
    if not _JobManager_current_stage_data then
        _JobManager_current_stage_data = JobManager.current_stage_data
    end

    function JobManager.current_stage_data(self)
        if isSAEnabled() and isPagerBonusEnabled() then
            return modifyGhostBonus(self, _JobManager_current_stage_data(self))
        end
        return _JobManager_current_stage_data(self)
    end

    if not _JobManager_current_level_data then
        _JobManager_current_level_data = JobManager.current_level_data
    end

    function JobManager.current_level_data(self)
        if isSAEnabled() and isPagerBonusEnabled() then
            return modifyGhostBonus(self, _JobManager_current_level_data(self))
        end
        return _JobManager_current_level_data(self)
    end

    function modifyGhostBonus(self, level_data)
        if level_data and level_data.ghost_bonus then
            local new_data = {}
            for k, v in pairs(level_data) do
                if k == "ghost_bonus" then
                    local bonus = JobManager.on_last_stage(self) and calculateLevelStealthBonus() or calculateStageStealthBonus()
                    new_data[k] = math.clamp(v + bonus, 0, 1)
                else
                    new_data[k] = v
                end
            end
            return new_data
        end
        return level_data
    end
end

function CreateSALobbyMessage()
    local message = managers.localization:text("sa_lobby_notice_1")
    if isStealthKillEnabled() then
        message = message .. managers.localization:text("sa_lobby_notice_2")
    end

    local params = {
        num_pagers = getNumPagers(),
        num_per_player = getNumPagersPerPlayer(),
        pager_detection_threshold_pct = getPagerDetectionThreshold() * 100
    }
    message = message .. managers.localization:text("sa_lobby_notice_3", params)
    return message
end

Hooks:Add("NetworkManagerOnPeerAdded", "NetworkManagerOnPeerAdded_SA", function(peer, peer_id)
    if Network:is_server() and isSAEnabled() then
        DelayedCalls:Add("DelayedSAAnnounce" .. tostring(peer_id), 2, function()
            local message = CreateSALobbyMessage()
            local peer2 = managers.network:session() and managers.network:session():peer(peer_id)
            if peer2 then
                peer2:send("send_chat_message", ChatManager.GAME, message)
            end
        end)
    end
end)
