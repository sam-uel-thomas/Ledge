# Ledge 🟦

Ledge is a minimalist, high-performance macOS utility that provides a "temporary shelf" for your files. Inspired by apps like Dropover, Ledge lets you summon a floating landing pad with a quick shake of your mouse, allowing you to stash files during complex drag-and-drop operations.

## ✨ Features

- **Shake-to-Summon**: Hold left-click and shake your mouse rapidly to bring up the Ledge.
- **Springy UI**: A smooth, native-feeling interface with 0.3s fade-in/out animations.
- **Draggable**: Use the subtle handle at the top of the tile to move it anywhere on your screen.
- **Appearance Settings**: Toggle between Light, Dark, and System appearance modes via the Menu Bar.
- **Smart Dismissal**: The Ledge automatically stays visible while you're dragging a file out, then fades away gracefully.
- **Safe Interaction**: Won't re-summon or jump around if it's already visible.

## 🚀 Installation

### 1. Download the App
Clone this repository or download the latest release:
```bash
git clone https://github.com/sam-uel-thomas/Ledge.git
```

### 2. Run Ledge
Open `Ledge.app` from the project folder. You may need to:
1. **Right-click > Open** the first time to bypass macOS's gatekeeper.
2. Grant **Accessibility Permissions** in *System Settings > Privacy & Security > Accessibility* for your terminal or the app itself so it can detect mouse shakes.

## 🛠 Compilation (Manual)

If you'd like to build the project yourself from the source:

```bash
swiftc Ledge.swift -o Ledge -framework SwiftUI -framework AppKit -framework UniformTypeIdentifiers
```

## ⚙️ Settings

Ledge lives in your **Menu Bar**. Click the Ledge icon (stacked squares) to:
- Open **Settings** (Change appearance, view logo).
- Manually **Show Ledge** for testing.
- **Quit** the application.

## 🎨 Design

Ledge uses a premium, low-contrast color palette:
- **Light Mode**: `#F0EDE5` background with `#312F2C` text.
- **Dark Mode**: `#312F2C` background with `#F0EDE5` text.

---
Built with Swift and SwiftUI.
