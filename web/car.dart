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

  static const double length = 4.5;
  static const double width = 2.0;
  static const double weight = 1000.0;
  static const double g = 9.8;
  static const double aMomentum = (length * length + width * width) * weight / 12;
  static const double speed = 40.0;
  static const double angle = 20 * PI / 180;
  
  
  Vector2 pos = new Vector2.zero(), v = new Vector2.zero();
  double a = 0.0, va = 0.0;
  static final Vector2 fl = new Vector2(0.45*length, -0.45*width);
  static final Vector2 fr = new Vector2(0.45*length, 0.45*width);
  static final Vector2 rl = new Vector2(-0.45*length, -0.45*width);
  static final Vector2 rr = new Vector2(-0.45*length, 0.45*width);
  double fangle = 0.0;
  
  void updatePos(num dt, {bool turnLeft, bool turnRight, bool accel, bool brake}) {
    fangle = turnLeft == turnRight ? 0.0 : (turnLeft ? angle : -angle);
    final double defaultFSpeed = v.x / cos(fangle);
    final double rspeed = accel ? speed : (brake ? -speed : v.x);
    final double fspeed = /*brake ? 0.0 :*/ defaultFSpeed;
    
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
<<<<<<< HEAD
    //we rotated so we have to adjust our speed
    //because it in local coordinates
    v = daRotMat * v;
    a += da;
=======
    var da = va * dt;
    a += da;
    v = new Matrix2.rotation(-da) * v;
>>>>>>> fcad1d8789cc7973430c9c137ec13c4969b7c310
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
