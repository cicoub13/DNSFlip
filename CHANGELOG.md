# Changelog

All notable changes to DNSFlip will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.1.0] - 2026-05-15

### Added
- DNS connectivity probe (UDP/53) in the profile editor — each server field shows a real-time reachability indicator (spinner → green check / red warning) before applying
- Warning shown when a DNS server is unreachable, with option to apply anyway
- Start at Login option in Settings
- French and English localization
- Onboarding illustration (App → Helper → DNS) visible in the Helper tab until the helper is installed
- Unit and UI tests

### Fixed
- Sparkle update URL fallback when the primary URL is unavailable
- Error alert in Settings when a helper operation fails

### Security
- Various security hardening fixes

## [1.0.0] - 2026-05-14

### Added
- Menu bar app to switch DNS server profiles instantly
- Profile-based DNS management (add, edit, delete, reorder)
- Root LaunchDaemon helper for privileged DNS changes via SCPreferences
- Secure XPC communication between app and helper
- Network service selection (automatic or manual interface)
- Helper management UI (install, uninstall, status)
- Persistent profiles stored in UserDefaults
