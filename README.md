<div align="center">
  <div style="width:200px">
    <a href="https://github.com/northhalf/bf-playground">
      <img src="assets/icon.png" alt="bf_playground" width="200">
    </a>
  </div>

<h1>bf_playground</h1>

![Status](https://img.shields.io/badge/status-active-brightgreen) ![CI](https://github.com/northhalf/bf-playground/actions/workflows/deploy.yml/badge.svg) ![Release](https://img.shields.io/github/v/release/northhalf/bf-playground) ![Downloads](https://img.shields.io/github/downloads/northhalf/bf-playground/total) ![License](https://img.shields.io/badge/license-MIT-blue)

<p align="center">English | <a href="./README_zh.md">中文</a></p>

<h5>A Brainfuck live-preview playground written in Flutter.</h5>

Runs in the browser, and as Windows, macOS and Android packages.

[![GitHub Pages Live Demo](https://img.shields.io/badge/GitHub%20Pages-Live%20Demo-222222?style=for-the-badge&logo=github&logoColor=white)](https://northhalf.github.io/bf-playground/)

</div>

## Demo

<p align="center">
  <img src="assets/demo.webp" alt="Desktop layout: a Hello World program live-previewing on the tape grid" width="800"><br>
  <em>Desktop — a Hello World program mid-run: the current instruction is highlighted in the code box, and the tape grid wraps onto rows while following the pointer.</em>
</p>
<p align="center">
  <img src="assets/demo-mobile.webp" alt="Mobile layout: tape on top, input panel below" width="280"><br>
  <em>Phone — the same session in the vertical layout: tape grid on top, keypad, controls and code box below.</em>
</p>

## Features

- **Live preview** — operators appended at the end of the code box execute instantly with step animation; an unclosed `[` enters a pending state until the matching `]` arrives
- **Calculator-style keypad** for the 8 Brainfuck instructions
- **Code view** — the current instruction is highlighted both in the editor and in the instruction strip below it
- **Tape grid** — cells wrap onto rows joined by connector lines, the view follows the pointer, and cells flash on value changes
- **Preset input / live output** — when input runs out, execution pauses with a hint and resumes after you feed more
- **Playback controls** — step, play/pause, reset, and an adjustable steps-per-second speed

## Run locally

```bash
flutter pub get
flutter run -d web-server   # open the printed URL in any browser
```

## Test & lint

```bash
flutter test
flutter analyze
```

## Tech stack

- Flutter Web (Dart 3)
- [brainfxxk](https://pub.dev/packages/brainfxxk) — the only runtime dependency: parser, `Stepper`, `Tape`
- No state-management or syntax-highlight packages; the UI listens to a single `ChangeNotifier` (`VmController`)
