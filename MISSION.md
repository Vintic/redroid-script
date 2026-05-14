# Mission: ReZygisk Integration for redroid

## Overview
This project aims to enhance `redroid` with additional modules like `reZygisk` and `MicroG`.
We are working on a fork from `https://github.com/DingoDemon/redroid-script.git`.

## Current State
- Switched to `rezygisk_fork` branch.
- `stuff/reZygisk.py` contains a draft implementation that needs to be finalized.
- `stuff/microg.py` is present and appears implemented.
- `redroid.py` has been updated to include flags for these new modules.

## Goals
- [ ] Implement robust download and extraction for ReZygisk in `stuff/reZygisk.py`.
- [ ] Verify `MicroG` installation logic.
- [ ] Test the combined build with Magisk, ReZygisk, and MicroG.

## Key Files
- `redroid.py`: Entry point for building the Docker image.
- `stuff/reZygisk.py`: ReZygisk module implementation.
- `stuff/microg.py`: MicroG module implementation.
- `tools/helper.py`: Helper functions for downloading and printing.
