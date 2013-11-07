utils.signedArea = (p0, p1, p2) ->
  return (p0.x-p2.x)*(p1.y () - p2.y ())-(p1.x-p2.x)*(p0.y-p2.y)

utils.localfindIntersection = (u0, u1, v0, v1,w) ->
  if (u1 < v0) or (u0 > v1)
    return 0;
  if u1 > v0
    if u0 < v1 
      w[0] = if u0 < v0 then v0 else u0
      w[1] = if u1 > v1 then v1 else u1
      return 2
    else
      w[0] = u0
      return 1
  else
    w[0] = u1
    return 1

utils.dist = (p1, p2) ->
  Math.sqrt((p1.x - p2.x)*(p1.x - p2.x) + (p1.y - p2.y)*(p1.y - p2.y))

utils.findIntersection = (seg0, seg1, pi0, pi1) ->
  p0 = seg0.s
  d0 = 
    x: seg0.t.x - p0.x
    y: seg0.t.y - p0.y
  p1 = seg1.s
  d1 = 
    x: seg1.t.x - p1.x
    y: seg1.t.y - p1.y
  sqrEpsilon = 0.0000001
  E =
    x: p1.x - p0.x
    y: p1.y - p0.y
  kross = d0.x*d1.y - d0.y*d1.x
  sqrKross = kross * kross
  sqrLen0 = d0.x*d0.x + d0.y*d0.y
  sqrLen1 = d1.x*d1.x + d1.y*d1.y

  if sqrKross > sqrEpsilon*sqrLen0*sqrLen1
    # lines of the segments are not parallel
    s = (E.x*d1.y - E.y*d1.x)/kross
    if s < 0 or s > 1
      # No Intersections
      return 0
    t = (E.x*d0.y - E.y*d0.x)/kross
    if t < 0 or t > 1
      # No Intersections
      return 0
    # intersection of lines is a point an each segment
    pi0 = 
      x: p0.x + s*d0.x
      y: p0.y + s*d0.y
    if utils.dist(pi0, seg0.s) < 0.00000001
      pi0 = seg0.s
    if utils.dist(pi0, seg0.t) < 0.00000001
      pi0 = seg0.t
    if utils.dist(pi0, seg1.s) < 0.00000001
      pi0 = seg1.s
    if utils.dist(pi0, seg1.t) < 0.00000001
      pi0 = seg1.t
    return 1

  # Lines of the segments are parallel
  sqrLenE = E.x*E.x + E.y*E.y
  kross = E.x*d0.y - E.y*d0.x
  sqrKross = kross * kross
  if sqrKross > sqrEpsilon * sqrLen0 * sqrLenE
    # lines of the segment are different
    return 0

  # Lines of the segments are the same. Need to test for overlap of segments.
  s0 = (d0.x*E.x + d0.y*E.y)/sqrLen0  # so = Dot (D0, E) * sqrLen0
  s1 = s0 + (d0.x*d1.x + d0.y*d1.y)/sqrLen0  # s1 = s0 + Dot (D0, D1) * sqrLen0
  smin = Math.min(s0, s1)
  smax = Math.max(s0, s1)
  w = []
  imax = utils.localfindIntersection(0.0, 1.0, smin, smax, w)
  if imax > 0
    pi0 = 
      x: p0.x + w[0]*d0.x 
      y: p0.y + w[0]*d0.y
    if utils.dist(pi0, seg0.s) < 0.00000001
      pi0 = seg0.s
    if utils.dist(pi0, seg0.t) < 0.00000001
      pi0 = seg0.t
    if utils.dist(pi0, seg1.s) < 0.00000001
      pi0 = seg1.s
    if utils.dist(pi0, seg1.t) < 0.00000001
      pi0 = seg1.t
    if (imax > 1)
      pi1 = 
        x: p0.x + w[1]*d0.x
        y: p0.y + w[1]*d0.y
  return imax

module.exports = utils