extern "C" {
  void init_motors();
  // Orden Assembly: (Pin9, Pin10, Pin3, Pin11)
  void write_motors_asm(int pin9, int pin10, int pin3, int pin11);
  void uart_init();
  extern volatile int16_t raw_roll;  
  extern volatile int16_t raw_pitch;
}

// Prototipos
void calibrarSensor();

// Variables
int16_t offset_roll = 0;
int16_t offset_pitch = 0;
int throttle = 1000;

void setup() {
  // DEBUG: Usar el LED del Arduino para ver si recibe señal
  pinMode(13, OUTPUT); 
  digitalWrite(13, LOW);

  uart_init();
  init_motors(); 

  // Armado: Señal mínima a todos
  write_motors_asm(1000, 1000, 1000, 1000);
  
  // Parpadeo rápido del LED para indicar que estamos en SETUP
  for(int i=0; i<5; i++) { digitalWrite(13, HIGH); delay(100); digitalWrite(13, LOW); delay(100); }

  delay(2000); // Esperar armado ESC
  
  calibrarSensor();
  
  // LED encendido fijo 1 segundo indica: "CALIBRACIÓN OK"
  digitalWrite(13, HIGH); delay(1000); digitalWrite(13, LOW);
}

void loop() {
  // 1. LEER MANDO
  long puls = pulseIn(2, HIGH, 30000);
  
  if (puls < 1000) throttle = 1000;
  else if (puls > 2000) throttle = 2000;
  else throttle = (int)puls;

  // --- DIAGNÓSTICO VISUAL ---
  // Si aceleras (pasas de 1100), el LED se enciende.
  // Si no se enciende, el Arduino no está leyendo tu mando.
  if (throttle > 1100) digitalWrite(13, HIGH);
  else digitalWrite(13, LOW);

  // 2. LEER SENSOR
  int16_t r, p;
  noInterrupts();
  r = raw_roll;
  p = raw_pitch;
  interrupts();

  // 3. PID
  int roll_pid = (r - offset_roll) / 16;
  int pitch_pid = (p - offset_pitch) / 16;

  // 4. MEZCLA (Configuración física: 9=FL, 10=BL, 3=BR, 11=FR)
  int v_FL, v_FR, v_BL, v_BR;

  if (throttle < 1100) {
    v_FL = 1000; v_FR = 1000; v_BL = 1000; v_BR = 1000;
  } else {
    v_FL = throttle + pitch_pid + roll_pid;
    v_FR = throttle + pitch_pid - roll_pid;
    v_BL = throttle - pitch_pid + roll_pid;
    v_BR = throttle - pitch_pid - roll_pid;
  }

  // Restricciones
  v_FL = constrain(v_FL, 1000, 2000);
  v_FR = constrain(v_FR, 1000, 2000);
  v_BL = constrain(v_BL, 1000, 2000);
  v_BR = constrain(v_BR, 1000, 2000);

  // 5. ENVIAR A ASSEMBLY
  // Orden esperado por write_motors_asm: Pin9(FL), Pin10(BL), Pin3(BR), Pin11(FR)
  write_motors_asm(v_FL, v_BL, v_BR, v_FR);
}

void calibrarSensor() {
  long sum_roll = 0;
  long sum_pitch = 0;
  int muestras = 50;
  for (int i = 0; i < muestras; i++) {
    noInterrupts();
    int16_t r = raw_roll;
    int16_t p = raw_pitch;
    interrupts();
    sum_roll += r;
    sum_pitch += p;
    delay(10);
  }
  offset_roll = sum_roll / muestras;
  offset_pitch = sum_pitch / muestras;
}