// Better Optical Camo (Redscript compatibility module for "Custom Quickslots")
// Copyright (c) 2022 Lukas Berger
// MIT License (See LICENSE.md)
@if(ModuleExists("CustomQuickslotsConfig"))
import CustomQuickslotsConfig.*

@if(ModuleExists("CustomQuickslotsConfig"))
@addMethod(HotkeyItemController)
public func IsOpticalCamoCyberwareAbility() -> Bool {
    switch this.m_customQuickslotProperties.itemType {
        case CustomQuickslotItemType.OpticalCamo:
            return true;
        default:
            return false;
    }
}
