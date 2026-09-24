#!/bin/sh
# Allow local X11 connections. Runs once per XQuartz start, sourced by
# /opt/X11/etc/X11/xinit/xinitrc.d/98-user.sh (must be executable).
xhost +localhost >/dev/null 2>&1
