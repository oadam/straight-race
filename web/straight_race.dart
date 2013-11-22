import 'dart:html';
import 'dart:math';
import 'car.dart';
import 'keyboard.dart';


class Game {
  final Keyboard keyboard;

  final Car car = new Car();
  final CanvasRenderingContext2D context;
  final int width;
  final int height;
  
  static const num speed = 3;
  static const num speedRot = 0.04;
  
  Game(CanvasElement canvas): 
    keyboard = new Keyboard(),
    context = canvas.getContext("2d"),
    width = canvas.width,
    height = canvas.height {
    car.x = width / 2;
    car.y = height / 2;
    car.a = 0;
    
    window.requestAnimationFrame(this.update);
  }

  update(e) {
    if (keyboard.isPressed(KeyCode.UP)) {
      car.x += speed * cos(car.a);
      car.y += speed * sin(car.a);
    }
    if (keyboard.isPressed(KeyCode.LEFT)) {
      car.a -= speedRot;
    }
    if (keyboard.isPressed(KeyCode.RIGHT)) {
      car.a += speedRot;
    }
    context.setFillColorRgb(255, 0, 0);
    context.fillRect(0, 0, width, height);
   
    drawCar(context, car);
    
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
    ..translate(car.x, car.y)
    ..scale(20, 20)
    ..rotate(car.a)
    ..lineWidth = 0.01
    ..setStrokeColorRgb(0, 255, 0)
    ..strokeRect(-0.5, -0.25, 1, 0.5)
    ..setFillColorRgb(0, 255, 255)
    ..fillRect(0.43, 0.18, 0.05, 0.05)
    ..fillRect(0.43, -0.23, 0.05, 0.05)
    ..restore();  
}
