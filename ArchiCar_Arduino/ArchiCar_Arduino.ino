/*
 * ArchiCar_Arduino Steuersoftware
 * 
 * - Steuert das ArchiCar, misst die Distanzen zu den Wänden
 * und Sendet Informationen an Processing Client - Software.
 *
 * AUTHOR: Lorenz Kromer
 * MATRNR: mt131044
 * FACH: IAI Semester-Projekt SS 2015 @ FH St. Pölten
 *
 * KONTAKT: mt131044@fhstp.ac.at
*/

// --- BIBLIOTHEKEN --- //

/*
 * Das in dieser Installation verwendete Bluetooth-Modul (Typ HC-05) ist leider nicht mit den OnBoard Arduino-RX/TX-Pins kompatibel.
 * Zur lösung des Problems wird die SoftwareSerial Library genutzt. Kurz erklärt: mehrere andere Digital-Pins können als Serial Tranceiver/Receiver (TX/RX) verwendet werden.
 * Mehr Informationen zu diesem "Problem" finden Sie hier: http://www.instructables.com/id/Arduino-AND-Bluetooth-HC-05-Connecting-easily/
*/
#include <SoftwareSerial.h>
#include <Servo.h> 

// --- Objektinstanzen --- //

// Ein SoftwareSerial-Object wird instanziert und hört bzw. sendet auf den Ports 10 und 11. Über dieses Object verläuft im Weitern die Bluetooth Kommunikation.
SoftwareSerial BTConn(11, 10); // TX, RX
Servo servoLeft, servoRight;

// --- VARIABLEN --- //

// Der Datenstrom aus BTConn in Bytes übertragen und per .read()-Funktion in einen Integerwert umgewandelt und in BTData gespeichert.
int BTData;

// Der Datenstring, der Übertragen wird. 2 Doppelpunkte :: trennen die Werte voneinander. Processing weiß, die diese Nachricht zu interpretieren ist.
String msg;

/* Message-Daten des Fahrzeugs
 *
 * servoSpeedLeft: Wert zw. 0-255, Speed des Servos
 * servoSpeedRight: Wert zw. 0-255, Speed des Servos
 * distanceFront: Abstand des Autos nach vorne
 * distanceRight: Abstand des Autos nach rechts
 * directionMode: Gibt dem Processingclient Auskunft, in welche Richtung im Koordinatensystem sich das Auto bewegt.
 *
*/
int servoSpeedLeft = 2, servoSpeedRight = 3, distanceFront = 0, distanceRight = 0, directionMode = 0;

// Fahrbereich des Autos (in cm!). Unter- oder Ueberschreitet das Auto einen dieser Border, wird 
// dementsprechend gehandelt.
int areaFrontborder = 9, areaUpperborder = 8, areaLowerborder = 7;

// Long-Variablen zur Kalkulation der Distanzen vom Auto zur Wand od. Obstacles.
long duration, duration_middle, duration_right;

// Pinout der beiden Ultraschall Sensoren. Trigger = Ausloeser. Echo = Echo-Empfaenger
int trigPin_middle = 3;
int echoPin_middle = 5;
int trigPin_right = 6;
int echoPin_right = 9;

// Der autoMode u. obstacleMode entscheidet, ob das Auto alleine faehrt oder nicht.
boolean autoMode = false, obstacleMode = false;

// Ein Wert, 0 oder 1, der dem Processing Client sagt, ob das Auto faehrt oder nicht.
int drivingForward = 0;

void setup() {
  // Beginne auf BTConn nach einkommenden Signalen zu "hoeren"
  BTConn.begin(38400);
  
  // Signal-LED Pinout u. Aktivierung
  pinMode(13, OUTPUT);
  
  // Aktivierung und Setzung der Sensor-Pins
  pinMode(trigPin_middle, OUTPUT); // Trigger = "sender"
  pinMode(echoPin_middle, INPUT); // Echo = "reveicer"
  
  // same hier...
  pinMode(trigPin_right, OUTPUT);
  pinMode(echoPin_right, INPUT);
}

void loop() {
  // Berechnung der aktuellen Distanzen von den jeweiligen Sensoren aus.
  distanceFront = getDistance(trigPin_middle, echoPin_middle);
  distanceRight = getDistance(trigPin_right, echoPin_right);
  
  // Leeren des msg-Strings, der nachher via BTConn versendet wird.
  msg = "";

  // Sobald Daten via BTConn verfuegbar sind -> auslesen
  if (BTConn.available()){
    // Setze Signal-LED -> Daten wurden empfangen.
    digitalWrite(13, HIGH);
    
    // Der Datenstrom aus BTConn in Bytes übertragen und per .read()-Funktion in einen Integerwert umgewandelt und in BTData gespeichert.
    BTData = BTConn.read();

    /* Der Processing Client sendet "Codes" 
     * die fuer die versch. Funktionen des Autos stehen:
     * 
     * 1....Lade Fahrzeuginfos (Laufzeit, Distanzen und Speed)
     * 2....Setze Servos bereit
     * 3....Schalte Servos und alle Modi ab
     * 4....Fahre vorwaerts
     * 5....Kurve links fahren
     * 6....Kurve rechts fahren
     * 7....turnLeftInPosition
     * 8....turnRightInPosition
     * 9....aktiviere ManualMode
     * 10....aktiviere AutoMode
     * 11....anhalten
     * 12....Fahre rueckwaerts
    */
    if(BTData==1){
      sendMessage();
    }
    else if(BTData==2){
      setServosUp();
    }
    else if(BTData==3){
      setServosDown();
      autoMode = false;
      obstacleMode = false;
    }
    else if(BTData==4){
      driveForward();
    }
    else if(BTData==5){
      curveLeft();
    }
    else if(BTData==6){
      curveRight();
    }
    else if(BTData==7){
      turnLeftInPosition();
    }
    else if(BTData==8){
      turnRightInPosition();
    }
    else if(BTData==9){
      // Deaktiviere den automatischen Modus. Fahrzeug bleibt stehen.
      autoMode = false;
    }
    else if(BTData==10){
      autoMode = true;
      // Aktiviere den automatischen Modus. Fahrzeug faehrt selbststaendig los.
    }
    else if(BTData==11){
      breaking();
    }
    else if(BTData==12){
      driveBackward();
    }
    else if(BTData==13){
      obstacleMode = true;
    }
    else{
      breaking();
    }
  }
  
  // obstacleMode = der Modus, indem das Auto alleine Faehrt und dabei Gegenständen ausweicht, die sich in den Weg stellen.
  if(obstacleMode){
    // Solange der Front-Sensor nicht ausschlaegt, wird das Fahrzeug geradeaus fahren.
    // Ist die Distanz nach Vorne kleiner als 15cm, weicht das Auto dem Obstacle nach links aus.
    // so faehrt das Auto ein "changeDirectionLeft"-Manoever.
    if(distanceFront < 15){
      changeDirectionLeft();
    }
    // Muss das Auto nicht ausweichen, faehrt es geradeaus.
    else{
        driveForward();
    }
  }
  
  // autoMode = der Modus, indem das Auto alleine Faehrt und die zurueckgelegte Straecke
  // im Client nachzeichnet.
  // Das Auto sollte im Raum in der "rechten unteren Ecke" abgestellt werden!!!
  // Dabei sollte ein Abstand von mindestens 5 cm zur Wand (also RECHTS!) eingehalten werden.
  if(autoMode){
    // Solange der Front-Sensor nicht ausschlaegt, wird das Fahrzeug geradeaus fahren.
    // Ist die Distanz nach Vorne kleiner als der definierte Border,
    // so faehrt das Auto ein "changeDirectionLeft"-Manoever.
    if(distanceFront < areaFrontborder){
      changeDirectionLeft();
    }
    // Das waere eine Rechtskurve, die funktioniert leider nicht so gut.
    // Ist die Distanz nach rechts aprupt ueber 30cm, so wird ein 
    // "changeDirectionLeft"-Manoever eingeleitet.
    else if(distanceRight > 30){
        //changeDirectionRight();
    }
    else{
      // Das Auto faehrt automatisch mit einer Geschwindigkeit von 10cm/s geradeaus.
      driveForward();
      // Korrekturmodi des Fahrzeugs
      // Ist der Abstand zur rechten Wand zu groß, so korrigiert das Fahrzeug die Spur,
      // indem es eine Rechtskurve faehrt.
      if(distanceRight > areaUpperborder){
        curveRight();
      }
      // Ist der Abstand zur rechten Wand zu gering, so korrigiert das Fahrzeug die Spur,
      // indem es eine Linksskurve faehrt.
      else if(distanceRight < areaLowerborder){
        curveLeft();
      }
    }
  }
  
  // Dieses Delay "sollte" helfen, den BTConn-Buffer wieder zu loeschen.
  // Das funktioniert allerdings nur mangelhaft. Niedrigere Delay-Raten sorgen fuer
  // mehr Data-Trash bei der Bluetooth Uebertragung. 100ms = okay!
  delay(100);
  //BTConn.flush();

  // Signal-LED wieder "AUS" setzen -> fancy blinking ;)
  digitalWrite(13, LOW);
}

// "changeDirectionLeft"-Manoever: Fahrzeug weicht einem Obstacle nach links aus.
void changeDirectionLeft(){
  // Auto dreht sich im Stand nach links.
  turnLeftInPosition();
  
  // Speichere Richtungsaenderung, Processing muss nun XY-Variablen vertauschen.
  directionMode++;  
  
  // Informiert Processing, dass das Auto steht, und sich nicht vorwaerts bewegt.
  drivingForward = 0;

  // Wartezeit, damit sich das auto fuer 1,6 Sekunden dreht (entspricht ca 90 Grad-Drehung)
  delay(1600);
}

// "changeDirectionRight"-Manoever: Fahrzeug weicht einem Obstacle nach rechts aus. Nicht ausgereift...
void changeDirectionRight(){
  delay(1600);
  turnRightInPosition();
  directionMode--;
      drivingForward = 0;
  delay(1000);
  driveForward();
  delay(500);
  breaking();
  delay(2000);
}

// Setzt die Drehgeschwindigkeit der beiden Servos
void setServosSpeed(int servoSpeedLeft, int servoSpeedRight){
  servoLeft.write(servoSpeedLeft);
  servoRight.write(servoSpeedRight);
}

// Aktivierung beider Sensoren mit Ausrichtung im "Stillstand" - Modus -> 90
void setServosUp(){
  // Servos werden an Pins gebunden.
  servoRight.attach(2);
  servoLeft.attach(4);
  
  // Value 90: Stillstand der Servos
  servoSpeedLeft = 90;
  servoSpeedRight = 90;
  
  // Informiert Processing, dass das Auto steht, und sich nicht vorwaerts bewegt.
  drivingForward = 0;

  servoLeft.write(servoSpeedLeft);
  servoRight.write(servoSpeedRight);

  // Geschwindigkeit setzen...
  setServosSpeed(servoSpeedLeft, servoSpeedRight);
}

// Abschalten der Servos
void setServosDown(){
  servoLeft.detach();
  servoRight.detach();
  
  // Informiert Processing, dass das Auto steht, und sich nicht vorwaerts bewegt.
  drivingForward = 0;
}

// Brems-Modus. Beide Servos stehen still.
void breaking(){
  // Value 90: Stillstand der Servos
  servoSpeedLeft = 90;
  servoSpeedRight = 90;
  
  // Informiert Processing, dass das Auto steht, und sich nicht vorwaerts bewegt.
  drivingForward = 0;

  // Geschwindigkeit setzen...
  setServosSpeed(servoSpeedLeft, servoSpeedRight);
}

// Auto faehrt vorwaerts.
void driveForward(){
  // Beide Servos drehen Vorwaerts. Unterschiedliche Werte, da sie in unterschiedlicher Richtung
  // am Fahrzeug befestigt sind.
  servoSpeedLeft = 50;
  servoSpeedRight = 130;
  
  // Informiert Processing, dass das Auto in bewegung nach vorne ist.
  drivingForward = 1;

  // Geschwindigkeit setzen...
  setServosSpeed(servoSpeedLeft, servoSpeedRight);
}

// Auto faehrt vorwaerts.
void driveBackward(){
  // Beide Servos drehen Rueckwaerts. Unterschiedliche Werte, da sie in unterschiedlicher Richtung
  // am Fahrzeug befestigt sind.
  servoSpeedLeft = 130;
  servoSpeedRight = 50;
  
  // Informiert Processing, dass das Auto steht, und sich nicht vorwaerts bewegt.
  drivingForward = 0;

  // Geschwindigkeit setzen...
  setServosSpeed(servoSpeedLeft, servoSpeedRight);
}

// Auto faehrt Kurve bzw. "Bogen" nach links.
void curveLeft() {
  // Beide Servos drehen Vorwaerts, aber mit unterschiedlicher Leistung. -> Linkskurve
  // Unterschiedliche Werte, da sie in unterschiedlicher Richtung
  // am Fahrzeug befestigt sind.
  servoSpeedLeft = 80;
  servoSpeedRight = 140;

  // Informiert Processing, dass das Auto in bewegung nach vorne ist.
  drivingForward = 1;

  // Geschwindigkeit setzen...
  setServosSpeed(servoSpeedLeft, servoSpeedRight);
}

// Auto faehrt Kurve bzw. "Bogen" nach rechts.
void curveRight() {
  // Beide Servos drehen Vorwaerts, aber mit unterschiedlicher Leistung. -> Rechtskurve
  // Unterschiedliche Werte, da sie in unterschiedlicher Richtung
  // am Fahrzeug befestigt sind.
  servoSpeedLeft = 50;
  servoSpeedRight = 110;

  // Informiert Processing, dass das Auto in bewegung nach vorne ist.
  drivingForward = 1;

  // Geschwindigkeit setzen...
  setServosSpeed(servoSpeedLeft, servoSpeedRight);
}

// Auto dreht sich im Stand nach links.
void turnLeftInPosition(){
  // Servos drehen in gleiche Richtung. -> Fahrzeug dreht im Stand
  // Gleiche Werte, da sie in unterschiedlicher Richtung
  // am Fahrzeug befestigt sind.
  servoSpeedLeft = 110;
  servoSpeedRight = 110;
  
  // Informiert Processing, dass das Auto steht, und sich nicht vorwaerts bewegt.
  drivingForward = 0;

  // Geschwindigkeit setzen...
  setServosSpeed(servoSpeedLeft, servoSpeedRight);
}

// Auto dreht sich im Stand nach rechts.
void turnRightInPosition(){
  // Servos drehen in gleiche Richtung. -> Fahrzeug dreht im Stand
  // Gleiche Werte, da sie in unterschiedlicher Richtung
  // am Fahrzeug befestigt sind.
  servoSpeedLeft = 70;
  servoSpeedRight = 70;
  
  // Informiert Processing, dass das Auto steht, und sich nicht vorwaerts bewegt.
  drivingForward = 0;

  // Geschwindigkeit setzen...
  setServosSpeed(servoSpeedLeft, servoSpeedRight);
}

// Sende Nachricht via Bluetooth an Processing-Client
void sendMessage(){
  // Damit die Datenuebertragung fehlerfrei zustande kommt, wird folgendes "Frame" verwendet.
  // Die Infos werden in einen String zusammengefuegt, die durch ein klares Trennzeichen wieder
  // gesplittet werden koennen:
  /* 
   *
   * ### NACHRICHTEN "FRAME" - STRUKTUR ###
   * <timestamp>::<servoSpeedLeft>::<servoSpeedRight>::<distanceFront>::<distanceRight>::<directionMode>::<drivingForward>
   *
  */

  // Bevor gesendet wird, wird der Kanal noch einmal "geleert"
  BTConn.flush();
  
  // Aktuelle Laufzeit des Arduinos
  msg += millis() / 1000;
  msg += "::";
  // == siehe Deklarationen == //
  msg += servoSpeedLeft;
  msg += "::";
  msg += servoSpeedRight;
  msg += "::";
  msg += distanceFront;
  msg += "::";
  msg += distanceRight;
  msg += "::";
  msg += directionMode;
  msg += "::";
  msg += drivingForward;
  
  // .print sendet die Nachricht ueber den Bluetooth-Kanal
  BTConn.print(msg);
}

// Berechnung der Distanzen des jeweiligen Sensors
long getDistance(int trigPin, int echoPin){
  // Code aus folgender Quelle uebernommen: 
  // http://www.tautvidas.com/blog/2012/08/distance-sensing-with-ultrasonic-sensor-and-arduino/

  // Set digital write to low and prepare to send. Wait 2 microseconds to avoid data failure.
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  
  // Set digital write to hight and start measurement by sending a signal. Send 10 microseconds.
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  
  // Set digital write to low to stop sending a signal.
  digitalWrite(trigPin, LOW);
  
  // Listen on echo pin and receive a value of the reflected us signal. Calculate the distance.
  duration = pulseIn(echoPin, HIGH);
  return ((duration/2) / 29.1);
}
