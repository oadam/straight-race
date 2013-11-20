import 'package:unittest/unittest.dart';
import 'package:vector_math/vector_math.dart';

class Tire {
  final double bestGrip;
  /**slip over speed ratio at best grip (ie 10%)*/
  final double bestDrift;
  final double worstGrip;
  final double worstDrift;
  final double longitudeFactor;
  Matrix2 applyFactor;
  Matrix2 removeFactor;
  
  
  Tire(this.bestGrip, this.bestDrift, this.worstGrip, this.worstDrift, this.longitudeFactor) {
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
    
    double doubleDrift;
    if (roadSpeedf.length2 == 0.0){
      doubleDrift = bestGrip;
    } else {
      doubleDrift = driftSpeedf.length / roadSpeedf.length;
    }
    double doubleResponse = _doubleResponse(doubleDrift);
    
    Vector2 driftDirection = driftSpeedf.normalized();
    Vector2 responsef = driftDirection.scaled(-doubleResponse);
    
    Vector2 response = removeFactor.transformed(responsef);
    return response;
  }
}


main() {
  const double bestGrip = 1.0;
  const double bestDrift = 0.1;
  const double worstGrip = 0.5;
  const double worstDrift = 0.5;
  const double longitudeFactor = 2.0;
  var tire = new Tire(bestGrip, bestDrift, worstGrip, worstDrift, longitudeFactor);
  
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
    expect(response.x, -worstGrip, reason: "x response");
    expect(response.y, 0.0, reason: "y response");
  });
  
  test('grip at high lateral speed', () {
    Vector2 roadSpeed = new Vector2(0.0, -50.0);
    double wheelSpeed = 0.0;
    Vector2 response = tire.response(roadSpeed, wheelSpeed);
    expect(response.x, 0.0, reason: "x response");
    expect(response.y, worstGrip / longitudeFactor, reason: "y response");
  });
  
  
}