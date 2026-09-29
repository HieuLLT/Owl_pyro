import os

file_path = r"c:\Users\PREDATOR\OneDrive\Desktop\Twermove\titan_frontend\static\style.css"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("font-family: var(--font-system);", "font-family: var(--font-angry);")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Font updated.")
