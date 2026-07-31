#!/bin/bash
# music_video_sync.sh <socket_path>
SOCKET="$1"

if [ -z "$SOCKET" ]; then
    echo "Usage: $0 <ipc_socket_path>"
    exit 1
fi

# 1. Wait for IPC socket file to exist (up to 15s)
for i in $(seq 1 150); do
    [ -S "$SOCKET" ] && break
    sleep 0.1
done

if [ ! -S "$SOCKET" ]; then
    echo "[MusicVideoSync] Socket $SOCKET not found"
    exit 1
fi

# 2. Wait for mpv "file-loaded" event (indicating video stream is initialized)
timeout 25 socat - UNIX-CONNECT:"$SOCKET" 2>/dev/null | \
while IFS= read -r line; do
    if echo "$line" | grep -q '"event":"file-loaded"'; then
        break
    fi
done

# Short delay to ensure mpv decoder playback loop is settled
sleep 0.2

# 3. Get exact current player position from playerctl
POS=$(playerctl position 2>/dev/null | cut -d. -f1)
if [ -z "$POS" ] || ! [[ "$POS" =~ ^[0-9]+$ ]]; then
    POS=0
fi

# 4. Perform absolute seek to actual music position
echo '{"command":["seek","'"$POS"'","absolute"]}' | \
    socat - UNIX-CONNECT:"$SOCKET" 2>/dev/null

echo "[MusicVideoSync] Synced mpv video to ${POS}s"
