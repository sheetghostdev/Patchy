#!/usr/bin/env bash
# Regenerate procedural scenes: tools/builders/build.sh movement_lab camera_lab ...
cd "$(dirname "$0")/../.."
godot --headless --path . --import >/dev/null 2>&1
exec godot --headless --path . res://tools/builders/run_builder.tscn -- "$@" 2>&1 \
	| grep -vE "ALSA|audio|^\s*$|dummy driver|init_output_device|ERR_CANT_OPEN|AudioManager|_load_manifest|push_warning \(core|audio_manager.gd"
