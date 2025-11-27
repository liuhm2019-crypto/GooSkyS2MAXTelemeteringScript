# Goosky S2 MAX Telemetry Widget for Futaba TX15

A comprehensive telemetry display widget designed specifically for the Goosky S2 MAX helicopter when used with the Futaba TX15 transmitter.

## Overview

This Lua script provides real-time telemetry monitoring for your Goosky S2 MAX, displaying critical flight parameters in an easy-to-read format optimized for the TX15's screen. Simply copy to your SD card and activate in App Mode.

## Features

- **Helicopter-Specific Layout**: Tailored display for Goblin S2 MAX parameters
- **Real-Time Telemetry**: Live updates of voltage, RPM, temperature, and signal
- **App Mode Optimization**: Full-screen display without transmitter UI clutter
- **Low Battery Alerts**: Visual and audio warnings (configurable thresholds)
- **RSS Signal Monitoring**: Signal strength bar with loss counter
- **Flight Timer Integration**: Automatic timer start/stop based on throttle

## Requirements

- Futaba TX15 transmitter (or compatible T15 series)
- OpenTX 2.3.x or EdgeTX 2.8+ firmware installed
- Goosky S2 MAX with compatible telemetry receiver (e.g., R3008SB, R7108SB)
- Telemetry link established (RF module and receiver bound)
- MicroSD card (formatted FAT32)

## Installation

1. **Copy the Script**  
   Create a folder named `DBK_S2Max` inside the `WIDGETS` directory and place the script inside:
   WIDGETS/DBK_S2Max/GooskyS2MAX.lua

2. **SD Card Structure**  
Ensure your SD card has this structure:
TX15/
├── WIDGETS/
│   └── DBK_S2Max/
│       └── main.lua
│       └── Feiji.png
│       └── hold1.png
│       └── hold2.png
│       └── title.jpg
├── SOUNDS/
├── MODELS/
└── IMAGES/

3. **Safety Checks**  
- Verify telemetry is working (check in Model Settings → Telemetry)
- Test voltage sensor is receiving data
- Confirm throttle stick activates the timer

## Setup Instructions

### Step 1: Add the Widget
1. Long-press the **MDL** button
2. Navigate to **DISPLAY** menu
3. Select an empty screen or replace existing one
4. Choose **App Mode** (critical for full-screen display)
5. Press **ENTER** and select `DBK_S2Max` from the widget list
