# Hybrid Flight Controller (C++/ASM) for Quadcopter 🚁

Bare-metal design and programming of a Quadcopter flight controller using a strategic dual-stack software architecture on an ATmega328P microcontroller. 

Unlike standard commercial systems that rely on high-level flight libraries, this project was built from scratch to achieve zero-latency stabilization by manipulating hardware registers directly while keeping complex math in an upper abstraction layer.

## 🧠 Dual-Stack Software Architecture

To meet strict real-time requirements, the algorithm is divided into two languages:

### 1. Low-Level Layer (Assembly)
Operates exclusively on critical hardware interfaces.
* **Precise PWM Generation:** Configures 16-bit Timer 1 and 8-bit Timer 2 to output absolute 1000-2000 µs pulse widths.
* **Interrupt Vectors:** Native handling of UART RX interrupts for the IMU sensor and INT0 (Pin 2) for reading the RC receiver without blocking the main CPU cycle.
* **Zero Overhead:** No generic C libraries are used for hardware communication, ensuring optimal clock-cycle execution.

### 2. High-Level Layer (C++)
Dedicated to logic processing and spatial mathematics.
* **PID Control Loop:** Processes real-time IMU data to calculate structural error in `Roll` and `Pitch`, adjusting them to the established SetPoint.
* **Motor Mixing:** Takes the base throttle signal and dynamically adds or subtracts the PID corrections to distribute independent speed signals to the 4 rotors (Front-Left, Front-Right, Back-Left, Back-Right).

## ⚙️ Hardware Setup (ATmega328P)

* **Motor FL (Front-Left):** Pin 9 (Timer 1 A)
* **Motor FR (Front-Right):** Pin 11 (Timer 2 A)
* **Motor BL (Back-Left):** Pin 10 (Timer 1 B)
* **Motor BR (Back-Right):** Pin 3 (Timer 2 B)
* **RC Receiver:** Pin 2 (INT0)
* **IMU Sensor:** UART (RX/TX)

## 📂 Repository Structure

* `calibracion_motores.ino`: The main C++ logic containing the `setup()` and `loop()`. Handles the IMU offset calibration, PID execution, Motor Mixing, and safety constraints.
* `completo.S`: The core Assembly driver that initializes the Timers' prescalers, Configures Fast PWM (Mode 14), and sets the Interrupt Service Routines (ISR).
* `motor_driver.S` & `sensor.S`: Modularized Assembly vectors for specific motor writes and UART reads.

## 🎯 The Algorithm Cycle
1. **Data Acquisition:** The system reads spatial positioning (Roll/Pitch) disabling interrupts temporarily for a clean, atomic read.
2. **Error Calculation:** Translates mechanical angles into PID error vectors.
3. **Power Distribution:** Merges the User Throttle with the Roll/Pitch errors.
4. **Constraint:** Restricts final values securely between 1000 and 2000.
5. **Hardware Execution:** Writes securely to the hardware Timers (`OCR1A`, `OCR1B`, `OCR2A`, `OCR2B`) via Assembly functions (`write_motors_asm`).

## 📊 System Architecture & Flow Charts

### 1. Dual-Stack Software Architecture
![Hybrid Software Architecture](https://raw.githubusercontent.com/Sebastianwhc/Hybrid-Flight-Controller-C-ASM-/main/fc-architecture.png)

### 2. Motor Mixing (Power Distribution Math)
![Mathematical Power Distribution Calculation](https://raw.githubusercontent.com/Sebastianwhc/Hybrid-Flight-Controller-C-ASM-/main/fc-motor-mixing.png)

### 3. Native Hardware Timer Configuration (16-bit)
![Assembly: 16-bit Hardware Timer Configuration](https://raw.githubusercontent.com/Sebastianwhc/Hybrid-Flight-Controller-C-ASM-/main/fc-timer.png)

### 4. UART Interrupt Vector Logic
![Assembly: UART Interrupt Vector Logic](https://raw.githubusercontent.com/Sebastianwhc/Hybrid-Flight-Controller-C-ASM-/main/fc-uart.png)

---
*If you are interested in Mechatronics, Embedded Systems, or Aerospace Dynamics, feel free to explore the code!*
