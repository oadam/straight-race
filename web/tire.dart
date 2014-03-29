import 'package:unittest/unittest.dart';
import 'package:vector_math/vector_math.dart';
import 'dart:math' as math;

class Tire {
  static const double bestGrip = 3.0;
  static const double worstGrip = 2.0;
  static const double bestDrift = 0.1*10;
  static const double worstDrift = 0.3*10;
  static const double longitudeFactor = 2.0;
  
  static const double minRoadSpeed = 1.0;
  Matrix2 _applyFactor;
  Matrix2 _removeFactor;
  
  
  Tire() {
    _applyFactor = new Matrix2(1.0, 0.0, 0.0, longitudeFactor);
    _removeFactor = _applyFactor.clone();
    _removeFactor.invert();
  }
  
  double _doubleResponse(double drift) {
    assert(drift >= 0);
    if (drift < bestDrift) {
      return bestGrip * drift / bestDrift;
    } else if(drift < worstDrift) {
      return bestGrip + (worstGrip - bestGrip) * (drift - bestDrift) / (worstDrift - bestDrift); 
    } else {
      return worstGrip;
    }
  }
  
  Vector2 response(Vector2 roadSpeed, double wheelSpeed, double fz) {
    Vector2 driftSpeed = new Vector2(roadSpeed.x - wheelSpeed, roadSpeed.y);
    
    Vector2 roadSpeedf = _applyFactor.transformed(roadSpeed);
    Vector2 driftSpeedf = _applyFactor.transformed(driftSpeed);
    
    double roadSpeedD = math.max(roadSpeedf.length, minRoadSpeed);
    double doubleDrift = driftSpeedf.length;// / roadSpeedD;
   
    double doubleResponse = _doubleResponse(doubleDrift);
    
    Vector2 driftDirection = driftSpeedf.normalized();
    Vector2 responsef = driftDirection.scaled(-doubleResponse);
    
    Vector2 response = _removeFactor.transformed(responsef);
    return response.scaled(fz);
  }
}


main() {
  var tire = new Tire();
 
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
        Vector2 roadSpeed = new Vector2(0.0, -50.0);
        double wheelSpeed = 0.0;
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
            Vector2 roadSpeed = new Vector2(-50.0, 0.0);
            double wheelSpeed = 45.0;
            const fz = 2500.0;
            Vector2 response = tire.response(roadSpeed, wheelSpeed, fz);
            expect(response.x, greaterThan(0.0), reason: "x response");
            expect(response.y, isVeryLow, reason: "y response");
     });
  
  
}