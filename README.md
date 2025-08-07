🧠 Tanuki AI Enhanced DCS Tactical System v4.0
⚡ Adaptive Tactics | 🛡️ Enhanced Defense | 😴 Fatigue System
A complete, self-contained Lua script that transforms DCS AI into reactive, tactical, and realistic combatants — no external dependencies required.

📜 Overview
Tanuki AI v4.0 brings advanced situational awareness, adaptive behaviors, and realistic combat fatigue to AI pilots in DCS World. Designed for both SP and MP missions, this script upgrades standard AI behavior with features usually reserved for human pilots.

🚀 Features
🎯 Tactical Awareness: Dynamic profile switching (e.g., BVR, dogfight, ground attack) based on threat range and aircraft role.

🛡️ Advanced Defensive Systems:

Evasive maneuvers: Beam, notch, corkscrew, etc.

Customizable countermeasure profiles.

ECM battery management (active, passive, depleted).

🔀 Adaptive Engagement:

Adjusts ROE based on threat levels, pilot fatigue, and fuel state.

Handles hesitation, fallback, RTB logic.

👨‍✈️ Pilot Personalization:

Role-based skill assignment (Fighter, CAS, Bomber, SEAD, etc.).

Skill ranges and randomized variance for realism.

🪫 Fuel & ECM State Simulation:
AI will RTB or change tactics when low on fuel or ECM is drained.

📉 Fatigue System:

Tracks time in combat, recovers during lulls.

Impacts radar use, countermeasures, and performance.

🧑‍🤝‍🧑 Wingman Coordination:

Wingman disengage logic.

Formation management and damage response.

🌙 Environmental Awareness:

Night behavior adjustments.

Weapon preference shifts based on visibility.

📡 DCS 2.9 Compatible Event Handler:

Automatically hooks into unit birth, crash, hit, and death.

📂 Installation
Download or clone this repository.

Copy the file Tanuki AI Enhanced DCS Tactical System 4.0.lua into your mission folder or scripting environment.

Add this line to your mission script or init file:

lua
Copy
Edit
dofile("Tanuki AI Enhanced DCS Tactical System 4.0.lua")
Script auto-initializes after 10 seconds, applying to all AI aircraft (BLUE and RED, planes and helicopters).

🧠 How It Works
Every AI aircraft is assigned:

A tactical profile (CAS, SEAD, Interceptor, etc.)

A skill level affecting their combat decisions

A fatigue score, updated dynamically

AI will:

Change tactics in response to nearby threats

Use ECM and countermeasures intelligently

Break formation if wingmen are damaged

RTB on low fuel or critical damage

📈 Example Use Case
Add the script to a PvE mission

Spawn AI dynamically via triggers or scripting

Watch AI pilots fight smart, react to missile threats, and disengage intelligently

✅ Requirements
DCS World 2.9 or later

Works in both SP and MP environments

No external dependencies (MOOSE, Mist, etc. not required)

🛠️ Customization
You can tweak behavior by modifying constants inside the script:

AGGRESSION_LEVELS — ROE and maneuvering

PILOT_SKILLS — Skill ranges per role

FATIGUE_FACTORS — Fatigue rates

TACTICAL_PROFILES — Engagement logic per role

DEFENSIVE_PROFILES — Evasive tactics and countermeasures

📜 License
This script is released under the MIT License. See LICENSE for details.

🙏 Credits
Developed by TanukiInfosec
Special thanks to the Nemesis community for inspiration and testing support.
