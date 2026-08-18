# This script is meant to be sourced.
# It's not for directly running.

# shellcheck shell=bash

try rm "${FIRSTRUN_FILE}"
try rm "${XDG_STATE_HOME:-$HOME/.local/state}/illogical-impulse/user/first_run.txt"
