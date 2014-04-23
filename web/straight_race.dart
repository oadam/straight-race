import 'dart:html';
import 'car.dart';
import 'keyboard.dart';
import 'package:vector_math/vector_math.dart';
import 'dart:math';
import 'package:box2d/box2d.dart';
import 'package:box2d/box2d_browser.dart';


class Camera {
  Vector2 pos = new Vector2.zero();
  Vector2 speed = new Vector2.zero();
  double zoom = 12.0;
  static num tracking = 4.0e-1 * 4;//m.s-2 / m     1g at 10m
  static num dumping = 2 * sqrt(tracking);//m.s-2 / m.s-1   1 g at 10m.s-1

  void updatePos(Vector2 target, Vector2 targetSpeed, double dt) {
    speed += ((target - pos) * Camera.tracking - (speed - targetSpeed) * Camera.dumping) * dt;
    pos += speed * dt;
  }
}

class Game {
  final Keyboard keyboard;

  final World world = new World(new Vector2(.0, .0), false, new DefaultWorldPool());
  final Car car = new Car();
  Body carBody;
  List<Body> wallBodies = [];
  final Vector2 wallSize = new Vector2(1.0, 300.0);
  
  final Camera camera;
  final CanvasRenderingContext2D context;
  final int width;
  final int height;

  static const double worldStep = 0.05;
  
  final ImageElement carImage = new ImageElement(src: 'car.png');
  bool paused = false;
  bool firstIterationAfterPause = false;

  final NumberInputElement angleInput;

  num lastUpdateTime = null;

  static const num speed = 3;
  static const num speedRot = 0.04;
  
  static const num _WORLD_STEP = 1 / 60;
  static const num _VELOCITY_ITERATIONS = 1 / 60;
  static const num _POSITION_ITERATIONS = 1 / 60;
    

  Game(CanvasElement canvas):
    keyboard = new Keyboard(),
    context = canvas.getContext("2d"),
    width = canvas.width,
    height = canvas.height,
    angleInput = document.getElementById("steering"),
    camera = new Camera() {
    
    //car
    BodyDef bd = new BodyDef();
    bd.type = BodyType.DYNAMIC;
    bd.position = new Vector2(.0, .0);
    bd.angle = PI / 2;
    carBody = world.createBody(bd);

    List<PolygonShape> shapes = Car.getShapes();
    double totalSurface = shapes.fold(0.0, (s, fd) {
      MassData md = new MassData();
      fd.computeMass(md, 1);
      return s + md.mass;
    });
    for (PolygonShape sd in shapes) {
      FixtureDef fd = new FixtureDef();
      fd.shape = sd;
      fd.density = Car.weight / totalSurface;
      fd.restitution = 0.5;
      fd.friction = 0.1;
      carBody.createFixture(fd);
    }
    
    //wall
    for (double offset in [-10.0, 10.0]) {
      PolygonShape wallShape = new PolygonShape();
      wallShape.setAsBox(wallSize.x * 0.5, wallSize.y * 0.5);
      BodyDef wbd = new BodyDef();
      wbd.position = new Vector2(offset, 0.0);
      Body wallBody = world.createBody(wbd);
      wallBody.createFixtureFromShape(wallShape);
      wallBodies.add(wallBody);
    }
    
    camera.pos = carBody.position;
    
    Vector2 extents = new Vector2(canvas.width / 2, canvas.height / 2);
    CanvasViewportTransform viewport = new CanvasViewportTransform(extents, extents);
    CanvasDraw debugDraw = new CanvasDraw(viewport, context);
    world.debugDraw = debugDraw;
    
    window.onKeyDown.forEach((event) {
      int keycode = event.keyCode;
      if (event.keyCode == 80) {//'p'
        paused = !paused;
        firstIterationAfterPause = true;
        window.requestAnimationFrame(update);
      }
    });

    angleInput.value = (Car.angle / PI * 180).toStringAsFixed(1);
    angleInput.onChange.forEach((event) {
      Car.angle = double.parse(angleInput.value) / 180 * PI;
    });

    window.requestAnimationFrame(this.update);
  }
  
  static const double _WORLD_STEP_MS = _WORLD_STEP * 1000;
    
  update(num time) {
    if (paused) {return;}
    if (lastUpdateTime == null || firstIterationAfterPause) {
      lastUpdateTime = time;
      firstIterationAfterPause = false;
    }
    int nbStep = ((time - lastUpdateTime) / _WORLD_STEP_MS).floor();
    lastUpdateTime += _WORLD_STEP_MS * nbStep;
    for (var i = 0; i < nbStep; i++) {
      car.applyForces(carBody, turnLeft: keyboard.isPressed(KeyCode.LEFT),
          turnRight: keyboard.isPressed(KeyCode.RIGHT),
          accel: keyboard.isPressed(KeyCode.UP),
          brake: keyboard.isPressed(KeyCode.DOWN)
      );
      
      world.step(_WORLD_STEP, 10, 10);
      camera.updatePos(carBody.position, carBody.getLinearVelocityFromLocalPoint(new Vector2.zero()), _WORLD_STEP);
      
      for (var sig in [-1.0, 1.0]) {
        if (carBody.position.y * sig > 10.0) {
          carBody.setTransform(carBody.position - new Vector2(.0,  10.0) * sig, carBody.angle);
          camera.pos.y -= sig * 10.0;
        }
      }
    }
    
    //clear
    context
      ..setFillColorRgb(255, 0, 0)
      ..fillRect(0, 0, width, height);

    /*world.drawDebugData();
    document.getElementById("log").text = "v ${(carBody.getLinearVelocityFromLocalPoint(new Vector2.zero()).length * 3.6).toStringAsFixed(0)}km/h";
    window.requestAnimationFrame(update);
    return;*/

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
        context.fillRect(x-1, y-1, 3, 3);
      }
    }
    context.translate(width/2, height/2);


    context
      ..scale(camera.zoom, camera.zoom);
    context.translate(- camera.pos.x, -camera.pos.y);

    //draw walls
    context.setFillColorRgb(255, 255, 255);
    for(Body b in wallBodies) {
      context.fillRect(b.position.x - wallSize.x / 2, b.position.y - wallSize.y / 2, wallSize.x, wallSize.y);
    }

    //draw car
    context.save();
    context.translate(carBody.position.x, carBody.position.y);
    context.rotate(carBody.angle);
    drawCar(context);
    context.restore();


    context.restore();

    document.getElementById("log").text = "speed ${(carBody.getLinearVelocityFromLocalPoint(new Vector2.zero()).length * 3.6).toStringAsFixed(0)}km/h";
    window.requestAnimationFrame(update);
  }

  void drawCar(CanvasRenderingContext2D context) {
    context
      ..save()
      ..lineWidth = 0.01
      ..setFillColorRgb(0, 255, 0)
      ..save()
      ..scale(Car.length, Car.width)
      ..drawImageScaled(carImage, -0.5, -0.5, 1.0, 1.0)
      ..restore()
      ;
    //tires
    context.setFillColorRgb(0, 255, 0);
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
}

void main() {
  CanvasElement canvas = querySelector("#canvas");

  Game game = new Game(canvas);
}


