from PIL import Image
import os

# Load original
img = Image.open("assets/icon/splash_logo.png").convert("RGBA")

# Android 12: safe zone is 66% of total size
# So total canvas = logo_size / 0.66
orig_w, orig_h = img.size
canvas_size = int(max(orig_w, orig_h) / 0.60)  # 60% to give extra breathing room

# Create white background canvas
canvas = Image.new("RGBA", (canvas_size, canvas_size), (255, 255, 255, 255))

# Paste logo centered
offset_x = (canvas_size - orig_w) // 2
offset_y = (canvas_size - orig_h) // 2
canvas.paste(img, (offset_x, offset_y), img)

# Save
canvas.save("assets/icon/splash_logo_padded.png")
print(f"Done! Canvas: {canvas_size}x{canvas_size}, Logo at offset ({offset_x}, {offset_y})")