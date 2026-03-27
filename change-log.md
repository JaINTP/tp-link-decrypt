# Change Log

## [Unreleased]
### Added
- Multi-distribution package resolution in `preinstall.sh` (`apt`, `pacman`, `dnf`, `zypper`).
- Automatic `uv` dependency management for python packages inside `preinstall.sh`, replacing `pip3 install --break-system-packages`. Added concurrent `unblob` tool installation.
- Dual-extractor logic in `extract_keys.sh` combining `unblob` as the primary extractor, with logical fallback to `binwalk` if target RSA assets aren't found.
- Export of `~/.local/bin` in `extract_keys.sh` to correctly hook Python libraries populated by `uv tool`.

### Changed
- Shifted dependency execution from `lsb_release`-driven conditionals matching 'ubuntu'/'kali' to dynamic `command -v` detection.
