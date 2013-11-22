import 'tire.dart';
import 'dart:math';
import 'package:vector_math/vector_math.dart';
import 'package:unittest/unittest.dart';

class ImpulseAndMomentum {
  final Vector2 impulse;
  final double momentum;
  ImpulseAndMomentum(this.impulse, this.momentum);
}

class Car {
  static const double bestGrip = 1.0;
  static const double worstGrip = 0.5;
  static const double bestDrift = 0.1;
  static const double worstDrift = 0.3;
  static const double longitudeFactor = 3.0;
  final Tire tire = new Tire(bestGrip, bestDrift, worstGrip, worstDrift, longitudeFactor);

  static const double length = 4.5;
  static const double width = 2.0;
  static const double weight = 1000.0;
  static const double aMomentum = (length * length + width * width) * weight / 12;
  static const double speed = 20.0;
  static const double angle = 20 * PI / 180;
  
  Vector2 pos = new Vector2.zero(), v = new Vector2.zero();
  double a = 0.0, va = 0.0;
  static final Vector2 fl = new Vector2(0.45*length, -0.45*width);
  static final Vector2 fr = new Vector2(0.45*length, 0.45*width);
  static final Vector2 rl = new Vector2(-0.45*length, -0.45*width);
  static final Vector2 rr = new Vector2(-0.45*length, 0.45*width);
  
  void updatePos(num dt, {bool turnLeft, bool turnRight, bool accel, bool brake}) {
    final double rspeed = accel ? speed : (brake ? 0.0 : v.x);
    final double fspeed = brake ? 0.0 : v.x;
    final double fangle = turnLeft == turnRight ? 0.0 : (turnLeft ? angle : -angle);
    
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
  }
  
  ImpulseAndMomentum updatePosForTire(num dt, Vector2 pos, double wheelSpeed, double angle) {
    Matrix2 rotMat = new Matrix2.rotation(-angle);
    Vector2 speedForTire = rotMat * v;
    Vector2 response = tire.response(speedForTire, wheelSpeed);
    Vector2 impulse = response * (dt * weight / 4);
    double momentum = pos.cross(impulse);
    return new ImpulseAndMomentum(impulse, momentum);
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
  });
}
