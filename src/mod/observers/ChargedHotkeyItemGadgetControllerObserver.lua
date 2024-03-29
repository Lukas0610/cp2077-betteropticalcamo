-- Better Optical Camo
-- Copyright (c) 2022-2023 Lukas Berger
-- MIT License (See LICENSE.md)
local ChargedHotkeyItemGadgetControllerObserver = {}
local LOGTAG = "ChargedHotkeyItemGadgetControllerObserver"

local m_rootWidget = nil

function observeOnInitialize(this)
    m_rootWidget = this:GetRootWidget()
end

function observeOnUninitialize(this)
    m_rootWidget = nil
end

function observeResolveState(this)
    m_rootWidget = this:GetRootWidget()

    local opticalCamoManager = GetOpticalCamoManager()
    local player = Game.GetPlayer()

    if ((player ~= nil) and (shouldOverrideRootWidgetState(player))) then
        if (this:IsCyberwareActive()) then
            if (opticalCamoManager:IsOpticalCamoActive(player)) then
                m_rootWidget:SetState("ActiveInterruptible")
            end
        else
            local opticalCamoCharges = opticalCamoManager:GetOpticalCamoCharges(player)

            if (opticalCamoCharges > 0) then
                m_rootWidget:SetState("Default")
            end
        end
    end
end

function shouldOverrideRootWidgetState(player)
    local opticalCamoManager = GetOpticalCamoManager()
    return (opticalCamoManager:GetSettingsManager():GetValue("enableToggling")) and
        (opticalCamoManager:HasOpticalCamoEquipped(player))
end

ChargedHotkeyItemGadgetControllerObserver.Initialize =
    function()
        ObserveAfter("ChargedHotkeyItemGadgetController", "OnInitialize", observeOnInitialize)
        ObserveBefore("ChargedHotkeyItemGadgetController", "OnUninitialize", observeOnUninitialize)
        ObserveAfter("ChargedHotkeyItemGadgetController", "ResolveState", observeResolveState)
    end

ChargedHotkeyItemGadgetControllerObserver.Update =
    function()
        if (m_rootWidget ~= nil) then
            local opticalCamoManager = GetOpticalCamoManager()
            local player = Game.GetPlayer()

            if ((player ~= nil) and (shouldOverrideRootWidgetState(player))) then
                local opticalCamoCharges = opticalCamoManager:GetOpticalCamoCharges(player)

                if (opticalCamoCharges < 0.01) then
                    m_rootWidget:SetState("Unavailable")
                else
                    m_rootWidget:SetState("Default")
                end
            end
        end
    end

return ChargedHotkeyItemGadgetControllerObserver
