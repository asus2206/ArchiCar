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

// --- SPEED / DISTANZ Messungen --- //
/*
 * Servo-Stillstand................90
 * 10cm/s......................50/130
 * 8.5cm/s...mitKurve!!!.......70/110
 *
*/

// --- ArchiCar_Controls --- //
/*
 * 1....Lade Fahrzeuginfos (Laufzeit, Distanzen und Speed)
 * 2....Setze Servos bereit
 * 3....Schalte Servos ab
 * 4....Fahre vorwärts
 * 5....Kurve links fahren
 * 6....Kurve rechts fahren
 * 7....turnLeftInPosition
 * 8....turnRightInPosition
 * 9....aktiviere ManualMode
 * 10....aktiviere AutoMode
*/
import processing.serial.*;

Serial s;
String[] rcv;
String timestamp = "1", servoSpeedLeft = "2", servoSpeedRight = "3", distanceFront = "4", distanceRight = "5", directionChanged = "0";

int lastTime = 0;
int drivingTime = 0;
int tmpOffset = 0;
int tmpDirection = 3;
int refreshRate = 400; /*... lowest value 400ms ...*/

float distancePerCheck;
float drivenDistance = 0;

PVector archiPosition, lastPosition = new PVector(), basePosition = new PVector();

ArrayList<PVector> coordinates = new ArrayList<PVector>();



void setup(){
  size(920,520);
  frameRate(25);
  
  println(Serial.list());
  s = new Serial(this, Serial.list()[0], 38400);
  println("Opening Port");
  
  basePosition.x = 100;
  basePosition.y = 100;
  lastPosition.x = basePosition.x;
  lastPosition.y = basePosition.y;
  distancePerCheck = 4;
  println(distancePerCheck);
}

void checkValues(){
  //println("check");
  s.write(1);
  if (s.available() > 0) {
    String inBuffer = s.readString();
    if (inBuffer != null) {
      rcv = split(inBuffer, "::");
      try{
        if(rcv.length == 7){
        archiPosition = new PVector();
        
        timestamp = rcv[0];
        servoSpeedLeft = rcv[1];
        servoSpeedRight = rcv[2];
        distanceFront = rcv[3];
        distanceRight = rcv[4];
        directionChanged = rcv[5];
        int drivingForward = int(rcv[6]);
        //println("Received");
        //println(inBuffer);
        
        if(drivingForward == 1){
          drivenDistance=+distancePerCheck;
          //println("hier");
        }
        
        //println(drivenDistance);
        
        int i = int(directionChanged) % 4;
        
        int xPositionOffset = int(distanceRight);
        
        if(xPositionOffset != tmpOffset){
          if(xPositionOffset > 8){
            xPositionOffset = xPositionOffset - 8;
          }
          else if(xPositionOffset < 7){
            xPositionOffset = (7 - xPositionOffset) * (-1);
          }
          else{
            xPositionOffset = 0;
          }
        }
        
        if(tmpDirection != i){
          basePosition.x = lastPosition.x;
          basePosition.y = lastPosition.y;
          tmpDirection = i;
        }
        
        if(i == 0){
          archiPosition.x = basePosition.x + xPositionOffset;
          archiPosition.y = lastPosition.y + drivenDistance;
          println("down");
        }
        else if(i == 1){
          archiPosition.x = lastPosition.x + drivenDistance;
          archiPosition.y = basePosition.y + xPositionOffset;
          println("right");
        }
        else if(i == 2){
          archiPosition.x = basePosition.x + xPositionOffset;
          archiPosition.y = lastPosition.y - drivenDistance;
          println("up");
        }
        else if(i == 3){
          archiPosition.x = lastPosition.x - drivenDistance;
          archiPosition.y = basePosition.y + xPositionOffset;
          println("left");
        }
        lastPosition.x = archiPosition.x;
        lastPosition.y = archiPosition.y;
        
        coordinates.add(archiPosition);
        }
      }
      catch(Exception e){
        println("data dump");
      }
    }
    inBuffer = null;
  }
  s.clear();
}

void draw() {
  background(255);
  
  if( millis() - lastTime >= refreshRate){
    checkValues();
    lastTime = millis();
  }
  
  fill(50);
  text("Arduino UpTime: " + timestamp + " s", 10, 20);
  text("SensorSpeed: " + servoSpeedLeft, 10, 40);
  text("DistanceFront: " + distanceFront + " cm", 10, 60);
  text("DistanceRight: " + distanceRight + " cm", 10, 80);
  text("ActiveMode: " + directionChanged, 10, 100);
  
  for(PVector position : coordinates){
    ellipse(position.x, position.y, 5,5);
  }
}

void keyPressed() {
  if (key == CODED) {
    if (keyCode == UP) {
      checkValues();
    }
    else if (keyCode == LEFT) {
      s.write(7);
    }
    else if (keyCode == RIGHT) {
      s.write(8);
    }
  } 
  else if (keyPressed) {
    if (key == '1') {
      s.write(1);
    } 
    else if (key == '2') {
      s.write(2);
    } 
    else if (key == '3') {
      s.write(3);
    } 
    else if (key == '4') {
      s.write(4);
    } 
    else if (key == '5') {
      s.write(5);
    } 
    else if (key == '6') {
      s.write(6);
    }
    else if (key == '7') {
      s.write(9);
    }
    else if (key == '8') {
      s.write(10);
    }
  }
}