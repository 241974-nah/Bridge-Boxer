# Bridge Boxer (Pygame vs. x86 MASM Assembly)

<img width="1920" height="1040" alt="BridgeBomber-Pygame" src="https://github.com/user-attachments/assets/b2f2f671-c6b5-4171-b485-2de0f98bd782" />

<img width="1920" height="1040" alt="BridgeBomber-Assembly" src="https://github.com/user-attachments/assets/75fb0784-1076-48fd-8374-1329850f6851" />



## Project Overview
Bridge Boxer is an arcade game developed across two entirely different programming paradigms for university coursework in Intro to AI and Computer Organization & Assembly Language (COAL). The project challenges high-level architectural state design against low-level hardware register constraints. 

The game loop requires the player to move across a bridge, collect supply boxes, and time their drops downward to hit moving target vehicles while avoiding pedestrians.

---

## Architectural Comparison

### 1. High-Level Architecture (Python / Pygame)
* **Framework:** Pygame Engine via Object-Oriented Python.
* **State Management:** Uses distinct agent classes (`IntelligentCar` and `SentryInterceptor`) featuring runtime states like `CRUISE`, `LOCK-ON`, and `EVADE: BRAKE`.
* **AI Systems:** Implements a reactive decision-tree logic and predictive heuristics where cars dynamically adjust their acceleration (`base_speed * 2.2`) based on real-time physics projection vectors and proximity lookaheads.

### 2. Low-Level Architecture (x86 Assembly)
* **Compiler/Toolchain:** MASM + Irvine32 library via Visual Studio.
* **Memory Architecture:** Eliminates abstractions. The entire 20x60 game board is treated as a flat 1D byte array (`grid BYTE 1200 DUP(' ')`).
* **Offset Math Engine:** Cell access is handled via manual register scaling:
  $$\text{Memory Offset} = (\text{Row Index} \times \text{NCOLS}) + \text{Column Index}$$
* **Timing & Game Loop:** Employs non-blocking asynchronous timing gates via manual delta updates (`GetMseconds`) to regulate independent traffic speeds, clock tracking, and custom bit modification algorithms for handling multi-case keyboard mapping.

---

## Technical Highlights (Assembly Build)
* **Array Memory Tracking:** Uses custom procedures (`GSet` / `GGet`) using the `IMUL` instruction across the `EBX` and `ESI` registers to manipulate map cells without multi-dimensional structures.
* **Conveyor Shifting Register:** Shifting lanes left or right (`ScrollRow`) is performed via pointer increments/decrements inside isolated stack boundaries using `PUSHAD` and `POPAD` to safeguard register accuracy during system interrupt calls.
* **Collision Matrix Filter:** Real-time physics calculations use explicit register sorting checking for ASCII identifiers (`'C'`, `'o'`, `'X'`, `'B'`) to execute branch conditions and signed integer math tracking (`SDWORD`).
