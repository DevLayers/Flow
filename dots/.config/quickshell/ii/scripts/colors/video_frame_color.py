import sys
from PIL import Image

def get_dominant_color(img_path):
    try:
        img = Image.open(img_path).convert('RGB')
        img = img.resize((16, 16), Image.Resampling.BOX)
        # Quantize to 3 main colors to avoid selecting pure black/shadow borders
        quantized = img.quantize(colors=3)
        palette = quantized.getpalette()
        for i in range(0, 9, 3):
            r, g, b = palette[i], palette[i+1], palette[i+2]
            # Pick first non-pure-black color if available
            if r > 15 or g > 15 or b > 15:
                return f"#{r:02X}{g:02X}{b:02X}"
        return f"#{palette[0]:02X}{palette[1]:02X}{palette[2]:02X}"
    except Exception as e:
        return "#000000"

if __name__ == "__main__":
    if len(sys.argv) > 1:
        print(get_dominant_color(sys.argv[1]))
    else:
        print("#000000")
