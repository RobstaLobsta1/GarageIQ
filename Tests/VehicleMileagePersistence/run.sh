#!/bin/sh
set -eu
garageiq_repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
garageiq_build_dir="$(mktemp -d "${TMPDIR:-/tmp}/garageiq-persistence-tests.XXXXXX")"
garageiq_sdk="$(xcrun --sdk macosx --show-sdk-path)"
xcrun --sdk macosx swiftc \
    -sdk "$garageiq_sdk" \
    -target "$(uname -m)-apple-macosx14.0" \
    -module-cache-path "$garageiq_build_dir/modules" \
    "$garageiq_repo_root/GarageIQ/ViewModels/MileageForecast.swift" \
    "$garageiq_repo_root/GarageIQ/Models/Vehicle.swift" \
    "$garageiq_repo_root/GarageIQ/Models/MaintenanceRecord.swift" \
    "$garageiq_repo_root/GarageIQ/Models/MaintenanceReminder.swift" \
    "$garageiq_repo_root/GarageIQ/Models/VehicleProposal.swift" \
    "$garageiq_repo_root/GarageIQ/ViewModels/VehicleFormData.swift" \
    "$garageiq_repo_root/Tests/VehicleMileagePersistence/main.swift" \
    -o "$garageiq_build_dir/tests"
"$garageiq_build_dir/tests" "$garageiq_build_dir/garage.store"
