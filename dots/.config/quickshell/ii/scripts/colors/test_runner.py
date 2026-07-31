import subprocess
import time
import os

url = "https://www.youtube.com/watch?v=X8nI97FLqBM"
sock = "/tmp/ii-musicvideo-test.sock"
frame = "/tmp/ii-videoframe-test.png"

subprocess.run(["pkill", "-f", "mpvpaper"])
time.sleep(0.5)

cmd = ["mpvpaper", "-l", "background", "-o", f"--config=no aid=no loop=inf input-ipc-server={sock}", "HDMI-A-1", url]
proc = subprocess.Popen(cmd)

print("Started mpvpaper, waiting 6 seconds for video playback...")
time.sleep(6)

print("\n=== TEST DE CAPTURA EM TEMPO REAL: Last Escape - Fleshwater ===")
for i in range(1, 6):
    socat_input = f'{{"command":["screenshot-to-file","{frame}","video"]}}\n'.encode('utf-8')
    res_socat = subprocess.run(["socat", "-", f"UNIX-CONNECT:{sock}"], input=socat_input, capture_output=True)
    time.sleep(0.2)
    
    if os.path.exists(frame):
        size = os.path.getsize(frame)
        res_py = subprocess.run(["python3", "/home/pedro/.config/quickshell/ii/scripts/colors/video_frame_color.py", frame], capture_output=True, text=True)
        color = res_py.stdout.strip()
        print(f"Amostra {i} (00:0{i}s): Cor extraída = {color} | Tamanho do frame PNG = {size} bytes")
    else:
        print(f"Amostra {i}: Falha ao gerar screenshot")
    time.sleep(0.8)

proc.terminate()
