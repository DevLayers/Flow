#!/usr/bin/env bash

if [[ -z "$1" ]]; then
    echo "Usage: $0 <target_locale> [model]"
    exit 1
fi

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SHELL_CONFIG_DIR="$XDG_CONFIG_HOME/illogical-impulse"
SHELL_CONFIG_FILE="${SHELL_CONFIG_DIR}/config.json"
TRANSLATIONS_DIR="${SCRIPT_DIR}/../../translations"
TRANSLATIONS_TARGET_DIR="${TRANSLATIONS_DIR}"
SOURCE_LOCALE="en_US"
NOTIFICATION_APP_NAME="Shell"
TARGET_LOCALE="$1"
MODEL="${2:-${GEMINI_MODEL:-gemini-2.5-flash}}"

# Update the source keys for translation
"${TRANSLATIONS_DIR}/tools/manage-translations.sh" update -l "$SOURCE_LOCALE" --yes
mkdir -p "$TRANSLATIONS_TARGET_DIR"

# Construct instruction
instruction='You are to translate the user interface of a **desktop shell**. Given a JSON object of key-value pairs, return a JSON with the same structure, with keys unchanged and values translated to '"$TARGET_LOCALE"'. Be as **concise** as possible to save screen space, and make sure terminology is relevant (e.g. "discharging" refers to the battery status).'

# Prepare request payload file to prevent shell argument limits
PAYLOAD_FILE=$(mktemp)
trap 'rm -f "$PAYLOAD_FILE"' EXIT

jq -n \
    --arg prompt_text "$instruction" \
    --rawfile content "${TRANSLATIONS_DIR}/en_US.json" \
    --arg temperature "0" \
    '{
        contents: [{
            parts: [
                {text: ($prompt_text + "\n```json\n" + $content + "\n```\n")}
            ]
        }],
        generationConfig: {
            temperature: ($temperature | tonumber),
            "responseMimeType": "application/json"
        }
    }' > "$PAYLOAD_FILE"

# Get API key
API_KEY=$(secret-tool lookup 'application' 'illogical-impulse' | jq -r '.apiKeys.gemini')

# Notify start
notify-send "Translation started" "Translating missing keys in batches, you'll be notified when complete." -a "$NOTIFICATION_APP_NAME"

# Perform batch translation for missing keys
python3 "${SCRIPT_DIR}/gemini-translate-batch.py" \
    "${TRANSLATIONS_DIR}/en_US.json" \
    "${TRANSLATIONS_TARGET_DIR}/${TARGET_LOCALE}.json" \
    "$TARGET_LOCALE" \
    --model "$MODEL" \
    --batch-size 300

jq --arg locale "$TARGET_LOCALE" '.language.ui = $locale' "$SHELL_CONFIG_FILE" > "${SHELL_CONFIG_FILE}.tmp" && mv "${SHELL_CONFIG_FILE}.tmp" "$SHELL_CONFIG_FILE"
notify-send "Translation complete" "Enjoy! In case you wanna refine it, the file is in ${TRANSLATIONS_TARGET_DIR}/${TARGET_LOCALE}.json" -a "$NOTIFICATION_APP_NAME"
