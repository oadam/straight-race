library car;
import 'dart:html';
import 'package:box2d/box2d.dart';
import 'keyboard.dart';
import 'car_physics.dart';
import 'straight_race.dart';
import 'dart:math';

abstract class CarController {
 CarControls getControls(Body body);
}

class Car {
  final Body body;
  final CarController controller;
  int color = 0;
  int score = 0;
  static final CarPhysics carPhysics = new CarPhysics();

  Car(this.body, this.controller);
  
  void applyForces(Iterable<Car> others) {
    CarControls controls = controller.getControls(body);
    carPhysics.applyForces(body, others.map((c)=>c.body), controls);
  }
  
  static void applyForcesForAll(List<Car> cars) {
    for (var i = 0; i < cars.length; i++) {
      Car car =  cars[i];
      //concat
      car.applyForces([cars.sublist(0, i), cars.sublist(i+1)].expand((_)=>_));
    }
  }
  
  static Car getFirst(List<Car> cars) {
    return cars.reduce((a, b) => a.body.position.y > b.body.position.y ? a : b);
  }
  
  static void applyLooseWin(List<Car> cars) {
    Car first = getFirst(cars);
    for (var i = 0; i < cars.length; i++) {
      Car c = cars[i];
      if ((first.body.position.y - c.body.position.y) < Game.LOOSING_DISTANCE) {
        continue;
      }
      c.score--;
      double x = -first.body.position.x.sign * (Game.TRACK_WIDTH / 2.0 - Game.START_SPACE_BETWEEN_CARS);
      c.body.setTransform(new Vector2(x, first.body.position.y + Game.START_SPACE_BETWEEN_CARS), PI/2.0);
      c.body.linearVelocity = first.body.linearVelocity;
      c.body.angularVelocity = 0.0;
      break;
    }
  }
}

class KeyboardController extends CarController {
  final Keyboard _keyboard;
  final int up;
  final int left;
  final int down;
  final int right;
    
  KeyboardController(this._keyboard, this.up, this.left, this.down, this.right) {}
  
  CarControls getControls(Body body) {
    return new CarControls(_keyboard.isPressed(left),
                        _keyboard.isPressed(right),
                        _keyboard.isPressed(up),
                        _keyboard.isPressed(down)
    );
  }
}

class BotController extends CarController {
  CarControls getControls(Body body) {
    Vector2 botSpeed = body.getLinearVelocityFromLocalPoint(new Vector2.zero());
    bool        botLeft = botSpeed.x > 0 && body.position.x > 0.3 * Game.TRACK_WIDTH;
    bool        botRight = botSpeed.x < 0 && body.position.x < -0.3 * Game.TRACK_WIDTH;
    return new CarControls(botLeft,
                         botRight,
                         true,
                         false
     );
   }
}