# nixantic-standalone

## Context
Extract the reusable Nixantic instruction system from `../appdots` into this standalone repository. The target is a Home-Manager-independent `lib.evalModules` core module that can be used on its own, while still exposing a thin Home Manager adapter for consumers that want HM integration. The repository scope includes both the reusable framework and AP's Claude/OpenCode instruction corpus.

## Checkpoint
Project folder and initial documentation skeleton created. No implementation planning or code changes have been recorded in this project doc yet.

Next expected step is to run planning against this project so requirements, tasks, acceptance criteria, and file-level scope can be expanded in the phase doc.

## Requirements
* R1: ⬜ Provide a standalone Nixantic core module that is compatible with `lib.evalModules` and usable outside Home Manager (Phase: foundation)
* R2: ⬜ Expose a Home Manager module that consumes the core module outputs instead of owning the core behavior directly (Phase: foundation)
* R3: ⬜ Move the Claude/OpenCode instruction framework and AP corpus out of `../appdots` into this repository while keeping them usable through the standalone module surface (Phase: foundation)

## Phases
### 🔄 01 Phase: foundation
[01-foundation](01-foundation.md)
Bootstrap the standalone project definition, architecture framing, and future planning surface for the extraction. This phase is the landing area for the detailed plan, task breakdown, acceptance criteria, and early investigation notes.

## Files
- (none yet)
