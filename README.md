# Pomodoro Sense

A productivity app for Garmin smartwatches that combines the Pomodoro technique with real-time physiological monitoring. The app tracks your stress levels, body battery (energy), and heart rate during focus sessions, then automatically recommends optimal break lengths based on your complete physiological state.

The app displays your current stress, body battery, and heart rate during every session. When a focus period ends, it analyzes your average stress and heart rate, and shows how your body battery changed. Based on this data, it intelligently recommends a short, long, or extra-long break to help you recover optimally.

## Features

- Pomodoro clock
- Stress-aware break recommendations
- Stress Monitoring
- Body Battery Tracking
- Heart Rate Monitoring
- Progress bar during countdowns

## How It Works

1. **Ready** — Press Start to begin a focus session
2. **Focusing** — Live countdown tracks your focus time
3. **Analyzing** — App reads your stress level, body battry and heart rate after focus ends
4. **Break Prompt** — Recommends break length based on stress
5. **Break** — Countdown for your recovery time

## Settings

Configure in Garmin Connect app and also in the app:

- Focus Duration
- Short Break
- Long Break
- Extra Long Break
- Sessions Before Long Break
- Stress Threshold
- Vibration
- Sound Alerts
- DisplaySeconds

## Permissions

- `SensorHistory` — Reads historical stress data, body battery, and heart rate from the watch
- `Sensor` — Access to real-time physiological sensor data

## Build & Run for development

**Prerequisites:**
- Garmin Connect IQ SDK (lin-9.1.0+)
- Java with `-Dfile.encoding=UTF-8`
- Garmin developer key

**Compile for simulator:**
```bash
java -Xms1g \
  -Dfile.encoding=UTF-8 \
  -Dapple.awt.UIElement=true \
  -jar ~/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.1.0-2026-03-09-6a872a80b/bin/monkeybrains.jar \
  -o bin/StressAwarePomodoro.prg \
  -f ./monkey.jungle \
  -y ./Garmin/key/developer_key \
  -d venu3_sim \
  -w
```

The compiled `.prg` file is written to `bin/StressAwarePomodoro.prg`.
