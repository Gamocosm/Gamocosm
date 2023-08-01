#!/usr/bin/env bash

set -e

cd "$(dirname "$0")"
cd ..

# Colour from app/assets/stylesheets/variables.scss

convert -density 1200 -background none -fill '#59ae44' -colorize '100%' -resize 32x32 -repage 32x32+0+1 -flatten app/assets/images/logo.svg app/assets/images/favicon.ico
