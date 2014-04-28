import 'dart:html';
import 'car_physics.dart';
import 'car.dart';
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
  
  List<Car> cars = [];
  static const int BOT_COUNT = 6;
 
  List<Body> wallBodies = [];
  static final Vector2 WALL_SIZE = new Vector2(1.0, 300.0);
  static const double PHYSICS_WORLD_WRAP = 100.0;
  static const double LOOSING_DISTANCE = 50.0;
  
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
  static const double START_SPACE_BETWEEN_CARS = CarPhysics.width * 2;

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
    bd.angle = PI / 2;
    CarController h1 = new KeyboardController(
        keyboard,
        KeyCode.UP,
        KeyCode.LEFT,
        KeyCode.DOWN,
        KeyCode.RIGHT
    );
    cars.add(new Car(world.createBody(bd), h1));
    //car2 = new Car(world.createBody(bd));
    for (var i = 0; i < BOT_COUNT; i++) {
      cars.add(new Car(world.createBody(bd), new BotController()));
    }
    //place cars
    //even lines are | * * * |
    //odd  lines are |  * *  |
    //int carsPerEvenLine = ((TRACK_WIDTH - START_SPACE_BETWEEN_CARS) / (2 * START_SPACE_BETWEEN_CARS)).floor();
    //int evenOddCount = (cars.length / (carsPerEvenLine + carsPerEvenLine - 1)).round();
    for (var i = 0; i < cars.length; i++) {
      Car c = cars[i];
      double x = (i.toDouble() - 0.5 * (cars.length - 1)) * START_SPACE_BETWEEN_CARS;
      c.body.setTransform(new Vector2(x, 0.0), PI/2.0);
      c.color = (360 * i / cars.length).round();
    }
    
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
      cars.forEach((c) => c.body.createFixture(fd));
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
    Car first = Car.getFirst(cars);
    double quarter_screen = canvasHeight / camera.zoom * 0.25;
    PosAndSpeed result = new PosAndSpeed(new Vector2(0.0, first.body.position.y - quarter_screen), first.body.getLinearVelocityFromLocalPoint(new Vector2.zero()));
    return result;
    /*PosAndSpeed result = new PosAndSpeed(new Vector2.zero(), new Vector2.zero());
    cars.forEach((c) {
      result.pos += c.body.position / cars.length.toDouble();
      result.speed += c.body.getLinearVelocityFromLocalPoint(new Vector2.zero()) / cars.length.toDouble();
    });
    return result;*/
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
      Car.applyForcesForAll(cars);
            
      world.step(_WORLD_STEP, 10, 10);
      PosAndSpeed allCarsCenter = _getCameraTarget();
      camera.updatePos(allCarsCenter.pos, allCarsCenter.speed, _WORLD_STEP);
      
      //lose and win
      Car.applyLooseWin(cars);
      
      //WORLD_WRAP
      Car first = Car.getFirst(cars);
      for (var sig in [-1.0, 1.0]) {
        if (first.body.position.y * sig > PHYSICS_WORLD_WRAP) {
          cars.forEach((c) {
            c.body.setTransform(c.body.position - new Vector2(.0,  PHYSICS_WORLD_WRAP) * sig, c.body.angle);
          });
          camera.pos.y -= sig * PHYSICS_WORLD_WRAP;
        }
      }      
    }
    
    //clear
    canvasContext
      ..setFillColorRgb(40, 40, 40)
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
    cars.forEach((c) {
      canvasContext.save();
      canvasContext.translate(c.body.position.x, c.body.position.y);
      canvasContext.rotate(c.body.angle);
      drawCar(canvasContext, c);
      canvasContext.restore();
    });


    canvasContext.restore();

    document.getElementById("log").text = """
       speed ${cars.map((car) =>(car.body.getLinearVelocityFromLocalPoint(new Vector2.zero()).length * 3.6).toStringAsFixed(0))}km/h
       scores ${cars.map((c)=>c.score)}
    """;
    window.requestAnimationFrame(update);
  }

  void drawCar(CanvasRenderingContext2D context, Car car) {
    context
      ..save()
      ..scale(CarPhysics.length, CarPhysics.width)
      ..drawImageScaled(carImage, -0.5, -0.5, 1.0, 1.0)
      ..restore()
      ;
    context
        ..setFillColorHsl(car.color, 100, 50)
        ..fillRect(-CarPhysics.length / 8, -CarPhysics.width / 8, CarPhysics.length / 4, CarPhysics.width / 4);
    //tires
    /*context.setFillColorRgb(0, 255, 0);
    carPhysics.tiresAndPos.forEach((tireAndPos) {
      context
        ..save()
        ..translate(tireAndPos.pos.x, tireAndPos.pos.y)
        ..rotate(tireAndPos.angle)
        ..fillRect(-CarPhysics.length / 30, -CarPhysics.width / 50, CarPhysics.length / 15, CarPhysics.width / 25)
        ..restore();
    });*/
  }
}

void main() {
  CanvasElement canvas = querySelector("#canvas");

  Game game = new Game(canvas);
}


