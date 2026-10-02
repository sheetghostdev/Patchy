#!/usr/bin/env bash
# Render a scene to PNG on a headless server using a virtual display.
#   tools/photo/shoot.sh scene=res://tests/scenes/movement_test.tscn out=/tmp/a.png frames=40
cd "$(dirname "$0")/../.."
exec xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan --fixed-fps 60 \
	res://tools/photo/photo.tscn -- "$@" 2>&1 | grep -vE "ALSA|audio|^\s*$|dummy driver|init_output_device|ERR_CANT_OPEN"
