import os

file_path = r"c:\Users\PREDATOR\OneDrive\Desktop\Twermove\titan_frontend\static\style.css"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Switch emotion-envy to use font-angry
content = content.replace("font-family: var(--font-envy); color: #00e84e;", "font-family: var(--font-angry); color: #00e84e;")

# Switch vent-phrase.envy-tint to use font-angry
envy_orig = """.vent-phrase.envy-tint {
  color: #00e84e;
  font-family: var(--font-envy);
}"""
envy_new = """.vent-phrase.envy-tint {
  color: #00e84e;
  font-family: var(--font-angry);
}"""
content = content.replace(envy_orig, envy_new)

# Switch vent-phrase.system-tint to grey color and font-system
system_orig = """.vent-phrase.system-tint {
  color: #00bb00;
  font-family: var(--font-angry);
}"""
system_new = """.vent-phrase.system-tint {
  color: #888888;
  font-family: var(--font-system);
}"""
content = content.replace(system_orig, system_new)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Styles updated.")
