#!/bin/sh

zip -r -o -X -ll Clash_for_Magisk-$(cat module.prop | grep 'version=' | awk -F '=' '{print $2}').zip ./ -x '.git/*' -x 'build.sh' -x '.github/*'