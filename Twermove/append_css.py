import os

css_to_append = """
/* Background Vent Phrase Tints */
.vent-phrase.rage-tint {
  color: #ff3300;
  font-family: var(--font-rage);
}
.vent-phrase.envy-tint {
  color: #00e84e;
  font-family: var(--font-envy);
}
.vent-phrase.despair-tint {
  color: #4488ff;
  font-family: var(--font-despair);
}
.vent-phrase.shame-tint {
  color: #dd33ff;
  font-family: var(--font-shame);
}
.vent-phrase.system-tint {
  color: #00bb00;
  font-family: var(--font-system);
}
"""

style_path = r"c:\Users\PREDATOR\OneDrive\Desktop\Twermove\titan_frontend\static\style.css"
with open(style_path, "a", encoding="utf-8") as f:
    f.write(css_to_append)

print("CSS appended.")
