library car;

import 'tire.dart';
import 'tire2.dart';
import 'dart:math';
import 'package:vector_math/vector_math.dart';
import 'package:unittest/unittest.dart';

class ImpulseAndMomentum {
  final Vector2 impulse;
  final double momentum;
  const ImpulseAndMomentum(this.impulse, this.momentum);
}

class TirePosAndAngle {
  final Vector2 pos;
  final num angle;
  const TirePosAndAngle(this.pos, this.angle);
}

class Car {
  final Tire tire = new Tire();

  static const double imageRatio = 4.5 / 500;
  static const double length = 500 * imageRatio;
  static const double width = 238 * imageRatio;
  static const double frontWheels = 170 * imageRatio;
  static const double rearWheels = -145 * imageRatio;
  static const double lateralWheels = 90 * imageRatio;
  static const double weight = 1000.0;
  static const double g = 9.8;
  static const double aMomentum = (length * length + width * width) * weight / 12;
  static const double power = 141e3;//W
  static const double rearSpeedThreshold = 4.0;
  static double angle = 40 * PI / 180;
  
  
  Vector2 pos = new Vector2.zero(), v = new Vector2.zero();
  double a = 0.0, va = 0.0;
  static final Vector2 fl = new Vector2(frontWheels, -lateralWheels);
  static final Vector2 fr = new Vector2(frontWheels, lateralWheels);
  static final Vector2 rl = new Vector2(rearWheels, -lateralWheels);
  static final Vector2 rr = new Vector2(rearWheels, lateralWheels);
  double fangle = 0.0;
  
  void updatePos(num dt, {bool turnLeft, bool turnRight, bool accel, bool brake}) {
    fangle = turnLeft == turnRight ? 0.0 : (turnLeft ? angle : -angle);
    double rspeed, fspeed;
    double accelPlusBrake = 0.0;
    if (accel) {
      accelPlusBrake+= 1.0;
    }
    if (brake) {
      accelPlusBrake-= 1.0;
    }
    
    final double defaultFSpeed = v.x / cos(fangle);  
    if (accelPlusBrake == 0.0) {
      rspeed = v.x;
      fspeed = defaultFSpeed;
    } else {
      //brake if:
      //braking and going faster that rearSpeedThreshold
      //accelerating and going faster backward than rearSpeedThreshold
      if (accelPlusBrake * (v.x + accelPlusBrake * rearSpeedThreshold) < 0) {
        rspeed = 0.0;
        fspeed = 0.0;
      } else {
        fspeed = defaultFSpeed;

        double dvx = accelPlusBrake * Tire.bestDrift;
        if (v.x != 0) {
          //if power is an issue, we are on the part of the curve where tireForce = dvx / Tire.bestDrift * Tire.bestGrip
          const int poweredWheelsCount = 2;
          double dvxAtMaxPower = power / poweredWheelsCount / weight / v.x.abs() * Tire.bestDrift / Tire.bestGrip;
          if (dvx.abs() > dvxAtMaxPower) {
            dvx = dvx.clamp(-dvxAtMaxPower, dvxAtMaxPower);
          }
        }
        rspeed = v.x + dvx;
      }
    }
    
    Vector2 impulse = new Vector2.zero();
    double momentum = 0.0;
    ImpulseAndMomentum imfl = updatePosForTire(dt, fl, fspeed, fangle);
    impulse += imfl.impulse;
    momentum += imfl.momentum;
    ImpulseAndMomentum imfr = updatePosForTire(dt, fr, fspeed, fangle);
    impulse += imfr.impulse;
    momentum += imfr.momentum;
    ImpulseAndMomentum imrl = updatePosForTire(dt, rl, rspeed, 0.0);
    impulse += imrl.impulse;
    momentum += imrl.momentum;
    ImpulseAndMomentum imrr = updatePosForTire(dt, rr, rspeed, 0.0);
    impulse += imrr.impulse;
    momentum += imrr.momentum;

    v += impulse / weight;
    va += momentum / aMomentum;
    double da = va * dt;
    Matrix2 rotMat = new Matrix2.rotation(a);
    Matrix2 daRotMat = new Matrix2.rotation(-da);
        
    pos += rotMat * v * dt;
    //we rotated so we have to adjust our speed
    //because it is in local coordinates
    v = daRotMat * v;
    a += da;
  }
  
  ImpulseAndMomentum updatePosForTire(num dt, Vector2 pos, double wheelSpeed, double angle) {
    Matrix2 rotToTire = new Matrix2.rotation(-angle);
    Matrix2 rotFromTire = new Matrix2.rotation(angle);
    Matrix2 vaMat = new Matrix2(0.0, va, -va, 0.0);
    Vector2 speed = v + vaMat * pos;
    Vector2 tireSpeed = rotToTire * speed;
    //print('${pos.x.toStringAsFixed(1)} ${pos.y.toStringAsFixed(1)}  ${tireSpeed.y.toStringAsFixed(3)}');
    Vector2 tireResponse = tire.response(tireSpeed, wheelSpeed, weight / 4);
    Vector2 tireImpulse = tireResponse * (dt * g);
    Vector2 impulse = rotFromTire * tireImpulse;
    
    double momentum = pos.cross(impulse);
    return new ImpulseAndMomentum(impulse, momentum);
  }
  
  List<TirePosAndAngle> get tiresAndPos {
    return [
      new TirePosAndAngle(fl, fangle),
      new TirePosAndAngle(fr, fangle),
      new TirePosAndAngle(rl, 0.0),
      new TirePosAndAngle(rr, 0.0)
    ];
  }
}

void main() {
  test('no response at 0 speed', () {
    Car car = new Car();
    car.updatePos(1.0, turnLeft: false, turnRight: false, accel: false, brake: false);
    expect(car.v.x, 0.0, reason: "vx");
    expect(car.v.y, 0.0, reason: "vy");
  });
  
  test('non null speed with accel true', () {
    Car car = new Car();
    car.updatePos(1.0, turnLeft: false, turnRight: false, accel: true, brake: false);
    expect(car.v.x, greaterThan(0.0), reason: "vx positive");
    expect(car.v.y, 0.0, reason: "vy");
    expect(car.pos.x, greaterThan(0.0), reason: "x positive");
    expect(car.pos.y, 0.0, reason: "y 0");
    
  });
}
