# Realistic Candle Flicker Effect for Home Assistant

This documentation provides a comprehensive guide for implementing a realistic candle flicker effect in Home Assistant. The system allows you to create a dynamic, randomized flame-like effect on RGB color lights that mimics the natural flickering of candles with warm, amber tones and subtle brightness variations.

## Table of Contents

1. [System Overview](#system-overview)
2. [Features](#features)
3. [Installation](#installation)
4. [Configuration Files](#configuration-files)
5. [How It Works](#how-it-works)
6. [Usage](#usage)
7. [Troubleshooting](#troubleshooting)
8. [External Control via API](#external-control-via-api)
9. [Customization](#customization)

## System Overview

The Realistic Candle Flicker Effect system uses a combination of:

- Scripts to control the flicker effect
- Input booleans to manage state
- Automations to handle manual overrides
- Dynamic templates to allow for device-specific control

The architecture follows a modular design that allows independent control of multiple lights while providing global override capabilities.

### Architecture Diagram

```
┌───────────────────────┐      ┌─────────────────────────┐
│ endless_flicker_effect │─────▶│ device_flicker_active   │
│ (Main Script)          │      │ (Per-device Booleans)   │
└───────────────────────┘      └─────────────────────────┘
           │                                 │
           │                                 │
           ▼                                 ▼
┌───────────────────────┐      ┌─────────────────────────┐
│ flicker_script_global  │      │ RGB Lights              │
│ (Global Control)       │      │ (Hardware)              │
└───────────────────────┘      └─────────────────────────┘
           ▲                                 ▲
           │                                 │
┌───────────────────────┐      ┌─────────────────────────┐
│ Stop/Override         │─────▶│ Manual Light Control     │
│ Automations           │      │ Detection                │
└───────────────────────┘      └─────────────────────────┘
```

## Features

- **Realistic flame simulation** with randomized colors, brightness, and timing
- **Independent control** of multiple lights
- **Parallel operation** to run flicker effects on multiple devices simultaneously
- **Manual override detection** to stop flicker when lights are controlled elsewhere
- **Global control** to easily start/stop all flicker effects
- **Customizable parameters** for colors, brightness range, transition time and delay
- **External control** via API for integration with other systems

## Installation

### Prerequisites

- Home Assistant (tested on version 2023.6 or newer)
- RGB-capable smart lights (Philips Hue, LIFX, etc.)
- Basic understanding of YAML configuration

### File Placement

1. Place script definitions in one of these locations:
   - In a dedicated file included via `!include` in your scripts section
   - Directly in your `scripts.yaml` file
   - In a `light_effects.yaml` file if you use split configuration

2. Add input boolean configuration to your `configuration.yaml`

3. Add automations to your `automations.yaml` file

### Setup Process

1. **Add the scripts** to your Home Assistant configuration
2. **Configure input booleans** for global control and per-device tracking
3. **Add the automations** for handling manual overrides
4. **Restart Home Assistant** to apply the configuration
5. **Verify installation** by starting the flicker effect on a light

## Configuration Files

### light_effects.yaml

```yaml
endless_flicker_effect:
  alias: Realistic Candle Flicker Effect
  fields:
    entity_id:
      description: "The light entity to flicker"
  sequence:
    - service: input_boolean.turn_on
      target:
        entity_id: input_boolean.flicker_script_global_active
    - service: input_boolean.turn_on
      target:
        entity_id: >
          {% set ib = 'input_boolean.' + entity_id.split('.')[1] + '_flicker_active' %}
          {{ ib }}
    - repeat:
        while:
          - condition: and
            conditions:
              - condition: state
                entity_id: input_boolean.flicker_script_global_active
                state: "on"
              - condition: template
                value_template: >
                  {% set ib = 'input_boolean.' + entity_id.split('.')[1] + '_flicker_active' %}
                  {{ is_state(ib, 'on') }}
        sequence:
          - variables:
              brightness_val: "{{ range(20, 255)|random }}"
              red_val: "{{ range(200, 255)|random }}"
              green_val: "{{ range(50, 220)|random }}"
              blue_val: "{{ range(0, 80)|random }}"
              transition_val: "{{ (range(1, 3)|random / 10)|round(1) }}"
              delay_val: "{{ range(300, 600)|random }}"
          - service: light.turn_on
            target:
              entity_id: "{{ entity_id }}"
            data:
              brightness: "{{ brightness_val }}"
              rgb_color: "{{ [red_val, green_val, blue_val] }}"
              transition: "{{ transition_val }}"
          - delay:
              milliseconds: "{{ delay_val }}"
    - service: input_boolean.turn_off
      target:
        entity_id: input_boolean.flicker_script_global_active
  mode: parallel
  max: 20

turn_off_flicker_globally:
  alias: "Turn Off Flicker Globally"
  sequence:
    - service: input_boolean.turn_off
      target:
        entity_id: input_boolean.flicker_script_global_active
```

### configuration.yaml (Input Booleans)

```yaml
input_boolean:  
  flicker_script_global_active:
    name: Global Flicker Script Active
    initial: off

  glass_lamp_flicker_active:
    name: Glass Lamp Flicker
    initial: off
  wall_light_flicker_active:
    name: Wall Light Flicker
    initial: off
  desk_lamp_light_flicker_active:
    name: Desk Light Flicker
    initial: off
```

### automations.yaml

```yaml
- alias: "Stop Flicker on Manual Change"
  trigger:
    - platform: state
      entity_id: light.glass_lamp
    - platform: state
      entity_id: light.wall_light
    - platform: state
      entity_id: light.desk_lamp_light
  condition:
    - condition: template
      value_template: >
        {% set light_name = trigger.entity_id.split('.')[1] %}
        {% set ib = 'input_boolean.' + light_name + '_flicker_active' %}
        {{ is_state(ib, 'on') }}
    - condition: template
      value_template: "{{ trigger.context.user_id is not none or trigger.context.parent_id is none }}"
  action:
    - service: input_boolean.turn_off
      target:
        entity_id: >
          {% set light_name = trigger.entity_id.split('.')[1] %}
          input_boolean.{{ light_name }}_flicker_active
    - service: input_boolean.turn_off
      target:
        entity_id: input_boolean.flicker_script_global_active

- alias: "Force Light Control Priority"
  trigger:
    - platform: state
      entity_id: light.all_lights
  condition:
    - condition: template
      value_template: "{{ is_state('input_boolean.light_override_mode', 'on') }}"
    - condition: state
      entity_id: input_boolean.flicker_script_global_active
      state: "off"
  action:
    - service: input_boolean.turn_off
      target:
        entity_id: >
          {% set light_name = trigger.entity_id.split('.')[1] %}
          input_boolean.{{ light_name }}_flicker_active
    - delay: 0.5
    - service: light.turn_on
      target:
        entity_id: "{{ trigger.entity_id }}"
      data: "{{ trigger.to_state.attributes }}"

- alias: "Stop Flicker When Light Turned OFF"
  trigger:
    - platform: state
      entity_id: light.glass_lamp
      to: "off"
    - platform: state
      entity_id: light.wall_light
    - platform: state
      entity_id: light.desk_lamp_light
      to: "off"
  action:
    - service: input_boolean.turn_off
      target:
        entity_id: >
          {% set light_name = trigger.entity_id.split('.')[1] %}
          input_boolean.{{ light_name }}_flicker_active
    - service: input_boolean.turn_off
      target:
        entity_id: input_boolean.flicker_script_global_active

- alias: "Detect Manual Light Control"
  trigger:
    - platform: state
      entity_id: light.glass_lamp
    - platform: state
      entity_id: light.wall_light
    - platform: state
      entity_id: light.desk_lamp_light
  condition:
    - condition: template
      value_template: "{{ trigger.context.user_id is not none }}"
  action:
    - service: input_boolean.turn_off
      target:
        entity_id: input_boolean.flicker_script_global_active
    - service: input_boolean.turn_off
      target:
        entity_id: >
          {% set light_name = trigger.entity_id.split('.')[1] %}
          input_boolean.{{ light_name }}_flicker_active
```

## How It Works

### Core Components

1. **Main Flicker Script (`endless_flicker_effect`)**
   - Accepts a light entity as input
   - Controls transition speed, color, and brightness variations
   - Uses variables to generate random values for realistic flickering
   - Respects global and per-device control booleans

2. **Control Booleans**
   - `flicker_script_global_active`: Master switch for all flicker effects
   - Device-specific booleans (e.g., `glass_lamp_flicker_active`): Control individual lights

3. **Override Automations**
   - Detect manual changes to lights
   - Stop flicker effect when a light is turned off
   - Handle priority controls for other automations

### Flicker Logic

The flicker effect works by:

1. Enabling control booleans for the specified light
2. Creating a continuous loop that:
   - Generates random values for brightness (20-255)
   - Selects random warm colors (red: 200-255, green: 50-220, blue: 0-80)
   - Sets random transition time (0.1-0.3 seconds)
   - Waits random delay between changes (300-600ms)
3. Continues until either boolean is turned off
4. Disables the global boolean when complete

### Override System

The system detects and handles overrides through:

1. **Manual UI Control**: Detected through `trigger.context.user_id is not none`
2. **Physical Switches**: Detected when parent_id is none
3. **Light Turned Off**: Special handling for off state
4. **Priority Mode**: Optional override using `light_override_mode`

## Usage

### Starting the Flicker Effect

To start the flicker effect on a specific light:

1. **Through the Home Assistant UI**:
   - Go to Developer Tools > Services
   - Select the `script.endless_flicker_effect` service
   - Enter the following as Service Data:
     ```yaml
     entity_id: light.your_light
     ```
   - Click "Call Service"

2. **Via Dashboard Button**:
   Add a button to your dashboard with this configuration:
   ```yaml
   type: button
   name: Start Candle Flicker
   tap_action:
     action: call-service
     service: script.endless_flicker_effect
     data:
       entity_id: light.your_light
   ```

### Stopping the Flicker Effect

To stop the flicker effect:

1. **Turn off the light**: The simplest way to stop the effect on a specific light
2. **Use the global off script**: Call `script.turn_off_flicker_globally` to stop all flicker effects
3. **Manually toggle off**: Turn off any of the input booleans in the UI
4. **Make any manual change**: Any manual control of the light will stop the flicker

### Controlling Multiple Lights

The system supports running the flicker effect on multiple lights simultaneously. To do this:

1. Ensure you have a corresponding `input_boolean.[light_name]_flicker_active` for each light
2. Add each light to the trigger sections of the automations
3. Call the script for each light to start the effect

## Troubleshooting

### Common Issues and Solutions

#### Flicker Effect Doesn't Start

**Symptoms**: 
- No visible flickering after calling the script
- Input booleans don't turn on

**Possible Causes & Solutions**:
1. **Incorrect entity_id format**:
   - Ensure the entity_id matches exactly (e.g., `light.glass_lamp`, not `glass_lamp`)
   - Check for typos or case sensitivity issues

2. **Missing input_boolean**:
   - Verify that you have created the corresponding input_boolean for the light
   - The naming must follow the pattern: `input_boolean.[light_name]_flicker_active`

3. **Script errors**:
   - Check Home Assistant logs for template errors
   - Verify all components are correctly loaded after restart

#### Flicker Stops After One Cycle

**Symptoms**:
- Light changes once then stops
- Input booleans remain ON but no flickering

**Possible Causes & Solutions**:
1. **Race condition with automations**:
   - The "Detect Manual Light Control" automation may be treating script-induced changes as manual changes
   - Check that condition templates correctly check user_id and parent_id

2. **Light compatibility issues**:
   - Some lights have rate limiting that prevents rapid changes
   - Try increasing delay_val to 1000-1500ms for slower flicker

#### Input Booleans Stay On After Turning Off Light

**Symptoms**:
- Light turns off but input_booleans remain on
- Cannot restart the flicker effect

**Possible Causes & Solutions**:
1. **"Stop Flicker When Light Turned OFF" automation issue**:
   - Verify the automation triggers for the correct light entities
   - Check if the to: "off" condition is properly configured

2. **Trigger missed**:
   - Try a direct API call to turn off the booleans (see External Control section)
   - Check Home Assistant logs for automation trace errors

### Debugging Tips

1. **Monitor Boolean States**:
   - Go to Developer Tools > States
   - Filter for "input_boolean"
   - Watch the states as you trigger the script

2. **Check Automation Traces**:
   - Go to Developer Tools > Events
   - Look for automation execution traces
   - Verify triggers are firing as expected

3. **Test Basic Light Control**:
   - Try simple on/off/color commands directly to verify light responsiveness
   - Rule out hardware/connectivity issues

4. **Simplify for Testing**:
   - Temporarily remove the dynamic template parts
   - Use a fixed count instead of while loop to test script execution

## External Control via API

### Using curl Commands

You can control the flicker effect via the Home Assistant REST API using curl:

1. **Starting the flicker effect**:
   ```bash
   curl --http1.1 \
     -H "Authorization: Bearer YOUR_LONG_LIVED_ACCESS_TOKEN" \
     -H "Content-Type: application/json" \
     -X POST \
     -d '{"entity_id": "light.glass_lamp"}' \
     http://your-home-assistant-url:8123/api/services/script/endless_flicker_effect
   ```

2. **Stopping all flicker effects**:
   ```bash
   curl --http1.1 \
     -H "Authorization: Bearer YOUR_LONG_LIVED_ACCESS_TOKEN" \
     -H "Content-Type: application/json" \
     -X POST \
     http://your-home-assistant-url:8123/api/services/script/turn_off_flicker_globally
   ```

### Windows Batch Files (.bat)

Create batch files for easy triggering from Windows:

1. **start_glass_lamp_flicker.bat**:
   ```batch
   @echo off
   curl --http1.1 ^
        -H "Authorization: Bearer YOUR_LONG_LIVED_ACCESS_TOKEN" ^
        -H "Content-Type: application/json" ^
        -X POST ^
        -d "{\"entity_id\": \"light.glass_lamp\"}" ^
        http://your-home-assistant-url:8123/api/services/script/endless_flicker_effect
   pause
   ```

2. **stop_all_flicker.bat**:
   ```batch
   @echo off
   curl --http1.1 ^
        -H "Authorization: Bearer YOUR_LONG_LIVED_ACCESS_TOKEN" ^
        -H "Content-Type: application/json" ^
        -X POST ^
        http://your-home-assistant-url:8123/api/services/script/turn_off_flicker_globally
   pause
   ```

### Obtaining a Long-Lived Access Token

1. In Home Assistant, click on your user profile (bottom left)
2. Scroll down to "Long-Lived Access Tokens"
3. Click "Create Token"
4. Give it a name (e.g., "Flicker Control")
5. Copy the token immediately (it will only be shown once)

## Customization

### Adjusting Flicker Parameters

To customize the flicker effect, modify these parameters in the script:

1. **Color Range**:
   ```yaml
   red_val: "{{ range(200, 255)|random }}"     # Higher min = redder flame
   green_val: "{{ range(50, 220)|random }}"    # Higher max = yellower flame
   blue_val: "{{ range(0, 80)|random }}"       # Higher max = bluer flame
   ```

2. **Brightness Range**:
   ```yaml
   brightness_val: "{{ range(20, 255)|random }}" # Adjust for dimmer/brighter flames
   ```

3. **Speed and Dynamics**:
   ```yaml
   transition_val: "{{ (range(1, 3)|random / 10)|round(1) }}" # Controls how quickly colors blend
   delay_val: "{{ range(300, 600)|random }}"                  # Time between changes
   ```

### Adding More Lights

To add support for another light:

1. **Add input_boolean**: 
   ```yaml
   new_light_flicker_active:
     name: New Light Flicker
     initial: off
   ```

2. **Add triggers to automations**:
   ```yaml
   - platform: state
     entity_id: light.new_light
   ```

3. **Verify naming convention**: Ensure light entity ID, input boolean, and naming patterns match

### Advanced Configurations

#### Creating a Group for All Flicker Lights

Add this to your `configuration.yaml`:

```yaml
light:
  - platform: group
    name: all_flicker_lights
    entities:
      - light.glass_lamp
      - light.wall_light
      - light.desk_lamp_light
```

#### Dashboard Card for Flicker Control

Add this to your dashboard:

```yaml
type: entities
title: Candle Flicker Controls
entities:
  - input_boolean.flicker_script_global_active
  - input_boolean.glass_lamp_flicker_active
  - input_boolean.wall_light_flicker_active
  - input_boolean.desk_lamp_light_flicker_active
  - type: button
    name: Start Glass Lamp Flicker
    tap_action:
      action: call-service
      service: script.endless_flicker_effect
      data:
        entity_id: light.glass_lamp
  - type: button
    name: Stop All Flicker
    tap_action:
      action: call-service
      service: script.turn_off_flicker_globally
```

---

## About This Project

This Realistic Candle Flicker Effect was developed to create a dynamic, natural-looking flame effect for smart RGB lights in Home Assistant. The system provides independent control of multiple lights while maintaining synchronization through global controls and automations.

For issues, suggestions, or customization help, refer to the troubleshooting section or the Home Assistant community forums.

