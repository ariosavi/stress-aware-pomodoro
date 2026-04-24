# Stress-Aware Pomodoro

## Features

- **Glance View**: Quickly see the app content
- **Stress-Aware Breaks**: After each 25-minute focus session, the app reads your average stress level from the last 25 minutes and adjusts your break:
  - **Low stress** (`< 50` or no data): 5-minute break
  - **High stress** (`>= 50`): 10-minute break
  - **Every 4 sessions**: A well-deserved 20-minute long break regardless of stress
- **Pause / Resume**: Press Start/Select during a focus or break countdown to pause and resume.
- **Reset**: Press Back when paused or during a break prompt to return to Ready. Intentionally disabled during active countdowns to prevent accidental resets.
- **Skip Break**: Press Down (Next Page) during break prompt or break to skip directly back to Ready.
- **Session Counter**: Tracks how many focus sessions you've completed in the current run.
- **Vibration Alerts**: Notifies you when a focus session ends and when a break ends.

## App Flow

1. **Ready** — Press Start to begin a 25-minute focus session. Completed sessions count shown.
2. **Focusing** — A live countdown (MM:SS) tracks your focus time. Press Start to pause/resume.
3. **Analyzing** — When focus ends, the app vibrates and reads your average stress score.
4. **Break Prompt** — Displays a recommended break length based on your stress. Shows average stress when available.
5. **Break** — Press Start to begin the countdown. Press Start again to pause/resume, or Down to skip. When it ends, the app vibrates and returns to Ready.

## Controls

| Button | Action |
|--------|--------|
| **Start / Select** | Start focus, start break, pause, or resume |
| **Back** | Reset (only when paused or on break prompt) / Exit app (from Ready screen) |
| **Down / Next Page** | Skip break and return to Ready |

> **Note:** Reset is intentionally only available when the timer is **paused** or during the **break prompt** to prevent accidental resets while the timer is actively running.

## Permissions

- `SensorHistory` — Required to read historical stress data.

