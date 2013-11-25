import 'dart:html';
import 'dart:math';
import 'car.dart';
import 'keyboard.dart';
import 'package:vector_math/vector_math.dart';


class Game {
  final Keyboard keyboard;

  final Car car = new Car();
  final CanvasRenderingContext2D context;
  final int width;
  final int height;
  
  num lastUpdateTime = null;
  
  static const num speed = 3;
  static const num speedRot = 0.04;
  
  Game(CanvasElement canvas): 
    keyboard = new Keyboard(),
    context = canvas.getContext("2d"),
    width = canvas.width,
    height = canvas.height {
    car.pos = new Vector2(.0, .0);
    car.a = 0.0;
    
    
    window.requestAnimationFrame(this.update);
  }

  update(num time) {
    if (lastUpdateTime != null) {
      num ellapsed = time - lastUpdateTime;
      lastUpdateTime = time;
      
      car.updatePos(ellapsed / 1000.0, 
          turnLeft: keyboard.isPressed(KeyCode.LEFT),
          turnRight: keyboard.isPressed(KeyCode.RIGHT),
          accel: keyboard.isPressed(KeyCode.UP),
          brake: keyboard.isPressed(KeyCode.DOWN)
      );
    }
    
    //clear
    context
      ..setFillColorRgb(255, 0, 0)
      ..fillRect(0, 0, width, height);
      
    context
      ..save()
      ..translate(0.0, height)
      ..scale(1.0, -1.0)
      ..scale(5, 5);
    drawCar(context, car);
    context.restore();
    
    document.getElementById("log").text = "pos ${car.pos.x.toStringAsExponential(3)}/${car.pos.y.toStringAsExponential(3)} : v ${car.v.x.toStringAsExponential(3)}/${car.v.y.toStringAsExponential(3)}";
    lastUpdateTime = time;
    window.requestAnimationFrame(update);
  }
}

void main() {
  CanvasElement canvas = querySelector("#canvas");
  
  Game game = new Game(canvas);
}

void drawCar(CanvasRenderingContext2D context, Car car) {
  context
    ..save()
    ..translate(car.pos.x, car.pos.y)
    ..rotate(car.a)
    ..lineWidth = 0.01
    ..setFillColorRgb(0, 255, 0)
    ..fillRect(-Car.length / 2.0, -Car.width / 2.0, Car.length, Car.width)
    ;
  //tires
  context.setFillColorRgb(255, 255, 0);
  car.tiresAndPos.forEach((tireAndPos) {
    context
      ..save()
      ..translate(tireAndPos.pos.x, tireAndPos.pos.y)
      ..rotate(tireAndPos.angle)
      ..fillRect(-Car.length / 30, -Car.width / 100, Car.length / 15, Car.width / 50)
      ..restore();
  });
  context
    ..restore();  
}
