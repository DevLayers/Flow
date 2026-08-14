# Touchscreen Gestures Helper (`touch_gestures`)

Helper passivo para observação e reconhecimento de gestos em telas touchscreen no `ii-p3drovfx`.

## Visão Geral

- **Backend:** `evdev` (Linux input subsystem)
- **Modo:** Observador passivo (não realiza `grab` do dispositivo, permitindo que as aplicações continuem recebendo eventos de touch normalmente)
- **Dispositivos suportados:** Telas touchscreen físicas (`INPUT_PROP_DIRECT` + `BTN_TOUCH`)
- **Dispositivos ignorados:** Touchpads, mouses, teclados e emuladores virtuais (`ydotool`, `uinput`, etc.)
- **Protocolo:** JSON Lines (JSONL) via `stdout`

## Build & Instalação

```bash
cd ~/.config/quickshell/ii/scripts/touchGestures/touch_gestures_src
cargo build --release
cp target/release/touch_gestures ../touch_gestures
chmod +x ../touch_gestures
```

## Permissões

O binário precisa de permissão de leitura para `/dev/input/event*` (normalmente pertencente ao grupo `input`).
Se o seu usuário não tiver acesso, adicione-o ao grupo `input`:

```bash
sudo usermod -aG input $USER
```

E reinicie a sessão.

## Protocolo JSONL


Eventos emitidos pelo helper:

- `ready`: `{"type":"ready","version":1}`
- `device_added`: `{"type":"device_added","deviceId":"...","name":"...","path":"/dev/input/eventX"}`
- `device_removed`: `{"type":"device_removed","deviceId":"..."}`
- `touch_down`: `{"type":"touch_down","deviceId":"...","contactId":0,"x":0.05,"y":0.5,"time":12345678}`
- `touch_move`: `{"type":"touch_move","deviceId":"...","contactId":0,"x":0.2,"y":0.5,"time":12345679}`
- `touch_up`: `{"type":"touch_up","deviceId":"...","contactId":0,"x":0.35,"y":0.5,"time":12345680}`
- `status`: `{"type":"status","code":"no_touchscreen"}`
- `error`: `{"type":"error","code":"permission_denied","message":"..."}`
