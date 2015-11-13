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

int BTData; // Der Datenstrom aus BTConn in Bytes übertragen und per .read()-Funktion in einen Integerwert umgewandelt und in BTData gespeichert.
String msg; // Der Datenstring, der Übertragen wird. 2 Doppelpunkte :: trennen die Werte voneinander. Processing weiß, die diese Nachricht zu interpretieren ist.

int servoSpeedLeft = 2, servoSpeedRight = 3, distanceFront = 0, distanceRight = 0, directionMode = 0;
int areaFrontborder = 9, areaUpperborder = 8, areaLowerborder = 7;

/*
  These declaration is important for further measurements from the distance sensors
*/
long duration, duration_middle, duration_right;
/*
  The following declarations set the pin variables for Sensor one and two.
  The ultra sonic sensor will be called _middle and _right.
*/
int trigPin_middle = 3;
int echoPin_middle = 5;
int trigPin_right = 6;
int echoPin_right = 9;

boolean autoMode = false;
int drivingForward = 0;

/* 
 *
 * ### NACHRICHTEN "FRAME" - STRUKTUR ###
 * <timestamp>::<servoSpeedLeft>::<servoSpeedRight>::<distanceFront>::<distanceRight>
 *
*/

void setup() {
  BTConn.begin(38400);
  pinMode(13, OUTPUT);
  
  pinMode(trigPin_middle, OUTPUT);
  pinMode(echoPin_middle, INPUT);
  
  pinMode(trigPin_right, OUTPUT);
  pinMode(echoPin_right, INPUT);
}

void loop() {
  distanceFront = getDistance(trigPin_middle, echoPin_middle);
  distanceRight = getDistance(trigPin_right, echoPin_right);
  
  msg = "";
  if (BTConn.available()){
    BTData=BTConn.read();
    if(BTData==1){
      sendMessage();
      digitalWrite(13, HIGH);
    }
    else if(BTData==2){
      setServosUp();
    }
    else if(BTData==3){
      setServosDown();
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
      digitalWrite(13, HIGH);
      autoMode = false;
    }
    else if(BTData==10){
      autoMode = true;
      digitalWrite(13, HIGH);
    }
  }
  
  if(autoMode){
    if(distanceFront < areaFrontborder){
      changeDirectionLeft();
    }
    else if(distanceRight > 30){
      changeDirectionRight();
    }
    else{
      driveForward();
      if(distanceRight > areaUpperborder){
        curveRight();
      }
      else if(distanceRight < areaLowerborder){
        curveLeft();
      }
    }
  }
  
  delay(100);
  digitalWrite(13, LOW);
}

void changeDirectionLeft(){
  turnLeftInPosition();
  directionMode++;
      drivingForward = 0;
  delay(1600);
}

void changeDirectionRight(){
  delay(1600);
  turnRightInPosition();
  directionMode--;
      drivingForward = 0;
  delay(1000);
}

void setServosUp(){
  servoRight.attach(2);
  servoLeft.attach(4);
  
  servoLeft.write(90);
  servoRight.write(90);
  
  servoSpeedLeft = 90;
  servoSpeedRight = 90;
}

void setServosDown(){
  servoLeft.detach();
  servoRight.detach();
}

void breaking(){
  servoLeft.write(90);
  servoRight.write(90);
  
  servoSpeedLeft = 90;
  servoSpeedRight = 90;
}

void driveForward(){
  servoLeft.write(50);
  servoRight.write(130);
  
  servoSpeedLeft = 50;
  servoSpeedRight = 130;
  
  drivingForward = 1;
}

void curveLeft() {
  servoLeft.write(80);
  servoRight.write(140);
  
  servoSpeedLeft = 80;
  servoSpeedRight = 140;
}
void curveRight() {
  servoLeft.write(50);
  servoRight.write(110);
  
  servoSpeedLeft = 50;
  servoSpeedRight = 110;
}

void turnLeftInPosition(){
  servoLeft.write(110);
  servoRight.write(110);
  
  servoSpeedLeft = 110;
  servoSpeedRight = 110;
}

void turnRightInPosition(){
  servoLeft.write(70);
  servoRight.write(70);
  
  servoSpeedLeft = 70;
  servoSpeedRight = 70;
}

void sendMessage(){
  BTConn.flush();
  
  msg += millis() / 1000;
  msg += "::";
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
  
  BTConn.print(msg);
}

long getDistance(int trigPin, int echoPin){
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
