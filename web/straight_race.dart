import 'dart:html';
import 'car.dart';
import 'keyboard.dart';
import 'package:vector_math/vector_math.dart';
import 'dart:math';

class Camera {
  Vector2 pos = new Vector2.zero();
  Vector2 speed = new Vector2.zero();
  double zoom = 5.0;
  static num tracking = 1.0e-1;//m.s-2 / m     1g at 10m
  static num dumping = 2 * sqrt(tracking);//m.s-2 / m.s-1   1 g at 10m.s-1
  
  void updatePos(Vector2 target, Vector2 targetSpeed, double dt) {
    speed += ((target - pos) * Camera.tracking - (speed - targetSpeed) * Camera.dumping) * dt;
    pos += speed * dt;
  }
}

class Game {
  final Keyboard keyboard;

  final Car car = new Car();
  final Camera camera;
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
    height = canvas.height,
    camera = new Camera() {
    car.pos = new Vector2(.0, .0);
    car.a = 0.0;
    camera.pos = car.pos;
    
    window.requestAnimationFrame(this.update);
  }

  update(num time) {
    if (lastUpdateTime != null) {
      num ellapsed = time - lastUpdateTime;
      lastUpdateTime = time;
      num dt = ellapsed / 1000.0;
      
      car.updatePos(dt, 
          turnLeft: keyboard.isPressed(KeyCode.LEFT),
          turnRight: keyboard.isPressed(KeyCode.RIGHT),
          accel: keyboard.isPressed(KeyCode.UP),
          brake: keyboard.isPressed(KeyCode.DOWN)
      );
      
      camera.updatePos(car.pos, new Matrix2.rotation(car.a) * car.v, dt);
     }
    
    //clear
    context
      ..setFillColorRgb(255, 0, 0)
      ..fillRect(0, 0, width, height);
      
    context
      ..save()
      ..translate(0.0, height)
      ..scale(1.0, -1.0);
      
        
    //draw dots
    const double dotDist = 10.0;
    double zoomedDotDist = dotDist * camera.zoom;
    context.setFillColorRgb(0, 0, 255);
    for (var x = -camera.zoom * camera.pos.x % zoomedDotDist; x < width; x+= zoomedDotDist) {
      for (var y = -camera.zoom * camera.pos.y % zoomedDotDist; y < height; y+= zoomedDotDist) {
        context.fillRect(x, y, 1, 1);
      } 
    }
    context.translate(width/2, height/2);
    

    context
      ..scale(camera.zoom, camera.zoom);
   
    
    //draw car
    context.save();
    context.translate(car.pos.x - camera.pos.x, car.pos.y - camera.pos.y);
    drawCar(context, car);
    context.restore();
    
    
    
    
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
    ..rotate(car.a)
    ..lineWidth = 0.01
    ..setFillColorRgb(0, 255, 0)
    ..fillRect(-Car.length / 2.0, -Car.width / 2.0, Car.length, Car.width)
    ;
  //tires
  context.setFillColorRgb(255, 255, 255);
  car.tiresAndPos.forEach((tireAndPos) {
    context
      ..save()
      ..translate(tireAndPos.pos.x, tireAndPos.pos.y)
      ..rotate(tireAndPos.angle)
      ..fillRect(-Car.length / 30, -Car.width / 50, Car.length / 15, Car.width / 25)
      ..restore();
  });
  context
    ..restore();  
}
