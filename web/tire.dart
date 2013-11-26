import 'package:unittest/unittest.dart';
import 'package:vector_math/vector_math.dart';
import 'dart:math' as math;

class Tire {
  static const double bestGrip = 4.0;
  static const double worstGrip = 2.0;
  static const double bestDrift = 0.1;
  static const double worstDrift = 0.3;
  static const double longitudeFactor = 1.0;
  
  static const double minRoadSpeed = 4.0;
  Matrix2 applyFactor;
  Matrix2 removeFactor;
  
  
  Tire() {
    applyFactor = new Matrix2(1.0, 0.0, 0.0, longitudeFactor);
    removeFactor = applyFactor.clone();
    removeFactor.invert();
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
  
  Vector2 response(Vector2 roadSpeed, double wheelSpeed) {
    Vector2 driftSpeed = new Vector2(roadSpeed.x - wheelSpeed, roadSpeed.y);
    
    Vector2 roadSpeedf = applyFactor.transformed(roadSpeed);
    Vector2 driftSpeedf = applyFactor.transformed(driftSpeed);
    
    double roadSpeedD = math.max(roadSpeedf.length, minRoadSpeed);
    double doubleDrift = driftSpeedf.length / roadSpeedD;
   
    double doubleResponse = _doubleResponse(doubleDrift);
    
    Vector2 driftDirection = driftSpeedf.normalized();
    Vector2 responsef = driftDirection.scaled(-doubleResponse);
    
    Vector2 response = removeFactor.transformed(responsef);
    return response;
  }
}


main() {
  var tire = new Tire();
  
  test('no response at 0 speed', () {
    Vector2 roadSpeed = new Vector2.zero();
    double wheelSpeed = 0.0;
    Vector2 response = tire.response(roadSpeed, wheelSpeed);
    expect(response.x, 0.0, reason: "x response");
    expect(response.y, 0.0, reason: "y response");
  });
  
  test('grip at high longitudinal speed', () {
    Vector2 roadSpeed = new Vector2(50.0, 0.0);
    double wheelSpeed = 0.0;
    Vector2 response = tire.response(roadSpeed, wheelSpeed);
    expect(response.x, -Tire.worstGrip, reason: "x response");
    expect(response.y, 0.0, reason: "y response");
  });
  
  test('grip at high lateral speed', () {
    Vector2 roadSpeed = new Vector2(0.0, -50.0);
    double wheelSpeed = 0.0;
    Vector2 response = tire.response(roadSpeed, wheelSpeed);
    expect(response.x, 0.0, reason: "x response");
    expect(response.y, Tire.worstGrip / Tire.longitudeFactor, reason: "y response");
  });
  
  
}