-- Better Optical Camo
-- Copyright (c) 2022-2023 Lukas Berger
-- MIT License (See LICENSE.md)
local GameUI = require("lib/GameUI")
local i18nCustom = require("i18n")
local i18nDefault = require("i18n-default")

local k_trace = false
local k_debug = false
local k_info = true

local k_defaultSettings = {
    enableToggling = true,
    opticalCamoChargesDecayRateModifier = 1,
    opticalCamoChargesRegenRateModifier = 1,
    opticalCamoChargesUseMinimalDecayRate = false,
    opticalCamoRechargeImmediate = false,
    combatCloak = false,
    combatCloakDelay = 1.5,
    deactivateOnVehicleEnter = false
}

local k_i18n = {}

local m_activeSettings = {}
local m_pendingSettings = {}
local m_playerStatsModifiers = {}
local m_playerExitCombatDelayIDs = {}

registerForEvent("onTweak", function()
    print_debug("onTweak", "entering")
    -- ~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

    TweakDB:SetFlat("BaseStatusEffect.OpticalCamoPlayerBuffRare_inline1.value", -1)
    TweakDB:SetFlat("BaseStatusEffect.OpticalCamoPlayerBuffEpic_inline1.value", -1)
    TweakDB:SetFlat("BaseStatusEffect.OpticalCamoPlayerBuffLegendary_inline1.value", -1)

    -- ~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
    print_debug("onTweak", "exiting")
end)

registerForEvent("onInit", function()
    print_debug("onInit", "entering")
    -- ~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
    local player = Game.GetPlayer()

    -- apply the default settings to the active/pending settings tables
    applyDefaultSettings()

    -- load the default translations
    loadI18nFile("./i18n.default")

    -- load the custom translations
    -- overrides all default translations which the custom i18n-file defines
    loadI18nFile("./i18n")

    -- load settings from file and write back the updated version
    loadSettingsFromFile()
    writeSettingsToFile()

    if (player ~= nil) then
        if (k_debug) then
            dumpPlayerStats(player)
        end

        applySettings(player)
    end

    -- observe for playing mount a vehicle
    GameUI.Listen("VehicleEnter", function()
        local player = Game.GetPlayer()

        if (m_activeSettings.deactivateOnVehicleEnter) then
            deactivateOpticalCamo(player)
        end
    end)

    -- apply settings (status modifiers, etc.) on (re)-load
    ObserveBefore("PlayerPuppet", "OnGameAttached", function(this)
        print_trace("[PlayerPuppet::OnGameAttached]", "entering")
        -- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

        if (k_debug) then 
            dumpPlayerStats(this)
        end

        applySettings(this)

        if (k_debug) then 
            dumpPlayerStats(this)
        end

        -- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
        print_trace("[PlayerPuppet::OnGameAttached]", "exiting")
    end)

    -- toggle the cloak by pressing the combat gadget button again
    ObserveBefore("PlayerPuppet", "OnAction", function(this, action)
        print_trace("[PlayerPuppet::OnAction]", "entering")
        -- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

        local actionName = Game.NameToString(ListenerAction.GetName(action))
        local actionType = ListenerAction.GetType(action).value

        if (m_activeSettings.enableToggling) then
            if (actionName == "UseCombatGadget" and actionType == "BUTTON_PRESSED" and isOpticalCamoActive(this)) then
                deactivateOpticalCamo(this)
            end
        end

        -- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
        print_trace("[PlayerPuppet::OnAction]", "exiting")
    end)

    -- run additional actions when cloak is activated
    ObserveBefore("PlayerPuppet", "OnStatusEffectApplied", function(this, event)
        print_trace("[PlayerPuppet::OnStatusEffectApplied]", "entering")
        -- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

        local playerID = this:GetEntityID()
        local statsSystem = Game.GetStatsSystem()
        local statusEffectSystem = Game.GetStatusEffectSystem()
        local delaySystem = Game.GetDelaySystem()

        local hasActiveCamoGameplayTag = doesEventContainActiveCamoGameplayTag(event)
        local canPlayerExitCombatWithOpticalCamo = Game.HasStatFlag(this, "CanPlayerExitCombatWithOpticalCamo")
        local blockOpticalCamoRelicPerk = Game.HasStatFlag(this, "BlockOpticalCamoRelicPerk")
        local hasOpticalCamoSlideCoolPerkStatusEffect = statusEffectSystem:HasStatusEffect(playerID, "OpticalCamoSlideCoolPerk")
        local hasOpticalCamoGrappleStatusEffect = statusEffectSystem:HasStatusEffect(playerID, "OpticalCamoGrapple")

        local shouldRunInvisibilityLogic = (hasActiveCamoGameplayTag)
            and (not canPlayerExitCombatWithOpticalCamo)
            and (not blockOpticalCamoRelicPerk)
            and (not hasOpticalCamoSlideCoolPerkStatusEffect)
            and (not hasOpticalCamoGrappleStatusEffect)
            and (m_activeSettings.combatCloak)

        print_trace("[PlayerPuppet::OnStatusEffectApplied]", "hasActiveCamoGameplayTag="..tostring(hasActiveCamoGameplayTag))
        print_trace("[PlayerPuppet::OnStatusEffectApplied]", "canPlayerExitCombatWithOpticalCamo="..tostring(canPlayerExitCombatWithOpticalCamo))
        print_trace("[PlayerPuppet::OnStatusEffectApplied]", "blockOpticalCamoRelicPerk="..tostring(blockOpticalCamoRelicPerk))
        print_trace("[PlayerPuppet::OnStatusEffectApplied]", "hasOpticalCamoSlideCoolPerkStatusEffect="..tostring(hasOpticalCamoSlideCoolPerkStatusEffect))
        print_trace("[PlayerPuppet::OnStatusEffectApplied]", "hasOpticalCamoGrappleStatusEffect="..tostring(hasOpticalCamoGrappleStatusEffect))
        print_trace("[PlayerPuppet::OnStatusEffectApplied]", "m_activeSettings.combatCloak="..tostring(m_activeSettings.combatCloak))

        if (shouldRunInvisibilityLogic) then
            print_info("[PlayerPuppet::OnStatusEffectApplied]", "activating combat-cloak")

            setPlayerInvisible(this)
            makePlayerExitCombat(this)
        end

        -- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
        print_trace("[PlayerPuppet::OnStatusEffectApplied]", "exiting")
    end)

    -- run additional actions when cloak is deactivated
    ObserveBefore("PlayerPuppet", "OnStatusEffectRemoved", function(this, event)
        print_trace("[PlayerPuppet::OnStatusEffectRemoved]", "entering")
        -- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

        if (doesEventContainActiveCamoGameplayTag(event)) then
            print_info("[PlayerPuppet::OnStatusEffectRemoved]", "deactivating combat-cloak")

            setPlayerVisible(this)
            clearDelayedPlayerExitCombatEvents()
        end

        -- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
        print_trace("[PlayerPuppet::OnStatusEffectRemoved]", "exiting")
    end)

    -- reset registered status-modifiers, etc. on reload
    ObserveBefore("PlayerPuppet", "OnDetach", function(this)
        print_trace("[PlayerPuppet::OnDetach]", "entering")
        -- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

        unregisterPlayerStatsModifier(this)

        -- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
        print_trace("[PlayerPuppet::OnDetach]", "exiting")
    end)

    -- compatibility with "Custom Quickslots" for toggling the cloak if selected
    if (GetSingleton("HotkeyItemController")["UseEquippedItem"] ~= nil) then
        ObserveBefore("HotkeyItemController", "UseEquippedItem", function(this)
            print_trace("[HotkeyItemController::UseEquippedItem]", "entering")
            -- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

            if (m_activeSettings.enableToggling) then
                local player = Game.GetPlayer()

                if (this:IsOpticalCamoCyberwareAbility() and isOpticalCamoActive(player)) then
                    deactivateOpticalCamo(player)
                end
            end

            -- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
            print_trace("[HotkeyItemController::UseEquippedItem]", "exiting")
        end)
    end

    createSettingsMenu()

    if (k_debug) and (player ~= nil) then
        dumpPlayerStats(player)
    end

    -- ~~~~~~~~~~~~~~~~~~~~~~~~~~ --
    print_debug("onInit", "exiting")
end)

registerForEvent("onUpdate", function()
    print_trace("onUpdate", "entering")
    -- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

    if (not m_activeSettings.opticalCamoChargesUseMinimalDecayRate) then
        local player = Game.GetPlayer()

        if (player ~= nil) then
            local statPoolsSystem = Game.GetStatPoolsSystem()
            local opticalCamoCharges = statPoolsSystem:GetStatPoolValue(player:GetEntityID(), "OpticalCamoCharges")

            if (opticalCamoCharges < 0.01) then
                deactivateOpticalCamo(player)
            end
        end
    end

    -- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
    print_trace("onUpdate", "exiting")
end)

registerForEvent("onShutdown", function()
    print_debug("onShutdown", "entering")
    -- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
    local player = Game.GetPlayer()

    if (player ~= nil) then
        unregisterPlayerStatsModifier(player)
    end

    -- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
    print_debug("onShutdown", "exiting")
end)

function applySettings(player)
    if (m_activeSettings.opticalCamoChargesUseMinimalDecayRate) then
        registerPlayerStatsModifier(player, "OpticalCamoChargesDecayRate", "Multiplier", 0.025)
    else
        registerPlayerStatsModifier(player, "OpticalCamoChargesDecayRate", "Multiplier", m_activeSettings.opticalCamoChargesDecayRateModifier)
        registerPlayerStatsModifier(player, "OpticalCamoChargesRegenRate", "Multiplier", m_activeSettings.opticalCamoChargesRegenRateModifier)
    end

    if (m_activeSettings.opticalCamoRechargeImmediate) then
        registerPlayerStatsModifier(player, "OpticalCamoRechargeDuration", "Multiplier", 0.01)
    else
        registerPlayerStatsModifier(player, "OpticalCamoRechargeDuration", "Multiplier", (1 / m_activeSettings.opticalCamoChargesRegenRateModifier))
    end
end

function deactivateOpticalCamo(entity)
    local entityID = entity:GetEntityID()
    local statusEffectSystem = Game.GetStatusEffectSystem()

    statusEffectSystem:RemoveStatusEffect(entityID, "BaseStatusEffect.OpticalCamoPlayerBuffRare")
    statusEffectSystem:RemoveStatusEffect(entityID, "BaseStatusEffect.OpticalCamoPlayerBuffEpic")
    statusEffectSystem:RemoveStatusEffect(entityID, "BaseStatusEffect.OpticalCamoPlayerBuffLegendary")
end

function isOpticalCamoActive(entity)
    local entityID = entity:GetEntityID()
    local statusEffectSystem = Game.GetStatusEffectSystem()

    return statusEffectSystem:HasStatusEffect(entityID, "BaseStatusEffect.OpticalCamoPlayerBuffRare") or
        statusEffectSystem:HasStatusEffect(entityID, "BaseStatusEffect.OpticalCamoPlayerBuffEpic") or
        statusEffectSystem:HasStatusEffect(entityID, "BaseStatusEffect.OpticalCamoPlayerBuffLegendary")
end

--------------------------------
--- Player
--------------------------------
function registerPlayerStatsModifier(player, statType, modifierType, value)
    local playerID = player:GetEntityID()
    local modifier = Game.CreateStatModifier(statType, modifierType, value)

    if (m_playerStatsModifiers[statType] ~= nil) then
        print_debug("registerPlayerStatsModifier", "removing modifier '"..statType.."'")
        Game.GetStatsSystem():RemoveModifier(playerID, m_playerStatsModifiers[statType])
    end

    if (k_debug) then
        print("[BetterOpticalCamo]", "DEBUG", "registerPlayerStatsModifier():", "adding modifier '"..statType.."': statType=<", statType, ">, modifierType=<", modifierType, ">, value=<", value, ">")
    end

    Game.GetStatsSystem():AddModifier(playerID, modifier)
    m_playerStatsModifiers[statType] = modifier
end

function unregisterPlayerStatsModifier(player)
    local playerID = player:GetEntityID()

    for name, modifier in pairs(m_playerStatsModifiers) do
        print_debug("unregisterPlayerStatsModifier", "removing modifier '"..name.."'")

        Game.GetStatsSystem():RemoveModifier(playerID, modifier)
        m_playerStatsModifiers[name] = nil
    end
end

function setPlayerInvisible(player)
    player:SetInvisible(true)
end

function setPlayerVisible(player)
    player:SetInvisible(false)
end

function makePlayerExitCombat(player)
    local playerID = player:GetEntityID()
    local delaySystem = Game.GetDelaySystem()
    local exitCombatDelay = TweakDB:GetRecord("Items.AdvancedOpticalCamoCommon.exitCombatDelay")
    local hostileTargets = player:GetTargetTrackerComponent():GetHostileThreats(false)

    for _, e in pairs(hostileTargets) do
        local hostileTarget = e.entity

        vanishEvt = NewObject("ExitCombatOnOpticalCamoActivatedEvent")
        vanishEvt.npc = hostileTarget

        m_playerExitCombatDelayIDs[hostileTarget:GetEntityID()] =
            delaySystem:DelayEvent(
                player,
                vanishEvt,
                m_activeSettings.combatCloakDelay,
                true -- isAffectedByTimeDilation
            )

        hostileTarget:GetTargetTrackerComponent():DeactivateThreat(player)
    end
end

function clearDelayedPlayerExitCombatEvents(player)
    local delaySystem = Game.GetDelaySystem()

    for _, delayID in pairs(m_playerExitCombatDelayIDs) do
        print_debug("[PlayerPuppet::OnStatusEffectRemoved]", "cancelling delayed player ExitCombatOnOpticalCamoActivatedEvent")
        delaySystem:CancelDelay(delayID)
    end

    m_playerExitCombatDelayIDs = {}
end

function dumpPlayerStats(player)
    dumpPlayerStat(player, "OpticalCamoCharges")
    dumpPlayerStat(player, "OpticalCamoChargesDecayRate")
    dumpPlayerStat(player, "OpticalCamoChargesDecayRateMult")
    dumpPlayerStat(player, "OpticalCamoChargesDecayStartDelay")
    dumpPlayerStat(player, "OpticalCamoChargesDelayOnChange")
    dumpPlayerStat(player, "OpticalCamoChargesRegenBegins")
    dumpPlayerStat(player, "OpticalCamoChargesRegenEnabled")
    dumpPlayerStat(player, "OpticalCamoChargesRegenEnds")
    dumpPlayerStat(player, "OpticalCamoChargesRegenRate")
    dumpPlayerStat(player, "OpticalCamoDuration")
    dumpPlayerStat(player, "OpticalCamoEmptyStat")
    dumpPlayerStat(player, "OpticalCamoIsActive")
    dumpPlayerStat(player, "OpticalCamoRechargeDuration")
end

function dumpPlayerStat(player, statType)
    local playerID = player:GetEntityID()
    local statsSystem = Game.GetStatsSystem()

    print("[BetterOpticalCamo]", "DEBUG", "dumpPlayerStat():", statType.."=<", statsSystem:GetStatValue(playerID, statType), ">")
end

--------------------------------
--- Events
--------------------------------
function doesEventContainActiveCamoGameplayTag(event)
    local gameplayTags = event.staticData:GameplayTags()

    return table_contains_value(
        gameplayTags,
        ToCName { hash_lo = 0x0035A31B, hash_hi = 0x3E1E789D --[[ ActiveCamo --]] }
    )
end

--------------------------------
--- Settings
--------------------------------
function createSettingsMenu()
    local nativeSettings = GetMod("nativeSettings")
    if (nativeSettings == nil) then
        return
    end

    if not nativeSettings.pathExists("/BetterOpticalCamo") then
        -- nativeSettings.addTab(path, label, optionalClosedCallback)
        nativeSettings.addTab(
            "/BetterOpticalCamo",
            k_i18n["settings.label"],
            function(state)
                local needsReload = willNeedLoadLastCheckpoint()

                applyPendingSettings()
                writeSettingsToFile()

                if (needsReload) then
                    -- Game.GetSettingsSystem():RequestLoadLastCheckpointDialog()
                end
            end
        )
    end

    if nativeSettings.pathExists("/BetterOpticalCamo/Core") then
        nativeSettings.removeSubcategory("/BetterOpticalCamo/Core")
    end

    nativeSettings.addSubcategory(
        "/BetterOpticalCamo/Core",
        k_i18n["settings.subcategory.label"]
    )

    -- nativeSettings.addSwitch(path, label, desc, currentValue, defaultValue, callback, optionalIndex)
    nativeSettings.addSwitch(
        "/BetterOpticalCamo/Core",
        k_i18n["settings.enableToggling.label"],
        k_i18n["settings.enableToggling.description"],
        m_activeSettings.enableToggling,
        k_defaultSettings.enableToggling,
        function(state)
            m_pendingSettings.enableToggling = state
        end)

    -- nativeSettings.addRangeFloat(path, label, desc, min, max, step, format, currentValue, defaultValue, callback, optionalIndex)
    nativeSettings.addRangeFloat(
        "/BetterOpticalCamo/Core",
        k_i18n["settings.opticalCamoChargesDecayRateModifier.label"],
        k_i18n["settings.opticalCamoChargesDecayRateModifier.description"],
        .1,
        10,
        0.1,
        "%.1f",
        m_activeSettings.opticalCamoChargesDecayRateModifier,
        k_defaultSettings.opticalCamoChargesDecayRateModifier,
        function(state)
            m_pendingSettings.opticalCamoChargesDecayRateModifier = state
        end)

    -- nativeSettings.addRangeFloat(path, label, desc, min, max, step, format, currentValue, defaultValue, callback, optionalIndex)
    nativeSettings.addRangeFloat(
        "/BetterOpticalCamo/Core",
        k_i18n["settings.opticalCamoChargesRegenRateModifier.label"],
        k_i18n["settings.opticalCamoChargesRegenRateModifier.description"],
        .1,
        10,
        0.1,
        "%.1f",
        m_activeSettings.opticalCamoChargesRegenRateModifier,
        k_defaultSettings.opticalCamoChargesRegenRateModifier,
        function(state)
            m_pendingSettings.opticalCamoChargesRegenRateModifier = state
        end)

    -- nativeSettings.addSwitch(path, label, desc, currentValue, defaultValue, callback, optionalIndex)
    nativeSettings.addSwitch(
        "/BetterOpticalCamo/Core",
        k_i18n["settings.opticalCamoChargesUseMinimalDecayRate.label"],
        k_i18n["settings.opticalCamoChargesUseMinimalDecayRate.description"],
        m_activeSettings.opticalCamoChargesUseMinimalDecayRate,
        k_defaultSettings.opticalCamoChargesUseMinimalDecayRate,
        function(state)
            m_pendingSettings.opticalCamoChargesUseMinimalDecayRate = state
        end)

    -- nativeSettings.addSwitch(path, label, desc, currentValue, defaultValue, callback, optionalIndex)
    nativeSettings.addSwitch(
        "/BetterOpticalCamo/Core",
        k_i18n["settings.opticalCamoRechargeImmediate.label"],
        k_i18n["settings.opticalCamoRechargeImmediate.description"],
        m_activeSettings.opticalCamoRechargeImmediate,
        k_defaultSettings.opticalCamoRechargeImmediate,
        function(state)
            m_pendingSettings.opticalCamoRechargeImmediate = state
        end)

    -- nativeSettings.addSwitch(path, label, desc, currentValue, defaultValue, callback, optionalIndex)
    nativeSettings.addSwitch(
        "/BetterOpticalCamo/Core",
        k_i18n["settings.combatCloak.label"],
        k_i18n["settings.combatCloak.description"],
        m_activeSettings.combatCloak,
        k_defaultSettings.combatCloak,
        function(state)
            m_pendingSettings.combatCloak = state
        end)

    -- nativeSettings.addRangeFloat(path, label, desc, min, max, step, format, currentValue, defaultValue, callback, optionalIndex)
    nativeSettings.addRangeFloat(
        "/BetterOpticalCamo/Core",
        k_i18n["settings.combatCloakDelay.label"],
        k_i18n["settings.combatCloakDelay.description"],
        0,
        10,
        0.1,
        "%.1f",
        m_activeSettings.combatCloakDelay,
        k_defaultSettings.combatCloakDelay,
        function(state)
            m_pendingSettings.combatCloakDelay = state
        end)

    -- nativeSettings.addSwitch(path, label, desc, currentValue, defaultValue, callback, optionalIndex)
    --nativeSettings.addSwitch(
    --    "/BetterOpticalCamo/Core",
    --    "Deactivate when entering vehicle (Bugged)",
    --    "Automatically deactivate the optical camo when entering a vehicle (Bugged)",
    --    m_activeSettings.deactivateOnVehicleEnter,
    --    k_defaultSettings.deactivateOnVehicleEnter,
    --    function(state)
    --        m_pendingSettings.deactivateOnVehicleEnter = state
    --    end)

    nativeSettings.refresh()
end

function willNeedLoadLastCheckpoint()
    --[[ if (m_activeSettings.opticalCamoDurationIsInfinite ~= m_pendingSettings.opticalCamoDurationIsInfinite) then
        return true
    end
    if (m_activeSettings.opticalCamoDuration ~= m_pendingSettings.opticalCamoDuration) then
        return true
    end ]]--
    return false
end

function applyDefaultSettings()
    for name, value in pairs(k_defaultSettings) do
        m_activeSettings[name] = value
        m_pendingSettings[name] = value
    end
end

function applyPendingSettings()
    for name, value in pairs(m_pendingSettings) do
        m_activeSettings[name] = value
    end

    applySettings(Game.GetPlayer())
end

function loadSettingsFromFile()
    local file = io.open("settings.json", "r")
    if file ~= nil then
        local contents = file:read("*a")
        local validJson, savedSettings = pcall(function() return json.decode(contents) end)

        file:close()

        if validJson then
            for key, value in pairs(savedSettings) do
                if k_defaultSettings[key] ~= nil then
                    m_activeSettings[key] = value
                    m_pendingSettings[key] = value
                end
            end
        end
    end
end

function writeSettingsToFile()
    local validJson, contents = pcall(function() return json.encode(m_activeSettings) end)

    if validJson and contents ~= nil then
        local file = io.open("settings.json", "w+")
        file:write(contents)
        file:close()
    end
end

--------------------------------
--- Localization
--------------------------------
function loadI18nFile(file)
    if (file_exists(file)) then
        local i18nFile = require(file)
        for name, value in pairs(i18nFile) do
            k_i18n[name] = value
        end
    end
end

--------------------------------
--- Utils
--------------------------------
function file_exists(path)
    local f = io.open(path, "r")
    if (f ~= nil) then
        io.close(f)
        return true
    else
        return false
    end
end

function print_trace(caller, text)
    if (k_trace) then
        print("[BetterOpticalCamo]", "TRACE", caller.."():", text)
    end
end

function print_debug(caller, text)
    if (k_debug) then
        print("[BetterOpticalCamo]", "DEBUG", caller.."():", text)
    end
end

function print_info(caller, text)
    if (k_info) then
        print("[BetterOpticalCamo]", "INFO", caller.."():", text)
    end
end

function table_contains_value(table, needle)
    for _, value in pairs(table) do
        if (value == needle) then
            return true
        end
    end

    return false
end
