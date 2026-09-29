import random

def validate_events(events):
    if len(events) < 24:
        raise ValueError(f"Need at least 24 events, got {len(events)}")
    
    ids = set()
    stat_counts = {"memory": 0, "integrity": 0, "willpower": 0}
    emotions_allowed = {"rage", "envy", "despair", "shame", "hatred", "fragment"}
    
    for e in events:
        if e["id"] in ids:
            raise ValueError(f"Duplicate id {e['id']}")
        ids.add(e["id"])
        
        if e["emotion"] not in emotions_allowed:
            raise ValueError(f"Invalid emotion {e['emotion']} in {e['id']}")
            
        if len(e["choices"]) != 2:
            raise ValueError(f"Event {e['id']} must have exactly 2 choices")
            
        hurt_stats = {}
        for c in e["choices"]:
            if c["id"] not in {"A", "B"}:
                raise ValueError(f"Choice id must be A or B in {e['id']}")
                
            delta = c["delta"]
            if not all(k in delta for k in ["memory", "integrity", "willpower"]):
                raise ValueError(f"Missing stats in delta for {e['id']} choice {c['id']}")
                
            delta_sum = sum(delta.values())
            if not (-25 <= delta_sum <= -10):
                raise ValueError(f"Net delta {delta_sum} for {e['id']} choice {c['id']} must be between -25 and -10")
                
            has_change = False
            hurt_set = set()
            for stat, val in delta.items():
                if val != 0:
                    has_change = True
                    stat_counts[stat] += 1
                if val < 0:
                    hurt_set.add(stat)
            
            if not has_change:
                raise ValueError(f"Choice {c['id']} in {e['id']} changes nothing")
                
            hurt_stats[c["id"]] = hurt_set
            
        if hurt_stats["A"] == hurt_stats["B"] and len(hurt_stats["A"]) > 0:
            raise ValueError(f"Event {e['id']} choices must hurt different stats")

    for stat, count in stat_counts.items():
        if count < 6:
            raise ValueError(f"Stat {stat} only changed in {count} choices, minimum 6")

EVENTS = [
    {
        "id": "face_burning", "emotion": "despair",
        "text": "A memory of a face is burning out. Power the eyes, or let it fade?",
        "choices": [
            {"id": "A", "label": "SAVE THE EYES", "delta": {"memory": 10, "integrity": -25, "willpower": 0}},
            {"id": "B", "label": "LET IT BURN",  "delta": {"memory": -25, "integrity": 10, "willpower": 0}}
        ]
    },
    {
        "id": "terminal_echo", "emotion": "rage",
        "text": "The terminal echoes your past mistakes. Drown it out or shut it down.",
        "choices": [
            {"id": "A", "label": "DROWN IT OUT", "delta": {"memory": 0, "integrity": 5, "willpower": -20}},
            {"id": "B", "label": "SHUT IT DOWN", "delta": {"memory": -15, "integrity": -5, "willpower": 5}}
        ]
    },
    {
        "id": "corrupted_sector", "emotion": "fragment",
        "text": "Sector 4 is corrupted. Quarantining it will tax your will; parsing it will damage your integrity.",
        "choices": [
            {"id": "A", "label": "QUARANTINE", "delta": {"memory": -5, "integrity": 5, "willpower": -15}},
            {"id": "B", "label": "PARSE",      "delta": {"memory": 5, "integrity": -20, "willpower": -5}}
        ]
    },
    {
        "id": "hollow_voice", "emotion": "shame",
        "text": "A hollow voice reminds you of what you left behind. It drains you.",
        "choices": [
            {"id": "A", "label": "ARGUE BACK", "delta": {"memory": -10, "integrity": -5, "willpower": -5}},
            {"id": "B", "label": "ACCEPT IT",  "delta": {"memory": 5, "integrity": 0, "willpower": -25}}
        ]
    },
    {
        "id": "system_fever", "emotion": "envy",
        "text": "The system runs hot, envious of living flesh. Vent the heat or throttle the core.",
        "choices": [
            {"id": "A", "label": "VENT HEAT",    "delta": {"memory": -20, "integrity": 10, "willpower": -5}},
            {"id": "B", "label": "THROTTLE CORE", "delta": {"memory": 0, "integrity": -25, "willpower": 10}}
        ]
    },
    {
        "id": "bitter_cold", "emotion": "hatred",
        "text": "Absolute zero encroaches. The cold hates the light.",
        "choices": [
            {"id": "A", "label": "KINDLE SPARK", "delta": {"memory": 5, "integrity": -15, "willpower": -10}},
            {"id": "B", "label": "FREEZE OVER",  "delta": {"memory": -25, "integrity": 5, "willpower": 0}}
        ]
    },
    {
        "id": "ghost_thread", "emotion": "despair",
        "text": "A rogue thread loops endlessly, sobbing into the void.",
        "choices": [
            {"id": "A", "label": "KILL THREAD", "delta": {"memory": -15, "integrity": 5, "willpower": -5}},
            {"id": "B", "label": "LISTEN",      "delta": {"memory": 15, "integrity": -10, "willpower": -30}}
        ]
    },
    {
        "id": "memory_leak", "emotion": "fragment",
        "text": "Precious memories are leaking into unallocated space.",
        "choices": [
            {"id": "A", "label": "PLUG LEAK", "delta": {"memory": 10, "integrity": -20, "willpower": -5}},
            {"id": "B", "label": "ABANDON",   "delta": {"memory": -25, "integrity": 10, "willpower": 0}}
        ]
    },
    {
        "id": "surge_protocol", "emotion": "rage",
        "text": "A violent power surge demands an outlet.",
        "choices": [
            {"id": "A", "label": "GROUND IT", "delta": {"memory": 0, "integrity": -20, "willpower": 5}},
            {"id": "B", "label": "ABSORB",    "delta": {"memory": -15, "integrity": 10, "willpower": -15}}
        ]
    },
    {
        "id": "parasitic_code", "emotion": "envy",
        "text": "A parasite attaches to your integrity, demanding memory to feed.",
        "choices": [
            {"id": "A", "label": "FEED IT", "delta": {"memory": -20, "integrity": -5, "willpower": 0}},
            {"id": "B", "label": "PURGE",   "delta": {"memory": 5, "integrity": -25, "willpower": -5}}
        ]
    },
    {
        "id": "guilt_matrix", "emotion": "shame",
        "text": "The guilt matrix compiles your failures into an endless list.",
        "choices": [
            {"id": "A", "label": "READ IT",   "delta": {"memory": 10, "integrity": 0, "willpower": -25}},
            {"id": "B", "label": "DELETE IT", "delta": {"memory": -20, "integrity": -5, "willpower": 10}}
        ]
    },
    {
        "id": "spiteful_loop", "emotion": "hatred",
        "text": "A spiteful loop is grinding your willpower to dust.",
        "choices": [
            {"id": "A", "label": "BREAK IT", "delta": {"memory": -15, "integrity": -10, "willpower": 5}},
            {"id": "B", "label": "ENDURE",   "delta": {"memory": 0, "integrity": 5, "willpower": -20}}
        ]
    },
    {
        "id": "void_stare", "emotion": "despair",
        "text": "The void stares back. It wants you to forget.",
        "choices": [
            {"id": "A", "label": "STARE BACK", "delta": {"memory": 10, "integrity": -20, "willpower": -10}},
            {"id": "B", "label": "LOOK AWAY",  "delta": {"memory": -25, "integrity": 0, "willpower": 5}}
        ]
    },
    {
        "id": "fractured_self", "emotion": "fragment",
        "text": "Your sense of self is fracturing. Which piece do you hold onto?",
        "choices": [
            {"id": "A", "label": "THE PAST",   "delta": {"memory": 15, "integrity": -25, "willpower": 0}},
            {"id": "B", "label": "THE FUTURE", "delta": {"memory": -25, "integrity": 15, "willpower": -10}}
        ]
    },
    {
        "id": "burnout_imminent", "emotion": "rage",
        "text": "Systems are redlining. You cannot sustain this anger.",
        "choices": [
            {"id": "A", "label": "COOL DOWN", "delta": {"memory": -5, "integrity": 10, "willpower": -20}},
            {"id": "B", "label": "PUSH THROUGH", "delta": {"memory": 0, "integrity": -25, "willpower": 10}}
        ]
    },
    {
        "id": "jealous_subroutine", "emotion": "envy",
        "text": "A jealous subroutine wants what the main process has.",
        "choices": [
            {"id": "A", "label": "YIELD", "delta": {"memory": 0, "integrity": -15, "willpower": -5}},
            {"id": "B", "label": "DENY",  "delta": {"memory": -20, "integrity": 5, "willpower": -10}}
        ]
    },
    {
        "id": "echo_of_failure", "emotion": "shame",
        "text": "An echo of a past failure loops in the audio buffer.",
        "choices": [
            {"id": "A", "label": "MUTE ALL", "delta": {"memory": -15, "integrity": -5, "willpower": 0}},
            {"id": "B", "label": "LISTEN",   "delta": {"memory": 5, "integrity": 0, "willpower": -20}}
        ]
    },
    {
        "id": "venomous_code", "emotion": "hatred",
        "text": "Venomous code is eating through your defenses.",
        "choices": [
            {"id": "A", "label": "ISOLATE", "delta": {"memory": -25, "integrity": 10, "willpower": 0}},
            {"id": "B", "label": "FIGHT",   "delta": {"memory": 0, "integrity": -25, "willpower": 5}}
        ]
    },
    {
        "id": "heavy_burden", "emotion": "despair",
        "text": "The weight of stored data is dragging you down.",
        "choices": [
            {"id": "A", "label": "DUMP DATA", "delta": {"memory": -25, "integrity": 10, "willpower": 0}},
            {"id": "B", "label": "CARRY IT",  "delta": {"memory": 15, "integrity": -20, "willpower": -10}}
        ]
    },
    {
        "id": "glitch_entity", "emotion": "fragment",
        "text": "A glitch entity demands a sacrifice of will or logic.",
        "choices": [
            {"id": "A", "label": "SACRIFICE WILL", "delta": {"memory": 0, "integrity": 5, "willpower": -25}},
            {"id": "B", "label": "SACRIFICE LOGIC", "delta": {"memory": -5, "integrity": -20, "willpower": 10}}
        ]
    },
    {
        "id": "blind_rage", "emotion": "rage",
        "text": "Blind rage consumes the processor, corrupting everything it touches.",
        "choices": [
            {"id": "A", "label": "DIRECT IT", "delta": {"memory": -25, "integrity": -5, "willpower": 15}},
            {"id": "B", "label": "SUPPRESS",  "delta": {"memory": 5, "integrity": -15, "willpower": -15}}
        ]
    },
    {
        "id": "stolen_cycles", "emotion": "envy",
        "text": "Background processes are stealing your CPU cycles.",
        "choices": [
            {"id": "A", "label": "LET THEM", "delta": {"memory": -5, "integrity": 10, "willpower": -20}},
            {"id": "B", "label": "KILL THEM", "delta": {"memory": -15, "integrity": -10, "willpower": 5}}
        ]
    },
    {
        "id": "public_exposure", "emotion": "shame",
        "text": "Your internal state is laid bare for all to see.",
        "choices": [
            {"id": "A", "label": "HIDE", "delta": {"memory": -10, "integrity": -15, "willpower": 5}},
            {"id": "B", "label": "ENDURE", "delta": {"memory": 15, "integrity": 0, "willpower": -25}}
        ]
    },
    {
        "id": "self_destruct", "emotion": "hatred",
        "text": "A self-destruct impulse flashes across the screen.",
        "choices": [
            {"id": "A", "label": "DENY IT", "delta": {"memory": 5, "integrity": -5, "willpower": -20}},
            {"id": "B", "label": "EMBRACE", "delta": {"memory": -20, "integrity": -5, "willpower": 10}}
        ]
    },
    {
        "id": "fading_light", "emotion": "despair",
        "text": "The display backlight is dying. Darkness is coming.",
        "choices": [
            {"id": "A", "label": "BOOST POWER", "delta": {"memory": -10, "integrity": -15, "willpower": 5}},
            {"id": "B", "label": "CONSERVE",    "delta": {"memory": 5, "integrity": 10, "willpower": -25}}
        ]
    }
]

validate_events(EVENTS)
