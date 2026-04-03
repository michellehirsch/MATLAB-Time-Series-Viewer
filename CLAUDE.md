# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A MATLAB GUI application for interactive exploration of time series data (originally designed for flight test data). Works with 1-D vectors (1xN or Nx1) from the MATLAB workspace. Published on MATLAB File Exchange.

## Running

Launch from MATLAB command window:
```matlab
timeseriesviewer
```
No build step. No test suite exists.

## Architecture

**GUIDE-based GUI**: The main app uses MATLAB's legacy GUIDE framework. `timeseriesviewer.m` contains all GUI logic and `timeseriesviewer.fig` stores the figure layout. The `.fig` file is binary — edit it only through GUIDE (`guide timeseriesviewer`).

**`timeseriesviewer.m` structure**: Uses `gui_mainfcn` for GUIDE initialization. All callbacks are subfunctions within the single file (~1600 lines). State is shared via `handles` struct and `appdata` on the figure. Supports 1–4 subplot axes configurations with drag-and-drop variable assignment.

**`@dragndrop/` class (old-style)**: Implements drag-and-drop using MATLAB's pre-classdef OOP (`class()` constructor in `dragndrop.m`). Properties: `DragHandles`, `DropHandles`, `DropCallbacks`, `DropValidDrag`. State stored as `appdata` on the parent figure. Property order matters when calling `set()` — define handles before callbacks.

**Key supporting functions**:
- `dddrag.m` — executes the drag operation; determines drop target via `undermouse()` and fires the appropriate `DropCallback`
- `linkedzoom.m` — linked zoom across multiple subplots (x-only, y-only, xy, or hybrid modes). Uses `appdata` on `ZLabel` to store axis limits
- `datalabel.m` — interactive click-to-label data points on lines. State-machine driven via string callbacks (`'down'`, `'move'`, `'up'`)
- `eventlabel.m` — interactive event annotation on plots with edit/delete context menus. Events stored in `appdata` as a struct array
- `dragtext.m` — makes text objects draggable via `dragrect`

**`private/` directory**: Helper utilities scoped to the main directory — `assignHere.m` (assign to caller workspace), `fixname.m`, `str2names.m`, `linkedzoom.m`, string trimming functions, and asset files (icons, help HTML).

## Key Patterns

- State management uses `setappdata`/`getappdata` on figure and axes handles throughout
- Callbacks are frequently specified as string expressions (e.g., `'datalabel down'`) rather than function handles — this is legacy style
- The GUI reads workspace variables via `evalin('base',...)` and assigns back with `assignin`/`assignHere`
- Many functions use `gco`/`gcf`/`gca` for context — these are fragile if multiple figures are open
