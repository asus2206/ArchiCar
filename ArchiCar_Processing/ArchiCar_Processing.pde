/*
 * ArchiCar_Processing Zeichen-/Steuer-Software-Client
 * 
 * Steuert das ArchiCar, empfaengt die Distanzen zu den Wänden
 * und die gefahrene Strecke.
 *
 * Verbindet sich VIA Bluetooth zum Fahrzeug
 *
 * 2 Modi werden unterstuetzt: Steuerung via Pfeiltasten + Automatischer Modus mit Zeichnung der gefahrenen Strecke
 *
 * AUTHOR: Lorenz Kromer
 * MATRNR: mt131044
 * FACH: IAI Semester-Projekt SS 2015 @ FH St. Pölten
 *
 * KONTAKT: mt131044@fhstp.ac.at
*/
// --- IMPORTS --- //
import processing.serial.*;
import controlP5.*;

// --- OBJEKTE --- //

// Serial-Object, um auf die Bluetooth-Schnittstelle des PCs zugreifen zu koennen.
Serial s;

// PVector-Object, um die XY-Koordinaten im Anschluss in einer ArrayList zu speichern.
// Laesst sich spaeter leichter auslesen
PVector archiPosition, lastPosition, basePosition;

// ControlP5-Object fuer GUI Elemente.
ControlP5 cp5;

// Alle GUI-Elemente.
Button connectButton, manualControlButton, startScanButton;

PImage arrowKeyUp, arrowKeyDown, arrowKeyLeft, arrowKeyRight;

// --- ARRAYS --- //

// String-Array fuer gesplittete Message vom Arduino. Sprich, alle empfangenen Daten.
String[] rcv;

// Array-List: Typ PVector - Speicher fuer alle Coordinaten.
ArrayList<PVector> coordinates = new ArrayList<PVector>();


// --- STRINGS --- //

// Die einzelnen Datenfelder aus dem rcv-Array.
String timestamp = "n/a", 
  servoSpeedLeft = "n/a", 
  servoSpeedRight = "n/a", 
  distanceFront = "n/a", 
  distanceRight = "n/a", 
  directionChanged = "0",
  drivingForward = "n/a";

// --- INTEGERS --- //

// Fuer Processing-Timer. Temporaerer millis()-Wert.
int lastTime = 0;

// Zeit, wie lange das Auto schon gefahren ist.
int drivingTime = 0;

// Temporaerer Offset zum regulaeren Abstand des rechten Sensors zur Wand.
int tmpOffset = 0;

// Temporaere Direction, also die Richtung, in die das Auto gerade faehrt. Am Start 3 ?!?!?
int tmpDirection = 3;

// Refreshrate der Daten, Aktuellisieungsrate. 400 ms fuer optimale Funktion.
int refreshRate = 400;

// Groeße der Zeichenflaeche unter dem GUI Menu
int drawboard_width, drawboard_height;

// Groeße der Tastatursymbole im man. Modus
int imageSize_KeyUp = 100;
int imageSize_KeyDown = 100;
int imageSize_KeyLeft = 100;
int imageSize_KeyRight = 100;

// --- FLOATS --- //

// Die vom Fahrzeug zurueckgelegte Strecke pro Sekunde.
float distancePerCheck = 4;
// --- SPEED / DISTANZ Messungen --- //
/*(fuer Code irrelevant, hängt von Fahrzeug ab)
 * Servo-Stillstand................90
 * 10cm/s......................50/130
 * 8.5cm/s...mitKurve!!!.......70/110 (never used)
*/

// Die vom Fahrzeug zurueckgelegte Strecke in einem Refresh. == distancePerCheck?!
float drivenDistance = 0;

// Damit die Skizze der zurueckgelegten Strecke nicht aus dem Fenster faehrt, 
// muss die maximale X oder Y Laenge erfasst werden, damit das Drawboard skaliert werden kann.
float maxPosX = 0, maxPosY = 0;

// --- BOOLEANS --- //

// Status-Var ob PC schon mit BT-Device verbunden ist.
boolean notConnected = true, manualMode = false, autoMode = false;

void setup(){
  // --- SIMPLE WINDOW SETUPS --- //
  size(1080, 700, P2D);
  smooth(8);
  frameRate(60);
  frame.setResizable(true);
  // --- ^^^^^^^^^^^^^^^^^^^ --- //

  // Instanzieren der Klassen
  cp5 = new ControlP5(this);
  // lastPosition = letzte XY-Position des Fahrzeugs im Koordinatensystem
  lastPosition = new PVector();
  // basePosition = Start XY-Position des Fahrzeugs im Koordinatensystem, wird bei jeder Drehung neu gesetzt
  basePosition = new PVector();

  // Vordefinierte ausganswerte: Startposition des Fahrzeugs im XY-System
  basePosition.x = 100;
  basePosition.y = 100;
  lastPosition.x = basePosition.x;
  lastPosition.y = basePosition.y;

  // lade die Bilder fuer Tastensteuerung
  arrowKeyUp = loadImage("images/rauf.png");
  arrowKeyDown = loadImage("images/runter.png");
  arrowKeyLeft = loadImage("images/links.png");
  arrowKeyRight = loadImage("images/rechts.png");

  // Instanziere GUI-Buttons
  // ConnectButton verbindet Processing mit Fahrzeug via Bluetooth
  connectButton = cp5.addButton("via Bluetooth verbinden...")
      .setValue(0)
      .setPosition(20, 100)
      .setSize(200, 30);

  // manualControlButton schaltet das Processing-GUI um.
  manualControlButton = cp5.addButton("Manuelle Steuerung")
      .setValue(0)
      .setPosition(320, 100)
      .setSize(200, 30);

  // startScanButton schaltet dasProcessing-GUI auf das Zeichenboard um.
  startScanButton = cp5.addButton("Automatische Analyse")
      .setValue(0)
      .setPosition(620, 100)
      .setSize(200, 30);
}

// checkValues fragt beim Auto nach aktuellen Daten nach, wird mit refreshRate (400ms) aufgerufen
void checkValues(){
  //println("check");

  // Code 1: Frage nach Fahrzeugdaten
  s.write(1);

  // Wenn das Auto antwortet, sie Datenstring aus.
  if (s.available() > 0) {
    // Wandle die Daten aus dem Buffer in einen String um
    String inBuffer = s.readString();

    // Solange der Buffer nicht leer ist, lese ihn aus
    if (inBuffer != null) {
      // rcv = receive-Nachticht, diese muss aufgesplittet werden.
      // Trennung der Informationen durch ::
      rcv = split(inBuffer, "::");

      // Da bei der Datenuebertragung oft Nachrichten-Frames doppelt oder vermischt übertragen werden,
      // hilfst dieser try-catch Block, um fehlerhafte Daten herauszufiltern.
      try{
        // das rcv-Array darf nur 7 felder haben. Sind es mehr, ist die Information nicht zulässig.
        if(rcv.length == 7){

        // Instanz der PVector Klasse, zum Speichern der aktuellen Position.
        archiPosition = new PVector();
        
        // auslesen der Message-Daten.

        // Laufzeit des Arduinos
        timestamp = rcv[0];

        // Servo-Geschwindigkeit des linken Servos
        servoSpeedLeft = rcv[1];

        // Servo-Geschwindigkeit des rechten Servos
        servoSpeedRight = rcv[2];

        // Freie Distanz nach vorne
        distanceFront = rcv[3];

        // Freie Distanz nach rechts
        distanceRight = rcv[4];

        // Anzahl, wie oft das Auto bereits gewendet hat.
        // Essenziell für Positionsbestimmung im XY-System
        directionChanged = rcv[5];

        // Info, ob Fahrzeug noch vorwaerts faehrt.
        drivingForward = rcv[6];
        
        // println(rcv);
        
        // Wenn das Auto in bewegung ist -> neue Position berechnen!
        if( int(drivingForward) == 1){

          // Erhoehe zurueckgelegte Strecke um Fahrgeschwindikeit (10cm/s).
          // Abfrage alle 400ms -> 4cm/s pro Abfrage.
          drivenDistance=+distancePerCheck;
        
          // Rechne Anzahl der Drehungen Modulo 4, um die vier Richtungen im XY-System zu finden.
          /*
           * 0 ... fahre im XY nach unten
           * 1 ... fahre im XY nach rechts
           * 2 ... fahre im XY nach oben
           * 3 ... fahre im XY nach links
          */
          int i = int(directionChanged) % 4;
          
          // Abstand des Fahrzeugs zur rechten Seite, bevor der Offset berechnet wird.
          int xPositionOffset = int(distanceRight);
          

          // Berechnung des Offsets.
          /*
           * Wenn sich das Fahrzeug außer-/innerhalb der
           * Ideallinie (zwischen 8 und 7 cm zur Wand)
           * befindet, wird die Differenz zur Ideallinie
           * berechnet und als Offset definiert.
           *
          */
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

          // Drehung im Koordinatensystem
          /*
           * Sofern sich die uebertragene Anzahl der 
           * Drehungen veraendert wird die Baseposition
           * auf die letzte Position des Autos im XY-System gesetzt.
           * So ist eine "Drehung" um 90 Grad moeglich.
           *
          */          
          if(tmpDirection != i){
            basePosition.x = lastPosition.x;
            basePosition.y = lastPosition.y;
            tmpDirection = i;
          }
          
          // Setzen der neuen Positionen des Fahrzeugs im XY-System.
          /*
           * 0 ... fahre im XY nach unten
           * 1 ... fahre im XY nach rechts
           * 2 ... fahre im XY nach oben
           * 3 ... fahre im XY nach links
          */
          if(i == 0){
            archiPosition.x = basePosition.x + xPositionOffset;
            archiPosition.y = lastPosition.y + drivenDistance;
            //println("down");
          }
          else if(i == 1){
            archiPosition.x = lastPosition.x + drivenDistance;
            archiPosition.y = basePosition.y + xPositionOffset;
            //println("right");
          }
          else if(i == 2){
            archiPosition.x = basePosition.x + xPositionOffset;
            archiPosition.y = lastPosition.y - drivenDistance;
            //println("up");
          }
          else if(i == 3){
            archiPosition.x = lastPosition.x - drivenDistance;
            archiPosition.y = basePosition.y + xPositionOffset;
            //println("left");
          }

          // Vor einem neuen Durchlauf, speichere die letzte Position.
          lastPosition.x = archiPosition.x;
          lastPosition.y = archiPosition.y;
          
          // Zum zeichnen der zurueckgelegten Strecke, wird die Position in der ArrayList gespeichert.
          coordinates.add(archiPosition);
          }
        }
      }
      catch(Exception e){
        // wurde eine fehlerhafte Nachricht uebertragen, wird diese Exception geworfen.
        println("data dump");
      }
    }
    // Loesche den lokalen Buffer-String, um Fehler zu vermeiden.
    inBuffer = null;
  }
  // Leeren des aktuellen BT-Connection Buffers, um fehler zu vermeiden.
  s.clear();
}

void draw() {
  // Anpassung der Groeße des Zeichenbretts an Fenstergroeße
  drawboard_width = width;
  drawboard_height = (height/5) * 4;

  // Setzen das Hintergrundfarbe fuer ganzes Fenster
  background(120,140,160);

  // Textausgabe:
  /*
   * Setze Text-Farbe
   * Setze Text-Groeße
   * Ausgabe der Messwerte
  */
  fill(213,213,213);
  textSize(26); 
  text("ArchiCar Scanner", 10, 30);
  
  textSize(12);
  text("Arduino UpTime: " + timestamp + " s", 20, 60);
  text("SensorSpeed: " + servoSpeedLeft, 220, 60);
  text("DistanceFront: " + distanceFront + " cm", 420, 60);
  text("DistanceRight: " + distanceRight + " cm", 620, 60);
  text("ActiveMode: " + directionChanged, 820, 60);

  // Solange das Fahrzeug nicht verbinden ist, werden noch keine Daten abgerufen.
  // Ist das Auto verbunden, wird dies Signalisiert (gruenes feld) und 
  // alle 400ms wird eine Abfrage gesendet.
  if(notConnected){fill(200,0,0);}
  else{
    if( millis() - lastTime >= refreshRate){
      checkValues();
      lastTime = millis();
    }
    fill(0,200,0);
  }

  // nostroke, damit die Rechtecke keine Rahmen haben.
  noStroke();
    // Info-Feld fuer Verbindungsstatus
    rect(220, 100, 30, 30);
  
  // Wenn manualMode aktiviert ist, zeigt Processing die Tastatur
  if(manualMode){
    showManualMode();
    fill(0,200,0);
  }
  else{fill(200,0,0);}
    // Info-Feld fuer Bedienmodus (manual)
    rect(520, 100, 30, 30);
  
  // Wenn autoMode aktiviert ist, zeigt Processing das Zeichenbrett
  if(autoMode){
    showScanMode();
    fill(0,200,0);
  }
  else{fill(200,0,0);}
    // Info-Feld fuer Bedienmodus (automatisch)
    rect(820, 100, 30, 30);
}

void showManualMode(){
  // Hintergrund fuer die eingeblendete Tastatur
  fill(80,90,100);
  rect(0, height/5, drawboard_width, drawboard_height );

  // Positionierung der Tastatur-Bilder
  // Nicht die feine englische Art =S Sorry for that!
  image(arrowKeyUp, drawboard_width / 2 - imageSize_KeyUp / 2, drawboard_height / 2 - imageSize_KeyUp / 2, imageSize_KeyUp, imageSize_KeyUp);
  image(arrowKeyDown, drawboard_width / 2 - imageSize_KeyDown / 2, drawboard_height / 2 + imageSize_KeyDown / 1.5, imageSize_KeyDown, imageSize_KeyDown);
  image(arrowKeyLeft, drawboard_width / 2 - imageSize_KeyLeft / 1.5 - 100, drawboard_height / 2 + imageSize_KeyLeft / 1.5, imageSize_KeyLeft, imageSize_KeyLeft);
  image(arrowKeyRight, drawboard_width / 2 + imageSize_KeyRight / 1.5, drawboard_height / 2 + imageSize_KeyRight / 1.5, imageSize_KeyRight, imageSize_KeyRight);
}

void showScanMode(){
  // Hintergrund fuer das Zeichenbrett
  fill(240);
  rect(0, height/5, drawboard_width, drawboard_height );

  // Farbe des gezeichneten Punktes.
  fill(0);

  // Skalierung der Zeichenflaeche
  // Bevor die Strecke gezeichnet wird, werden die Maximalwerte ueberprueft.
  for(PVector position : coordinates){
    if(position.x > maxPosX){
      maxPosX = position.x;
    }
    if(position.y > maxPosY){
      maxPosY = position.y;
    }
  }

  // Zeiche die zurueckgelegte Strecke
  // PushMatrix, um gezielt den Punkt im XY-System zu manipulieren
  pushMatrix();

  // Wenn einer der PVector - Werte die Groeße des Zeichenboard ueberschreitet, wird skaliert.
  if( maxPosY > drawboard_height || maxPosX > drawboard_width ){ scale(0.8); }
    // Zeichne die in der ArrayList(coordinates) gespeicherten Punkte und somit die zurueckgelegte STrecke.
    for(PVector position : coordinates){
      ellipse(200 + (position.x * 2), 200 + (position.y * 2), 5,5);
    }
  // scale, transform usw Befehle werden wieder auf das gesamte Fenster uebernommen.
  popMatrix();
}

void keyReleased() {
  // Fuer Feedback im manuellen Modus.
  // die jeweilige Taste wird skaliert und wieder auf die normalgroeße gesetzt.
  imageSize_KeyUp = 100;
  imageSize_KeyDown = 100;
  imageSize_KeyLeft = 100;
  imageSize_KeyRight = 100;
}

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
 * 11....anhalten
 * 12....Fahre rueckwaerts
*/

void keyPressed() {
  // Bei key-pressed Events werden die definierten Codes versendet. Siehe ArchiCar_Controls - Codes
  if (key == CODED) {
    if (keyCode == UP) {
      s.write(4);
      // Fuer Feedback im manuellen Modus.
      // die jeweilige Taste wird skaliert und wieder auf die normalgroeße gesetzt.
      imageSize_KeyUp = 98;
  }
    else if (keyCode == LEFT) {
      s.write(7);
      // Fuer Feedback im manuellen Modus.
      // die jeweilige Taste wird skaliert und wieder auf die normalgroeße gesetzt.
      imageSize_KeyLeft = 98;
    }
    else if (keyCode == RIGHT) {
      s.write(8);
      // Fuer Feedback im manuellen Modus.
      // die jeweilige Taste wird skaliert und wieder auf die normalgroeße gesetzt.
      imageSize_KeyRight = 98;
    }
    else if (keyCode == DOWN) {
      s.write(12);
      // Fuer Feedback im manuellen Modus.
      // die jeweilige Taste wird skaliert und wieder auf die normalgroeße gesetzt.
      imageSize_KeyDown = 98;
    }
  } 
  // Bei key-pressed Events werden die definierten Codes versendet. Siehe ArchiCar_Controls - Codes
  else if (keyPressed) {
    if (key == '1') {
      s.write(13);
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

public void controlEvent(ControlEvent theEvent) {
  if (theEvent.getController() == connectButton) {
    try{
      println("Stelle Verbindung zu BT-Device her...");
      s = new Serial(this, Serial.list()[0], 38400);
      println("Device gefunden, oeffne Port...");
      notConnected = false;
      println("Erfolgreich!");
    }
    catch (Exception e) {
      println("Konnte keine Verbindung zu BT-Device herstellen. Device nicht gefunden.");
      notConnected = true;
    }
  }
  else if (theEvent.getController() == manualControlButton) {
    if(!notConnected){
      autoMode = false;
      try{
        println("Starte Manuelle Fahrzeugkontrolle.");
        manualMode = true;
        s.write(2);
        println("Erfolgreich! Das Auto kann nun mit den Pfeiltasten gesteuert werden.");
      }
      catch (Exception e) {
        println("Fehler beim manuellen Ansteuern des Fahrzeugs. Sind Sie mit dem Auto verbunden?");
        manualMode = false;
      }
    }
    else{
      println("Bitte verbinden Sie sich erst via BT zu dem Fahrzeug.");
    }
  }
  else if (theEvent.getController() == startScanButton) {
    if(!notConnected){
      manualMode = false;
      try{
        coordinates = new ArrayList<PVector>();
        println("Bereite Scann der Fahrzeugumgebung vor.");
        autoMode = true;
        println("Fertig! Die zurueckgelegte Strecke wird nun gezeichnet.");
      }
      catch (Exception e) {
        println("Fehler beim manuellen Ansteuern des Fahrzeugs. Sind Sie mit dem Auto verbunden?");
        autoMode = false;
      }
    }
    else{
      println("Bitte verbinden Sie sich erst via BT zu dem Fahrzeug.");
    }
  }
}