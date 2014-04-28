library car_physics;

import 'tire.dart';
import 'dart:math';
import 'package:vector_math/vector_math.dart';
import 'package:unittest/unittest.dart';
import 'package:box2d/box2d.dart';

class ImpulseAndMomentum {
  final Vector2 impulse;
  final double momentum;
  const ImpulseAndMomentum(this.impulse, this.momentum);
}

class PosAndAngle {
  final Vector2 pos;
  final num angle;
  const PosAndAngle(this.pos, this.angle);
}

class CarControls {
  final bool turnLeft;
  final bool turnRight;
  final bool accelerate;
  final bool brake;
  const CarControls(this.turnLeft, this.turnRight, this.accelerate, this.brake);
}

class SvgShape {
    final String svg;
    ///Needed because Box2D wants vertices to be ordered anti-clockwise
    final bool reversed;
    const SvgShape(this.reversed, this.svg);
}

class CarPhysics {
  final Tire tire = new Tire();

  static const double imageRatio = 4.5 / 500;

  ///result of
  ///    grep " d=" carFixtures.svg
  static final List<SvgShape> svgShapes = [
    new SvgShape(false, "M 2.5714286,358.36218 15.285714,319.50504 57.000002,297.79076 109.00718,288.49068 109.71429,501.07647 57.571431,492.79075 16.428571,475.50504 1.4999998,422.43361 z"),
    new SvgShape(false, "m 409.27854,290.21215 44.41349,8.98564 24.6145,15.3496 20.27926,42.85069 1.41421,62.10696 -18.62886,49.40776 -25.07179,18.47092 -44.87078,10.69275 z"),
    new SvgShape(false, "m 300,294.14789 -6.78572,-18.57142 14.28572,2.5 13.21428,15.71429 z"),
    new SvgShape(true, "m 299.64285,494.50504 -6.78572,18.57142 14.28572,-2.5 13.21428,-15.71429 z"),
    new SvgShape(false, "m 109.60155,289.39399 67.88225,5.65685 -2.82843,199.40411 -64.34672,7.07106 z"),
    new SvgShape(false, "m 177.4838,295.05084 186.67617,-0.70711 0,199.40412 -186.67617,0 z"),
    new SvgShape(true, "m 407.2935,290.10109 -42.42641,4.24264 0.70711,199.40411 44.54772,3.53553 z"),
  ];
  static const double length = 500 * imageRatio;
  static const double width = 238 * imageRatio;
  static const double frontWheels = 170 * imageRatio;
  static const double rearWheels = -145 * imageRatio;
  static const double lateralWheels = 90 * imageRatio;
  static const double weight = 1000.0;
  static const double g = 9.8;
  static const double aMomentum = (length * length + width * width) * weight / 12;
  static const double power = 141e3;//W
  static const double maxSpeed = 50.0;//m.s-1
  //the power of airBrake is v * (airBrake * v^2)
  static const double airBrake = power / maxSpeed / maxSpeed / maxSpeed;
  ///Ratio between speed of a car and wind just behind it
  static const double MAX_WIND_SHIELD = 0.5;
///The speed under which we switch from braking to reverse gear
  static const double rearSpeedThreshold = 4.0;//m.s-1
  static double airBrakeAlpha0 = 10.0 * PI / 180;
  static double airBrakeD0ByV0 = 10.0 / (100.0 / 3.6);//10 meters at 100 km/h

  static double angle = 30 * PI / 180;
    
  
  static final Vector2 fl = new Vector2(frontWheels, -lateralWheels);
  static final Vector2 fr = new Vector2(frontWheels, lateralWheels);
  static final Vector2 rl = new Vector2(rearWheels, -lateralWheels);
  static final Vector2 rr = new Vector2(rearWheels, lateralWheels);
  double fangle = 0.0;
  
  static RegExp mTest = new RegExp(r"m ([\d.-]+,[\d.-]+ ?)+ z");
  static RegExp MTest = new RegExp(r"M ([\d.-]+,[\d.-]+ ?)+ z");
  static RegExp svgPointRegex = new RegExp(r"[\d.-]+,[\d.-]+");
    
  static List<PolygonShape> getShapes() {
    List<List<Vector2>> result = [];
    for (SvgShape svg in svgShapes) {
      Iterable<Match> pointsString = svgPointRegex.allMatches(svg.svg);
      List<Vector2> parsed = pointsString
          .map((Match match) => match[0].split(","))
          .map((coords) => new Vector2(double.parse(coords[0]), double.parse(coords[1])))
          .toList();
      List<Vector2> vertices;
      if (mTest.hasMatch(svg.svg)) {
        vertices = [parsed[0]];
        for (var i = 1; i < parsed.length; i++) {
          vertices.add(parsed[i] + vertices[i - 1]);
        }
      } else if (MTest.hasMatch(svg.svg)) {
        vertices = parsed;
      } else {
        throw "unknown shape format";
      }
      
      if (svg.reversed) {
        vertices = vertices.reversed.toList();
      }
      
      result.add(vertices);
    }
    
    List<Vector2> allVertices = [];
    for (List<Vector2> subList in result) {
      allVertices.addAll(subList);
    }
    Vector2 minV = allVertices.reduce((a, b) {
          return new Vector2(min(a.x, b.x), min(a.y, b.y));
    });
    Vector2 maxV = allVertices.reduce((a, b) {
          return new Vector2(max(a.x, b.x), max(a.y, b.y));
    });
     
    Vector2 size = maxV - minV;
    double ratio1 = size.y / size.x, ratio2 = width / length; 
    assert((ratio1/ratio2 - 1.0).abs() < 0.02);//1% match
    double svgRatio = length / size.x;
    Vector2 svgCenter = (maxV + minV) / 2.0;
    
    List<PolygonShape> shapes = [];
    for (List<Vector2> list in result) {
      List<Vector2> centered = list.map((v) => (v - svgCenter) * svgRatio).toList();
      PolygonShape shape = new PolygonShape();
      try {
        shape.setFrom(centered, centered.length);
      } catch (e) {
        throw 'Error for shape $list : $e';
      }
      shapes.add(shape);
    }
    return shapes;
  }
  
  void applyForces(Body body, Iterable<Body> otherCars, CarControls controls) {
    fangle = controls.turnLeft == controls.turnRight ? 0.0 : (controls.turnLeft ? angle : -angle);
    double rspeed, fspeed;
    double accelPlusBrake = 0.0;
    if (controls.accelerate) {
      accelPlusBrake+= 1.0;
    }
    if (controls.brake) {
      accelPlusBrake-= 1.0;
    }
    
    bool noTorqueR = false, noTorqueF = false;
    if (accelPlusBrake == 0.0) {
      rspeed = double.NAN;
      fspeed = double.NAN;
      noTorqueR = true;
      noTorqueF = true;
    } else {
      Vector2 worldVRear = body.getLinearVelocityFromLocalPoint(new Vector2(-rearWheels, 0.0));
      Vector2 localVRear = body.getLocalVector2(worldVRear);
      double vx = localVRear.x;
      //brake if:
      //braking and going faster that rearSpeedThreshold
      //accelerating and going faster backward than rearSpeedThreshold
      if (accelPlusBrake * (vx + accelPlusBrake * rearSpeedThreshold) < 0) {
        rspeed = 0.0;
        fspeed = 0.0;
      } else {
        fspeed = double.NAN;
        noTorqueF = true;

        double dvx = accelPlusBrake * Tire.bestDrift;
        if (vx != 0) {
          //if power is an issue, we are on the part of the curve where tireForce = dvx / Tire.bestDrift * Tire.bestGrip
          const int poweredWheelsCount = 2;
          double dvxAtMaxPower = power / poweredWheelsCount / weight / vx.abs() * Tire.bestDrift / Tire.bestGrip;
          if (dvx.abs() > dvxAtMaxPower) {
            dvx = dvx.clamp(-dvxAtMaxPower, dvxAtMaxPower);
          }
        }
        rspeed = vx + dvx;
      }
    }
    
    //air brake
    Vector2 vg = body.getLinearVelocityFromLocalPoint(new Vector2.zero());
    Iterable<Vector2> otherWinds = otherCars.map((c) {
      Vector2 deltaPos = c.position - body.position;
      Vector2 otherSpeed = c.getLinearVelocityFromLocalPoint(new Vector2.zero());
      double cosA;
      if (deltaPos.length == 0.0 || otherSpeed.length == 0.0) {
        cosA = -1.0;
      } else {
        cosA = deltaPos.dot(otherSpeed) / deltaPos.length / otherSpeed.length;
      }
      if (cosA < 0.0) {
        return new Vector2.zero();
      }
      double deltaPosCoef = MAX_WIND_SHIELD * exp(-deltaPos.length / otherSpeed.length / airBrakeD0ByV0);
      double alpha = acos(cosA);
      double alphaCoef = exp(-alpha / airBrakeAlpha0);
      return otherSpeed * deltaPosCoef * alphaCoef;
    });
    
    //ponderated mean
    double lengthSum = otherWinds.fold(0.0, (s, c) => s + c.length);
    Vector2 meanWind = lengthSum == 0.0 ? new Vector2.zero() : otherWinds.map((w) => w * w.length / lengthSum)
        .reduce((a, b) => a + b);
    Vector2 airSpeed = meanWind - vg;
    
    Vector2 fairBrake = airSpeed * airBrake * airSpeed.length;
    body.applyForce(fairBrake, body.getWorldPoint(new Vector2.zero()));
    
    applyForceForTire(body, fl, fspeed, fangle, noTorqueF);
    applyForceForTire(body, fr, fspeed, fangle, noTorqueF);
    applyForceForTire(body, rl, rspeed, .0, noTorqueR);
    applyForceForTire(body, rr, rspeed, .0, noTorqueR);
  }

  void applyForceForTire(Body body, Vector2 position, double wheelSpeed, double angle, bool noTorque) {
    Matrix2 rotToTire = new Matrix2.rotation(-angle);
    Matrix2 rotFromTire = new Matrix2.rotation(angle);
    Vector2 speed = body.getLocalVector2(body.getLinearVelocityFromLocalPoint(position));
    Vector2 tireSpeed = rotToTire * speed;
    
    if (noTorque) {
      wheelSpeed = tireSpeed.x;
    }
    Vector2 tireResponse = tire.response(tireSpeed, wheelSpeed, weight * g / 4);
    Vector2 response = rotFromTire * tireResponse;
    
    body.applyForce(body.getWorldVector2(response), body.getWorldPoint(position));
  }
  
  List<PosAndAngle> get tiresAndPos {
    return [
      new PosAndAngle(fl, fangle),
      new PosAndAngle(fr, fangle),
      new PosAndAngle(rl, 0.0),
      new PosAndAngle(rr, 0.0)
    ];
  }
}

void main() {

  test('getShapes', () {
    List<PolygonShape> result = CarPhysics.getShapes();
    expect(result.length, CarPhysics.svgShapes.length, reason: "Number of shapes");
    var g = new Vector2.zero();
    for (PolygonShape s in result) {
      Vector2 c = s.centroid;
      g+=c;
    }
    //expect(g.x/Car.length, closeTo(0.0, 0.02));
    expect(g.y, closeTo(0.0, 0.08 * CarPhysics.width));
  });
}
