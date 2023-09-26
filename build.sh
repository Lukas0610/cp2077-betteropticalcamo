#!/bin/bash
# Better Optical Camo
# Copyright (c) 2022 Lukas Berger
# MIT License (See LICENSE.md)
set -e

rm -vfr build/
mkdir -pv build/

rm -vf BetterOpticalCamo.zip

# create directory structure
mkdir -pv "build/"
mkdir -pv "build/Core Mod/bin/x64/plugins/cyber_engine_tweaks/mods/BetterOpticalCamo/"
mkdir -pv "build/Compatibility Addons/"
mkdir -pv "build/Compatibility Addons/Custom Quickslots/r6/scripts/BetterOpticalCamo/compat/"

# copy files
cp -v {CHANGELOG,LICENSE,README}.md "build/"
cp -rv mod/* "build/Core Mod/bin/x64/plugins/cyber_engine_tweaks/mods/BetterOpticalCamo/"
cp -rv compat/custom_quickslots/redscript/* "build/Compatibility Addons/Custom Quickslots/r6/scripts/BetterOpticalCamo/compat"

# remove runtime files
rm -vf \
    "build/Core Mod/bin/x64/plugins/cyber_engine_tweaks/mods/BetterOpticalCamo/BetterOpticalCamo.log" \
    "build/Core Mod/bin/x64/plugins/cyber_engine_tweaks/mods/BetterOpticalCamo/db.sqlite3" \
    "build/Core Mod/bin/x64/plugins/cyber_engine_tweaks/mods/BetterOpticalCamo/settings.json"

# create final artifact
cd build/
zip -v -r9 ../BetterOpticalCamo.zip .
cd ..

# cleanup
rm -vfr build/
