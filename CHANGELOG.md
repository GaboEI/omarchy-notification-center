# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-27

### Added

- A bell in the bar with an unread count that reads correctly at any number,
  including `99+`.
- A notification history panel that opens under the bell and follows it when it
  is moved along the bar.
- Per-row removal, mark all read, close all, and clear history.
- Row activation: run a saved notification action, focus the app that sent it,
  open its website, or launch a verified desktop app.
- Right-click Do Not Disturb with a red crossed bell, kept in sync with
  Omarchy's own setting.
- Spanish and English interface, following the desktop language.

### Notes

- Clearing the panel hides entries from the panel only. Omarchy keeps its own
  notification history and exposes no way to erase it.
- A notification that has expired cannot reopen the exact chat or browser tab;
  the plugin focuses or launches the app instead and says so when it cannot.
