import 'dart:html';
import 'car_physics.dart';
import 'keyboard.dart';
import 'package:vector_math/vector_math.dart';
import 'dart:math';
import 'package:box2d/box2d.dart';
import 'package:box2d/box2d_browser.dart';


class Camera {
  Vector2 pos = new Vector2.zero();
  Vector2 speed = new Vector2.zero();
  double zoom = 8.0;
  static const num _TRACKING = 4.0e-1 * 4;//m.s-2 / m     1g at 10m
  static num _DUMPING = 2 * sqrt(_TRACKING);//m.s-2 / m.s-1   1 g at 10m.s-1

  void updatePos(Vector2 target, Vector2 targetSpeed, double dt) {
    speed += ((target - pos) * Camera._TRACKING - (speed - targetSpeed) * Camera._DUMPING) * dt;
    pos += speed * dt;
  }
}

class PosAndSpeed {
  Vector2 pos;
  Vector2 speed;
  PosAndSpeed(this.pos, this.speed);
}

class Game {
  final Keyboard keyboard;

  final World world = new World(new Vector2(.0, .0), false, new DefaultWorldPool());
  final CarPhysics carPhysics = new CarPhysics();
  Body carBody;
  Body botCarBody;
  List<Body> carBodies;
  List<Body> wallBodies = [];
  static final Vector2 WALL_SIZE = new Vector2(1.0, 300.0);
  static const double PHYSICS_WORLD_WRAP = 100.0;
  
  final Camera camera;
  final CanvasRenderingContext2D canvasContext;
  final int canvasWidth;
  final int canvasHeight;

  static const double WORLD_STEP = 0.05;
  
  final ImageElement carImage = new ImageElement(src: 'car.png');
  bool paused = false;
  bool firstIterationAfterPause = false;

  final NumberInputElement angleInput;

  num lastUpdateTime = null;

  static const num _WORLD_STEP = 1 / 60;
  static const num _VELOCITY_ITERATIONS = 1 / 60;
  static const num _POSITION_ITERATIONS = 1 / 60;
    
  static const double TRACK_WIDTH = 30.0;

  Game(CanvasElement canvas):
    keyboard = new Keyboard(),
    canvasContext = canvas.getContext("2d"),
    canvasWidth = canvas.width,
    canvasHeight = canvas.height,
    angleInput = document.getElementById("steering"),
    camera = new Camera() {
    
    //car
    BodyDef bd = new BodyDef();
    bd.type = BodyType.DYNAMIC;
    bd.position = new Vector2(-1.0, .0);
    bd.angle = PI / 2;
    carBody = world.createBody(bd);
    bd.position = new Vector2(1.0, 0.0);
    botCarBody = world.createBody(bd);
    carBodies = [carBody, botCarBody];
    
    List<PolygonShape> shapes = CarPhysics.getShapes();
    double totalSurface = shapes.fold(0.0, (s, fd) {
      MassData md = new MassData();
      fd.computeMass(md, 1);
      return s + md.mass;
    });
    for (PolygonShape sd in shapes) {
      FixtureDef fd = new FixtureDef();
      fd.shape = sd;
      fd.density = CarPhysics.weight / totalSurface;
      fd.restitution = 0.5;
      fd.friction = 0.1;
      carBodies.forEach((b) => b.createFixture(fd));
    }
    
    //wall
    for (double offset in [-TRACK_WIDTH / 2.0, TRACK_WIDTH / 2.0]) {
      PolygonShape wallShape = new PolygonShape();
      wallShape.setAsBox(WALL_SIZE.x * 0.5, WALL_SIZE.y * 0.5);
      BodyDef wbd = new BodyDef();
      wbd.position = new Vector2(offset, 0.0);
      Body wallBody = world.createBody(wbd);
      wallBody.createFixtureFromShape(wallShape);
      wallBodies.add(wallBody);
    }
    
    camera.pos = _getCameraTarget().pos;
    
    Vector2 extents = new Vector2(canvas.width / 2, canvas.height / 2);
    CanvasViewportTransform viewport = new CanvasViewportTransform(extents, extents);
    CanvasDraw debugDraw = new CanvasDraw(viewport, canvasContext);
    world.debugDraw = debugDraw;
    
    window.onKeyDown.forEach((event) {
      int keycode = event.keyCode;
      if (event.keyCode == 80) {//'p'
        paused = !paused;
        firstIterationAfterPause = true;
        window.requestAnimationFrame(update);
      }
    });

    angleInput.value = (CarPhysics.angle / PI * 180).toStringAsFixed(1);
    angleInput.onChange.forEach((event) {
      CarPhysics.angle = double.parse(angleInput.value) / 180 * PI;
    });

    window.requestAnimationFrame(this.update);
  }
  
  static const double _WORLD_STEP_MS = _WORLD_STEP * 1000;
    
  PosAndSpeed _getCameraTarget() {
    PosAndSpeed result = new PosAndSpeed(new Vector2.zero(), new Vector2.zero());
    carBodies.forEach((b) {
      result.pos += b.position / carBodies.length.toDouble();
      result.speed += b.getLinearVelocityFromLocalPoint(new Vector2.zero()) / carBodies.length.toDouble();
    });
    return result;
  }
  
  update(num time) {
    if (paused) {return;}
    if (lastUpdateTime == null || firstIterationAfterPause) {
      lastUpdateTime = time;
      firstIterationAfterPause = false;
    }
    int nbStep = ((time - lastUpdateTime) / _WORLD_STEP_MS).floor();
    lastUpdateTime += _WORLD_STEP_MS * nbStep;
    for (var i = 0; i < nbStep; i++) {
      carPhysics.applyForces(carBody, [botCarBody], turnLeft: keyboard.isPressed(KeyCode.LEFT),
          turnRight: keyboard.isPressed(KeyCode.RIGHT),
          accel: keyboard.isPressed(KeyCode.UP),
          brake: keyboard.isPressed(KeyCode.DOWN)
      );
      bool botLeft, botRight;
     Vector2 botSpeed = botCarBody.getLinearVelocityFromLocalPoint(new Vector2.zero());
     botLeft = botSpeed.x > 0 && botCarBody.position.x > 0.3 * TRACK_WIDTH;
     botRight = botSpeed.x < 0 && botCarBody.position.x < -0.3 * TRACK_WIDTH;
     carPhysics.applyForces(botCarBody, [carBody], turnLeft: botLeft,
          turnRight: botRight,
          accel: true,
          brake: false
      );
            
      world.step(_WORLD_STEP, 10, 10);
      PosAndSpeed cameraTarget = _getCameraTarget();
      camera.updatePos(cameraTarget.pos, cameraTarget.speed, _WORLD_STEP);
      
      for (var sig in [-1.0, 1.0]) {
        if (carBody.position.y * sig > PHYSICS_WORLD_WRAP) {
          carBodies.forEach((b) {
            b.setTransform(b.position - new Vector2(.0,  PHYSICS_WORLD_WRAP) * sig, b.angle);
          });
          camera.pos.y -= sig * PHYSICS_WORLD_WRAP;
        }
      }
    }
    
    //clear
    canvasContext
      ..setFillColorRgb(255, 0, 0)
      ..fillRect(0, 0, canvasWidth, canvasHeight);

    /*world.drawDebugData();
    document.getElementById("log").text = "v ${(carBody.getLinearVelocityFromLocalPoint(new Vector2.zero()).length * 3.6).toStringAsFixed(0)}km/h";
    window.requestAnimationFrame(update);
    return;*/

    canvasContext
      ..save()
      ..translate(0.0, canvasHeight)
      ..scale(1.0, -1.0);


    //draw dots
    const double dotDist = 10.0;
    double zoomedDotDist = dotDist * camera.zoom;
    canvasContext.setFillColorRgb(0, 0, 255);
    for (var x = -camera.zoom * camera.pos.x % zoomedDotDist; x < canvasWidth; x+= zoomedDotDist) {
      for (var y = -camera.zoom * camera.pos.y % zoomedDotDist; y < canvasHeight; y+= zoomedDotDist) {
        canvasContext.fillRect(x-1, y-1, 3, 3);
      }
    }
    canvasContext.translate(canvasWidth/2, canvasHeight/2);


    canvasContext
      ..scale(camera.zoom, camera.zoom);
    canvasContext.translate(- camera.pos.x, -camera.pos.y);

    //draw walls
    canvasContext.setFillColorRgb(255, 255, 255);
    for(Body b in wallBodies) {
      canvasContext.fillRect(b.position.x - WALL_SIZE.x / 2, b.position.y - WALL_SIZE.y / 2, WALL_SIZE.x, WALL_SIZE.y);
    }

    //draw car
    carBodies.forEach((b) {
      canvasContext.save();
      canvasContext.translate(b.position.x, b.position.y);
      canvasContext.rotate(b.angle);
      drawCar(canvasContext);
      canvasContext.restore();
    });


    canvasContext.restore();

    document.getElementById("log").text = "speed ${(carBody.getLinearVelocityFromLocalPoint(new Vector2.zero()).length * 3.6).toStringAsFixed(0)}km/h";
    window.requestAnimationFrame(update);
  }

  void drawCar(CanvasRenderingContext2D context) {
    context
      ..save()
      ..lineWidth = 0.01
      ..setFillColorRgb(0, 255, 0)
      ..save()
      ..scale(CarPhysics.length, CarPhysics.width)
      ..drawImageScaled(carImage, -0.5, -0.5, 1.0, 1.0)
      ..restore()
      ;
    //tires
    context.setFillColorRgb(0, 255, 0);
    carPhysics.tiresAndPos.forEach((tireAndPos) {
      context
        ..save()
        ..translate(tireAndPos.pos.x, tireAndPos.pos.y)
        ..rotate(tireAndPos.angle)
        ..fillRect(-CarPhysics.length / 30, -CarPhysics.width / 50, CarPhysics.length / 15, CarPhysics.width / 25)
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


