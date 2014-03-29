library tire2;

import 'package:unittest/unittest.dart';
import 'package:vector_math/vector_math.dart';
import 'dart:math';
import 'tire.dart';

class Tire2 implements Tire {  
  
  Tire2() {
  }
  
  Vector2 response(Vector2 signedRoadSpeed, double signedWheelSpeed, double fz) {
    //see http://code.eng.buffalo.edu/dat/sites/tire/tire.html
    
    double signSwitch = signedRoadSpeed.x >= 0 ? 1.0 : -1.0;
    Vector2 roadSpeed = signedRoadSpeed.scaled(signSwitch);
    double wheelSpeed = signSwitch * signedWheelSpeed;
    
    double slip;
    if (roadSpeed.x == 0.0) {
      slip = wheelSpeed == 0.0 ? 0.0 : wheelSpeed > 0 ? 1.0 : -1.0;
    } else if (wheelSpeed == 0.0) {
      slip = roadSpeed.x > 0 ? -1.0 : 1.0;
    } else if (roadSpeed.x > wheelSpeed) {
      slip = (wheelSpeed - roadSpeed.x) / roadSpeed.x;
    } else {
      slip = (wheelSpeed - roadSpeed.x) / wheelSpeed;
    }
    double alpha = atan2(-roadSpeed.y, wheelSpeed);
    
    double ap0 = 0.0768 * sqrt(fz * 810) / 6 / (25 + 5);
    double a0 = 914.02;
    double csfz = 18.7;
    
    double ks = 2 / (ap0 * ap0) * a0;
    double kc = 2 / (ap0 * ap0) * fz * csfz;
    
    double mu0 = 0.85;
    double sigma = PI * ap0 * ap0 / (8 * mu0 * fz) * sqrt(pow(ks * tan(alpha), 2) + pow(kc * slip / (1.1/*TODO*/ - slip), 2));
    
    const double c1 = 1.0;
    const double c2 = 0.34;
    const double c3 = 0.57;
    const double c4 = 0.32;
    double fsigma = (c1 * pow(sigma, 3) + c2 * pow(sigma, 2) + 4 / PI * sigma) /
        (c1 * pow(sigma, 3) + c3 * pow(sigma, 2) + c4 * sigma + 1);
    
    const double kmu = 0.124;
    double mysqrt = sqrt(pow(sin(alpha), 2) + pow(slip * cos(alpha), 2));
    double kprimec = kc + (ks - kc) * mysqrt;
    double mu = mu0 * (1 - kmu * mysqrt);
    
    double mysecondsqrt = sqrt(pow(ks * tan(alpha), 2) + pow(kprimec * slip, 2));
    if (mysecondsqrt == 0.0) {mysecondsqrt = ks;}//TODO 
    double fx = mu * fz * fsigma * kprimec * slip / mysecondsqrt;
    double fy = mu * fz * fsigma * ks * tan(alpha) / mysecondsqrt;
    assert(!fx.isNaN);
    assert(!fy.isNaN);
    
    return new Vector2(fx, fy).scaled(signSwitch);
  }
}


main() {
  Tire tire = new Tire2();
  
  Matcher isVeryLow = closeTo(0.0, 1e-5);
  
  test('no error at 0 speed', () {
    Vector2 roadSpeed = new Vector2.zero();
    double wheelSpeed = 0.0;
    const fz = 2500.0;
    Vector2 response = tire.response(roadSpeed, wheelSpeed, fz);
    expect(response.x.isNaN, isFalse, reason: "x response");
    expect(response.y.isNaN, isFalse, reason: "y response");
  });
  
  test('grip at high longitudinal speed', () {
    Vector2 roadSpeed = new Vector2(50.0, 0.0);
    double wheelSpeed = 0.1;
    const fz = 2500.0;
    Vector2 response = tire.response(roadSpeed, wheelSpeed, fz);
    expect(response.x, lessThan(0.0), reason: "x response");
    expect(response.y, isVeryLow, reason: "y response");
  });
  
  test('grip at high lateral speed', () {
      Vector2 roadSpeed = new Vector2(0.1, -50.0);
      double wheelSpeed = 0.1;
      const fz = 2500.0;
      Vector2 response = tire.response(roadSpeed, wheelSpeed, fz);
      expect(response.x, isVeryLow, reason: "x response");
      expect(response.y, greaterThan(0.0), reason: "y response");
    });
  
  test('turning left at high speed', () {
    Vector2 roadSpeed = new Vector2(40.0, -10.0);
    double wheelSpeed = 40.0;
    const fz = 2500.0;
    Vector2 response = tire.response(roadSpeed, wheelSpeed, fz);
    expect(response.x, isVeryLow, reason: "x response");
    expect(response.y, greaterThan(0.0), reason: "y response");
  });
  
  test('grip when accelerating', () {
      Vector2 roadSpeed = new Vector2(50.0, 0.0);
      double wheelSpeed = 55.0;
      const fz = 2500.0;
      Vector2 response = tire.response(roadSpeed, wheelSpeed, fz);
      expect(response.x, greaterThan(0.0), reason: "x response");
      expect(response.y, isVeryLow, reason: "y response");
   });
  
  test('grip when breaking', () {
          Vector2 roadSpeed = new Vector2(50.0, 0.0);
          double wheelSpeed = 45.0;
          const fz = 2500.0;
          Vector2 response = tire.response(roadSpeed, wheelSpeed, fz);
          expect(response.x, lessThan(0.0), reason: "x response");
          expect(response.y, isVeryLow, reason: "y response");
    });
    
  test('accelerating when going backward', () {
          Vector2 roadSpeed = new Vector2(-5.0, 0.0);
          double wheelSpeed = 5.0;
          const fz = 2500.0;
          Vector2 response = tire.response(roadSpeed, wheelSpeed, fz);
          expect(response.x, greaterThan(0.0), reason: "x response");
          expect(response.y, isVeryLow, reason: "y response");
   });
    
}
