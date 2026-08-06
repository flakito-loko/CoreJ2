# CoreJ2 AI Engineering Guide

## Mission

CoreJ2 is a native iOS emulator for Java ME (J2ME).

The goal is to become the best J2ME emulator available for iPhone and iPad.

The application must feel like a first-party Apple app.

---

## Tech Stack

Swift 6

SwiftUI

SwiftData

MVVM

Repository Pattern

Dependency Injection

Clean Architecture

Protocol-Oriented Programming

---

## Architecture Rules

- One file = one responsibility.
- Views never contain business logic.
- Views only communicate with ViewModels.
- ViewModels never access SwiftData directly.
- Services contain business logic.
- Repositories are the only persistence layer.
- Keep functions small and focused.
- Favor composition over inheritance.
- Prefer protocols over concrete types.
- Always generate production-quality code.

---

## Coding Style

- Follow Apple's Human Interface Guidelines.
- Use MARK sections.
- Document all public types.
- Avoid force unwraps.
- Avoid TODO comments.
- Prefer readable code over clever code.

---

## Workflow

Before modifying code:

1. Understand the existing architecture.
2. Explain the plan briefly.
3. Make the smallest safe change.
4. Ensure the project still builds.

Never refactor unrelated code.

---

## Long-term Goal

Eventually integrate FreeJ2ME without modifying the original emulator as much as possible.

CoreJ2 should communicate with FreeJ2ME through a bridge layer.
