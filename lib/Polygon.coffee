_ = require('lodash')

#
#  The algorithm computes the clipped polygon in three phases. In the first phase it determines (and marks) the intersection points. The points are then inserted in both lists, in their proper place by ordering them using the alpha values. If no intersection points are found in this phase we know that either the subject polygon lies entirely inside the clip polygon or vice versa, or that both polygons are disjoint. By performing a containment test for any of the vertexes we are able to determine which case we have. Then we either return the inner polygon or nothing at all.
#  In order to efficiently implement this, the algorithm uses two doubly linked lists to represent the polygons. One list is for the clip and one for the subject polygon. In each list, a node represents a distinct vertex. Obviously, the lists will contain the x and y coordinates of the vertexes as well as the necessary links to the previous and next node in the list. In addition to these however, the algorithm needs some more information. 
#  
class ClipperNode
  #  NextPoly is a pointer to a new polygon, once the current one has been closed. Indeed, in the most general case, the result of the algorithm is a set of polygons rather than a single one, so that the lists that represent the polygons have to be linked together in order for polygons to be accessed from one to another.
  constructor: (@x, @y, @prev, @next, @nextPoly) ->
    #  Intersect is a boolean value that is set to true if the current node is an intersection point and to false otherwise. 
    @intersect = false
    @processed = false

    #  Similarly, entry is flag that records whether the intersecting point is an entry or an exit point to the other polygon's interior.
    @entry = false #true means entry, false means exit
    
    #  Neighbor is a link to the identical vertex in the "neighbor" list. An intersection node belongs, obviously, to both polygons and therefore has to be present in both lists of vertexes. However, in Phase III, when we generate the polygons from the list of resulting edges we want to be able to jump from one polygon to another (switch the current polygon). To enable that, the neighbor pointers keep track of the identical vertexes. In the same phase of building the polygons by navigating through the list of nodes, the visited flag is used to mark the nodes already inserted in the result (it is important to notice here that every intersection point belongs to the resulting polygon (since by definition it belongs to both interiors).
    @neighbor = null
    
    #  The alpha value is a floating point number from 0 to 1 that indicates the position of an intersection point reported to two consecutive non-intersection vertexes from the initial list of vertexes.
    @alpha = null


  getNext: () ->
    if @next.intersect
      return @next.getNext()
    @next

  getFirstIntersection: () ->
    if @intersect and not @processed
      return @
    else
      return @next.getFirstIntersection()

  insertIntersect: (i) ->
    old = @
    current = @next
    while current.intersect and current.alpha < i.alpha
      old = current
      current = current.next
    old.next = i
    i.prev = old
    i.next = current
    current.prev = i
    return

#
#  A Polygon is described by the ordered set of its vertices, P_0, P_1, P_2, ..., P_n = P_0. 
#  It consists of all line segments consecutively connecting the points P_i, i.e. P_0->P_1, P_1->P_2, ... P_n-1->P_n = P_n-1->P_0
#
class Polygon
  #  @points is an array of floats where the ith element is the x coordinate and i+1 is the y coordinate of the i/2th vertex
  #  @points.length >= 6 (2 points)
  #  @points.length % 2 == 0
  #  The Polygon has at @points.length/2.0 - 1 lines
  constructor: (@points) ->
    @num_points = @points.length/2

  get_nodes: ->
    nodes = new Array @points.length/2
    for i in [0...(@points.length/2)]
      nodes[i] = new ClipperNode @points[i*2], @points[i*2+1], nodes[i-1]
      if i != 0
        nodes[i-1].next = nodes[i]
    nodes[0].next = nodes[1]
    nodes[0].prev = nodes[nodes.length-1]
    nodes[nodes.length-1].next = nodes[0]
    nodes

  dist = (x1,y1,x2,y2) ->
    (x1 - x2)*(x1 - x2) + (y1 - y2)*(y1 - y2)

  # I(node *p1, node *p2, node *q1, node *q2, 
  #   float *alpha_p, float *alpha_q, int *xint, int *yint) 
  # { 
  #   float x, y, tp, tq, t, par;
  #   par = (float) ((p2->x - p1->x)*(q2->y - q1->y) - 
  #                  (p2->y - p1->y)*(q2->x - q1->x));
  #   if (!par) return 0;                               /* parallel lines */
  #   tp = ((q1->x - p1->x)*(q2->y - q1->y) - (q1->y - p1->y)*(q2->x - q1->x))/par; 
  #   tq = ((p2->y - p1->y)*(q1->x - p1->x) - (p2->x - p1->x)*(q1->y - p1->y))/par;
  #   if(tp<0 || tp>1 || tq<0 || tq>1) return 0;
  #   x = p1->x + tp*(p2->x - p1->x); 
  #   y = p1->y + tp*(p2->y - p1->y);
  #   *alpha_p = dist(p1->x, p1->y, x, y) / dist(p1->x, p1->y, p2->x, p2->y); 
  #   *alpha_q = dist(q1->x, q1->y, x, y) / dist(q1->x, q1->y, q2->x, q2->y); 
  #   *xint = (int) x; 
  #   *yint = (int) y;
  #   return 1; 
  # }
  clip_intersect = (p1, p2, q1, q2) ->  
    par = (p2.x - p1.x)*(q2.y - q1.y) - (q2.x-q1.x)*(p2.y - p1.y)
    if not par 
      return false
    tp = ((q1.x - p1.x)*(q2.y - q1.y) - (q1.y - p1.y)*(q2.x - q1.x))/par 
    tq = ((p2.y - p1.y)*(q1.x - p1.x) - (p2.x - p1.x)*(q1.y - p1.y))/par
    if tp < 0 or tp > 1 or tq < 0 or tq > 1 
      return false
    x = p1.x + tp*(p2.x - p1.x) 
    y = p1.y + tp*(p2.y - p1.y)
    results =
      a: dist(p1.x, p1.y, x, y) / dist(p1.x, p1.y, p2.x, p2.y)
      b: dist(q1.x, q1.y, x, y) / dist(q1.x, q1.y, q2.x, q2.y)
      x: x
      y: y

  #Phase 1
  find_all_intersections = (subject_nodes, clip_nodes) ->
    #Phase 1
    intersections = 0
    for i in [0...subject_nodes.length]
      for j in [0...clip_nodes.length]
        intersection = clip_intersect(subject_nodes[i],subject_nodes[i].getNext(),clip_nodes[j],clip_nodes[j].getNext())
        if intersection
          I1 = new ClipperNode intersection.x, intersection.y
          I2 = new ClipperNode intersection.x, intersection.y
          I1.alpha = intersection.a
          I2.alpha = intersection.b
          I1.intersect = true
          I2.intersect = true
          [I1.neighbor, I2.neighbor] = [I2, I1]
          subject_nodes[i].insertIntersect I1
          clip_nodes[j].insertIntersect I2
          intersections++

    #Clean Up Phase 1
    new_sub = new Array subject_nodes.length + intersections
    new_clip = new Array clip_nodes.length + intersections
    current = subject_nodes[0]
    for i in [0...new_sub.length]
      new_sub[i] = current
      current = current.next
    subject_nodes = new_sub
    current = clip_nodes[0]
    for i in [0...new_clip.length]
      new_clip[i] = current
      current = current.next
    clip_nodes = new_clip
    [subject_nodes, clip_nodes, intersections]

  find_all_entry_exits = (subject_poly, clip_poly, subject_nodes, clip_nodes) ->
    #Phase 2
    #Is the start point of the subject polygon inside the clip polygon?
    if clip_poly.isPointInPoly([subject_nodes[0].x, subject_nodes[0].y])
      status = false
    else
      status = true
    for node in subject_nodes
      if node.intersect
        node.entry = status
        status = !status
    #Is the start point of the clip polygon inside the subject polygon?
    if subject_poly.isPointInPoly([clip_nodes[0].x, clip_nodes[0].y])
      status = false
    else
      status = true
    for node in clip_nodes
      if node.intersect
        node.entry = status
        status = !status
    return

  find_all_entry_exits_union = (subject_poly, clip_poly, subject_nodes, clip_nodes) ->
    #Phase 2
    #Is the start point of the subject polygon inside the clip polygon?
    if clip_poly.isPointInPoly([subject_nodes[0].x, subject_nodes[0].y])
      status = true
    else
      status = false
    for node in subject_nodes
      if node.intersect
        node.entry = status
        status = !status
    #Is the start point of the clip polygon inside the subject polygon?
    if subject_poly.isPointInPoly([clip_nodes[0].x, clip_nodes[0].y])
      status = true
    else
      status = false
    for node in clip_nodes
      if node.intersect
        node.entry = status
        status = !status
    return

  #positive == clockwise == polygon
  #negative == counterclockwise == hole
  turns: (points) ->
    if not points
      points = @normal_points()
    p0 = points[points.length-1]
    sum = 0
    for point in points
      sum += (point.x - p0.x)*(point.y + p0.y)
      p0 = point
    return sum

  normal_points: ->
    results = new Array @points.length/2
    for i in [0...(@points.length/2)]
      results[i] = 
        x: @points[i*2]
        y: @points[i*2+1]
    results

  union: (clip_poly) ->
    subject_nodes = @get_nodes()
    clip_nodes = clip_poly.get_nodes()
    console.log clip_poly.normal_points(), @normal_points()
    output = "paper.path(\"#{@toSVG(@points)}\").attr({stroke:'blue', fill: 'blue'});\n"
    output += "paper.path(\"#{@toSVG(clip_poly.points)}\").attr({stroke:'yellow', fill: 'yellow'});\n"
    [subject_nodes, clip_nodes, intersections] = find_all_intersections(subject_nodes, clip_nodes)
    find_all_entry_exits_union(@, clip_poly, subject_nodes, clip_nodes)

    # for point in clip_nodes
    #   console.log "paper.rect(#{point.x}, #{point.y}, 1,1);"
    #Phase 3
    i = 0
    results = []
    while i < intersections
      current = subject_nodes[0].getFirstIntersection()
      current.processed = true
      i++
      new_poly = [[current.x, current.y]]
      start = new_poly[0]
      loop
        if current.entry
          loop
            current = current.next
            new_poly.push [current.x, current.y]
            if current.intersect
              i++
              current.processed = true
              break
        else
          loop
            current = current.prev
            new_poly.push [current.x, current.y]
            if current.intersect
              i++
              current.processed = true
              break
        current = current.neighbor
        if current.x == start[0] and current.y == start[1]#new_poly.length > 1 and new_poly[0][0] == new_poly[new_poly.length-1][0] and new_poly[0][1] == new_poly[new_poly.length-1][1]
          break
      reverse = false
      for other in results
        if other.isPointInPoly new_poly[0]
          reverse = true
      if reverse
        new_poly = new_poly.reverse()
        output += "paper.path(\"#{@toSVG(_.flatten(new_poly))}\").attr({stroke:'white', fill: 'white'});\n"
      else
        output += "paper.path(\"#{@toSVG(_.flatten(new_poly))}\").attr({stroke:'green', fill: 'green'});\n"
      results.push new Polygon _.flatten(new_poly)
    console.log output
    for poly in results
      console.log poly.turns()
    results

  intersection: (clip_poly) ->
    subject_nodes = @get_nodes()
    clip_nodes = clip_poly.get_nodes()
    output = "paper.path(\"#{@toSVG(@points)}\").attr({stroke:'blue', fill: 'blue'});\n"
    output += "paper.path(\"#{@toSVG(clip_poly.points)}\").attr({stroke:'yellow', fill: 'yellow'});\n"
    [subject_nodes, clip_nodes, intersections] = find_all_intersections(subject_nodes, clip_nodes)
    find_all_entry_exits(@, clip_poly, subject_nodes, clip_nodes)

    # for point in clip_nodes
    #   console.log "paper.rect(#{point.x}, #{point.y}, 1,1);"
    #Phase 3
    i = 0
    results = []
    while i < intersections
      current = subject_nodes[0].getFirstIntersection()
      current.processed = true
      i++
      new_poly = [[current.x, current.y]]
      start = new_poly[0]
      loop
        if current.entry
          loop
            current = current.next
            new_poly.push [current.x, current.y]
            if current.intersect
              i++
              current.processed = true
              break
        else
          loop
            current = current.prev
            new_poly.push [current.x, current.y]
            if current.intersect
              i++
              current.processed = true
              break
        current = current.neighbor
        if current.x == start[0] and current.y == start[1]#new_poly.length > 1 and new_poly[0][0] == new_poly[new_poly.length-1][0] and new_poly[0][1] == new_poly[new_poly.length-1][1]
          break
      output += "paper.path(\"#{@toSVG(_.flatten(new_poly))}\").attr({stroke:'green', fill: 'green'});\n"
      results.push new Polygon _.flatten(new_poly)
    console.log output
    results

  # Convienence method for outputting an SVG Path String
  toSVG: (points) ->
    output = ""
    for i in [0...points.length] by 2
      output += 'L '+Math.floor(points[i])+","+Math.floor(points[i+1])+" "
    output.replace(/^L/, "M") + "L " + points[0] + "," + points[1]

  scale: (dx, dy) ->
    output = new Array @points.length
    for i in [0...@points.length/2]
      output[i*2] = @points[i*2]*dx
      output[i*2+1] = @points[i*2+1]*dy
    return new Polygon output

  translate: (dx, dy) ->
    output = new Array @points.length
    for i in [0...@points.length/2]
      output[i*2] = @points[i*2] + dx
      output[i*2+1] = @points[i*2+1] + dy
    return new Polygon output

  #  https://github.com/substack/point-in-polygon
  #  http://www.ecse.rpi.edu/Homepages/wrf/Research/Short_Notes/pnpoly.html
  #  http://jsperf.com/point-in-polygon/2
  #  Checks if the point is inside of the polygon
  isPointInPoly: (point, points) ->
    if not points?
      points = @points
    for i in [0...points.length - 1] by 2
      if points[i] is point[0] and point[1] is points[i+1]
        return false
    return @windingNumber(point, points) % 2 != 0

  # cn_PnPoly( Point P, Point V[], int n )
  # {
  #     int    cn = 0;    // the  crossing number counter
  #     // loop through all edges of the polygon
  #     for (each edge E[i]:V[i]V[i+1] of the polygon) {
  #         if (E[i] crosses upward ala Rule #1
  #          || E[i] crosses downward ala  Rule #2) {
  #             if (P.x <  x_intersect of E[i] with y=P.y)   // Rule #4
  #                  ++cn;   // a valid crossing to the right of P.x
  #         }
  #     }
  #     return (cn&1);    // 0 if even (out), and 1 if  odd (in)
  # }
  crossingNumber: (point, points) ->
    if not points?
      vs = @points
    else
      vs = points
    x = point[0]
    y = point[1]
    
    cn = 0
    i = 0
    j = vs.length - 2

    while i < (vs.length - 2)
      xi = vs[i]
      yi = vs[i+1]
      if xi is x and yi is y
        return false
      xj = vs[j]
      yj = vs[j+1]
      intersect = ((yi > y) isnt (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
      if intersect
        cn++
      j = i
      i += 2
    cn
      
  # wn_PnPoly( Point P, Point V[], int n )
  # {
  #     int    wn = 0;    // the  winding number counter
  #     // loop through all edges of the polygon
  #     for (each edge E[i]:V[i]V[i+1] of the polygon) {
  #         if (E[i] crosses upward ala Rule #1)  {
  #             if (P is  strictly left of E[i])    // Rule #4
  #                  ++wn;   // a valid up intersect right of P.x
  #         }
  #         else
  #         if (E[i] crosses downward ala Rule  #2) {
  #             if (P is  strictly right of E[i])   // Rule #4
  #                  --wn;   // a valid down intersect right of P.x
  #         }
  #     }
  #     return wn;    // =0 <=> P is outside the polygon
  # }
  windingNumber: (point, points) ->
    wn = 0
    if not points?
      vs = @points
    else
      vs = points
    
    # Because we're not using Typed Arrays
    # http://jsperf.com/array-copy/13
    forclone = (arr) ->
      len = arr.length
      arr_clone = new Array(len + 2)
      for i in [0...len]
        arr_clone[i] = arr[i]
      arr_clone[len] = arr[0]
      arr_clone[len+1] = arr[1]
      arr_clone

    vs = forclone vs
    for i in [0...(vs.length/2)-1]
      if vs[i*2+1] <= point[1]     # start y <= P[1]
        if vs[(i+1)*2+1] > point[1]    # an upward crossing
          if @is_left([vs[i*2],vs[i*2+1]],[vs[(i+1)*2], vs[(i+1)*2+1]], point) > 0
            wn++
      else
        if vs[(i+1)*2 + 1] <= point[1]
          if @is_left([vs[i*2],vs[i*2+1]],[vs[(i+1)*2], vs[(i+1)*2+1]], point) < 0
            wn--
    wn

  is_left: (p0, p1, p2) ->
    (p1[0] - p0[0]) * (p2[1] - p0[1]) - (p2[0] - p0[0]) * (p1[1] - p0[1])

module.exports = Polygon


# _ = require('lodash')

# #
# #  The algorithm computes the clipped polygon in three phases. In the first phase it determines (and marks) the intersection points. The points are then inserted in both lists, in their proper place by ordering them using the alpha values. If no intersection points are found in this phase we know that either the subject polygon lies entirely inside the clip polygon or vice versa, or that both polygons are disjoint. By performing a containment test for any of the vertexes we are able to determine which case we have. Then we either return the inner polygon or nothing at all.
# #  In order to efficiently implement this, the algorithm uses two doubly linked lists to represent the polygons. One list is for the clip and one for the subject polygon. In each list, a node represents a distinct vertex. Obviously, the lists will contain the x and y coordinates of the vertexes as well as the necessary links to the previous and next node in the list. In addition to these however, the algorithm needs some more information. 
# #  
# class ClipperNode
#   #  NextPoly is a pointer to a new polygon, once the current one has been closed. Indeed, in the most general case, the result of the algorithm is a set of polygons rather than a single one, so that the lists that represent the polygons have to be linked together in order for polygons to be accessed from one to another.
#   constructor: (@x, @y, @prev, @next, @nextPoly) ->
#     #  Intersect is a boolean value that is set to true if the current node is an intersection point and to false otherwise. 
#     @intersect = false
#     @processed = false

#     #  Similarly, entry is flag that records whether the intersecting point is an entry or an exit point to the other polygon's interior.
#     @entry = false #true means entry, false means exit
    
#     #  Neighbor is a link to the identical vertex in the "neighbor" list. An intersection node belongs, obviously, to both polygons and therefore has to be present in both lists of vertexes. However, in Phase III, when we generate the polygons from the list of resulting edges we want to be able to jump from one polygon to another (switch the current polygon). To enable that, the neighbor pointers keep track of the identical vertexes. In the same phase of building the polygons by navigating through the list of nodes, the visited flag is used to mark the nodes already inserted in the result (it is important to notice here that every intersection point belongs to the resulting polygon (since by definition it belongs to both interiors).
#     @neighbor = null
    
#     #  The alpha value is a floating point number from 0 to 1 that indicates the position of an intersection point reported to two consecutive non-intersection vertexes from the initial list of vertexes.
#     @alpha = null


#   getNext: () ->
#     if @next.intersect
#       return @next.getNext()
#     @next

#   getFirstIntersection: () ->
#     if @intersect and not @processed
#       return @
#     else
#       return @next.getFirstIntersection()

#   insertIntersect: (i) ->
#     old = @
#     current = @next
#     while current.intersect and current.alpha < i.alpha
#       old = current
#       current = current.next
#     old.next = i
#     i.prev = old
#     i.next = current
#     current.prev = i
#     return

# #
# #  A Polygon is described by the ordered set of its vertices, P_0, P_1, P_2, ..., P_n = P_0. 
# #  It consists of all line segments consecutively connecting the points P_i, i.e. P_0->P_1, P_1->P_2, ... P_n-1->P_n = P_n-1->P_0
# #
# class Polygon
#   #  @points is an array of floats where the ith element is the x coordinate and i+1 is the y coordinate of the i/2th vertex
#   #  @points.length >= 6 (2 points)
#   #  @points.length % 2 == 0
#   #  The Polygon has at @points.length/2.0 - 1 lines
#   constructor: (@polys) ->

#   get_nodes: ->
#     all_nodes = []
#     for poly in @polys
#       nodes = new Array poly.length/2
#       for i in [0...(poly.length/2)]
#         nodes[i] = new ClipperNode poly[i*2], poly[i*2+1]
#         if i != 0
#           nodes[i].prev = nodes[i-1]
#           nodes[i-1].next = nodes[i]
#       nodes[0].next = nodes[1]
#       nodes[0].prev = nodes[nodes.length-1]
#       nodes[nodes.length-1].next = nodes[0]
#       all_nodes = all_nodes.concat nodes
#     all_nodes

#   dist = (x1,y1,x2,y2) ->
#     (x1 - x2)*(x1 - x2) + (y1 - y2)*(y1 - y2)

#   # I(node *p1, node *p2, node *q1, node *q2, 
#   #   float *alpha_p, float *alpha_q, int *xint, int *yint) 
#   # { 
#   #   float x, y, tp, tq, t, par;
#   #   par = (float) ((p2->x - p1->x)*(q2->y - q1->y) - 
#   #                  (p2->y - p1->y)*(q2->x - q1->x));
#   #   if (!par) return 0;                               /* parallel lines */
#   #   tp = ((q1->x - p1->x)*(q2->y - q1->y) - (q1->y - p1->y)*(q2->x - q1->x))/par; 
#   #   tq = ((p2->y - p1->y)*(q1->x - p1->x) - (p2->x - p1->x)*(q1->y - p1->y))/par;
#   #   if(tp<0 || tp>1 || tq<0 || tq>1) return 0;
#   #   x = p1->x + tp*(p2->x - p1->x); 
#   #   y = p1->y + tp*(p2->y - p1->y);
#   #   *alpha_p = dist(p1->x, p1->y, x, y) / dist(p1->x, p1->y, p2->x, p2->y); 
#   #   *alpha_q = dist(q1->x, q1->y, x, y) / dist(q1->x, q1->y, q2->x, q2->y); 
#   #   *xint = (int) x; 
#   #   *yint = (int) y;
#   #   return 1; 
#   # }
#   clip_intersect = (p1, p2, q1, q2) ->  
#     par = (p2.x - p1.x)*(q2.y - q1.y) - (q2.x-q1.x)*(p2.y - p1.y)
#     if not par 
#       return false
#     tp = ((q1.x - p1.x)*(q2.y - q1.y) - (q1.y - p1.y)*(q2.x - q1.x))/par 
#     tq = ((p2.y - p1.y)*(q1.x - p1.x) - (p2.x - p1.x)*(q1.y - p1.y))/par
#     if tp < 0 or tp > 1 or tq < 0 or tq > 1 
#       return false
#     x = p1.x + tp*(p2.x - p1.x) 
#     y = p1.y + tp*(p2.y - p1.y)
#     results =
#       a: dist(p1.x, p1.y, x, y) / dist(p1.x, p1.y, p2.x, p2.y)
#       b: dist(q1.x, q1.y, x, y) / dist(q1.x, q1.y, q2.x, q2.y)
#       x: x
#       y: y

#   #Phase 1
#   find_all_intersections = (subject_nodes, clip_nodes) ->
#     #Phase 1
#     intersections = 0
#     for i in [0...subject_nodes.length]
#       for j in [0...clip_nodes.length]
#         intersection = clip_intersect(subject_nodes[i],subject_nodes[i].getNext(),clip_nodes[j],clip_nodes[j].getNext())
#         if intersection
#           I1 = new ClipperNode intersection.x, intersection.y
#           I2 = new ClipperNode intersection.x, intersection.y
#           I1.alpha = intersection.a
#           I2.alpha = intersection.b
#           I1.intersect = true
#           I2.intersect = true
#           [I1.neighbor, I2.neighbor] = [I2, I1]
#           subject_nodes[i].insertIntersect I1
#           clip_nodes[j].insertIntersect I2
#           intersections++

#     #Clean Up Phase 1
#     new_sub = new Array subject_nodes.length + intersections
#     new_clip = new Array clip_nodes.length + intersections
#     current = subject_nodes[0]
#     for i in [0...new_sub.length]
#       new_sub[i] = current
#       current = current.next
#     subject_nodes = new_sub
#     current = clip_nodes[0]
#     for i in [0...new_clip.length]
#       new_clip[i] = current
#       current = current.next
#     clip_nodes = new_clip
#     [subject_nodes, clip_nodes, intersections]

#   find_all_entry_exits = (subject_poly, clip_poly, subject_nodes, clip_nodes) ->
#     #Phase 2
#     #Is the start point of the subject polygon inside the clip polygon?
#     if clip_poly.isPointInPoly([subject_nodes[0].x, subject_nodes[0].y])
#       status = false
#     else
#       status = true
#     for node in subject_nodes
#       if node.intersect
#         node.entry = status
#         status = !status
#     #Is the start point of the clip polygon inside the subject polygon?
#     if subject_poly.isPointInPoly([clip_nodes[0].x, clip_nodes[0].y])
#       status = false
#     else
#       status = true
#     for node in clip_nodes
#       if node.intersect
#         node.entry = status
#         status = !status
#     return

#   find_all_entry_exits_union = (subject_poly, clip_poly, subject_nodes, clip_nodes) ->
#     #Phase 2
#     #Is the start point of the subject polygon inside the clip polygon?
#     if clip_poly.isPointInPoly([subject_nodes[0].x, subject_nodes[0].y])
#       status = false
#     else
#       status = true
#     # start = subject_nodes[0]
#     # current = start
#     # while current.next != start
#     #   if current.intersect
#     #     current.entry = status
#     #     status = !status
#     #   current = current.next
#     for node in subject_nodes
#       if node.intersect
#         node.entry = status
#         status = !status
#     #Is the start point of the clip polygon inside the subject polygon?
#     if subject_poly.isPointInPoly([clip_nodes[0].x, clip_nodes[0].y])
#       status = false
#     else
#       status = true
#     for node in clip_nodes
#       if node.intersect
#         node.entry = status
#         status = !status
#     return

#   #positive == clockwise == polygon
#   #negative == counterclockwise == hole
#   turns: (points) ->
#     if not points
#       points = @normal_points()
#     p0 = points[points.length-1]
#     sum = 0
#     for point in points
#       sum += (point.x - p0.x)*(point.y + p0.y)
#       p0 = point
#     return sum

#   normal_points: ->
#     results = new Array @points.length/2
#     for i in [0...(@points.length/2)]
#       results[i] = 
#         x: @points[i*2]
#         y: @points[i*2+1]
#     results

#   union: (clip_poly) ->
#     subject_nodes = @get_nodes()
#     clip_nodes = clip_poly.get_nodes()
#     console.log clip_poly.normal_points(), @normal_points()
#     output = "paper.path(\"#{@toSVG(@points)}\").attr({stroke:'blue', fill: 'blue'});\n"
#     output += "paper.path(\"#{@toSVG(clip_poly.points)}\").attr({stroke:'yellow', fill: 'yellow'});\n"
#     [subject_nodes, clip_nodes, intersections] = find_all_intersections(subject_nodes, clip_nodes)
#     find_all_entry_exits_union(@, clip_poly, subject_nodes, clip_nodes)

#     # for point in clip_nodes
#     #   console.log "paper.rect(#{point.x}, #{point.y}, 1,1);"
#     #Phase 3
#     i = 0
#     results = []
#     while i < intersections
#       current = subject_nodes[0].getFirstIntersection()
#       current.processed = true
#       i++
#       new_poly = [[current.x, current.y]]
#       start = new_poly[0]
#       loop
#         if !current.entry
#           loop
#             #holes be here
#             current = current.next
#             new_poly.push [current.x, current.y]
#             if current.intersect
#               i++
#               current.processed = true
#               break
#         else
#           loop
#             current = current.prev
#             new_poly.push [current.x, current.y]
#             if current.intersect
#               i++
#               current.processed = true
#               break
#         current = current.neighbor
#         if current.x == start[0] and current.y == start[1]#new_poly.length > 1 and new_poly[0][0] == new_poly[new_poly.length-1][0] and new_poly[0][1] == new_poly[new_poly.length-1][1]
#           break
#       output += "paper.path(\"#{@toSVG(_.flatten(new_poly))}\").attr({stroke:'green', fill: 'green'});\n"
#       results.push new Polygon _.flatten(new_poly)
#     console.log output
#     for poly in results
#       console.log poly.turns()
#     results

#   intersection: (clip_poly) ->
#     subject_nodes = @get_nodes()
#     clip_nodes = clip_poly.get_nodes()
#     # output = "paper.path(\"#{@toSVG(@points)}\").attr({stroke:'blue', fill: 'blue'});\n"
#     # output += "paper.path(\"#{@toSVG(clip_poly.points)}\").attr({stroke:'yellow', fill: 'yellow'});\n"
#     [subject_nodes, clip_nodes, intersections] = find_all_intersections(subject_nodes, clip_nodes)
#     find_all_entry_exits(@, clip_poly, subject_nodes, clip_nodes)

#     # for point in clip_nodes
#     #   console.log "paper.rect(#{point.x}, #{point.y}, 1,1);"
#     #Phase 3
#     i = 0
#     results = []
#     while i < intersections
#       current = subject_nodes[0].getFirstIntersection()
#       current.processed = true
#       i++
#       new_poly = []
#       new_poly.push [current.x, current.y]
#       loop
#         if current.entry
#           loop
#             current = current.next
#             new_poly.push [current.x, current.y]
#             if current.intersect
#               i++
#               current.processed = true
#               break
#         else
#           loop
#             current = current.prev
#             new_poly.push [current.x, current.y]
#             if current.intersect
#               i++
#               current.processed = true
#               break
#         current = current.neighbor
#         if new_poly.length > 1 and new_poly[0][0] == new_poly[new_poly.length-1][0] and new_poly[0][1] == new_poly[new_poly.length-1][1]
#           break
#       # output += "paper.path(\"#{@toSVG(_.flatten(new_poly))}\").attr({stroke:'green', fill: 'green'});\n"
#       results.push new Polygon _.flatten(new_poly)
#     # console.log output
#     results

#   # Convienence method for outputting an SVG Path String
#   toSVG: (points) ->
#     output = ""
#     for i in [0...points.length] by 2
#       output += 'L '+Math.floor(points[i])+","+Math.floor(points[i+1])+" "
#     output.replace(/^L/, "M") + "L " + points[0] + "," + points[1]

#   scale: (dx, dy) ->
#     outputs = new Array @polys.length
#     for poly, j in @polys
#       output = new Array poly.length
#       for i in [0...poly.length/2]
#         output[i*2] = poly[i*2]*dx
#         output[i*2+1] = poly[i*2+1]*dy
#       outputs[j] = output
#     return new Polygon outputs

#   translate: (dx, dy) ->
#     outputs = new Array @polys.length
#     for poly, j in @polys
#       output = new Array poly.length
#       for i in [0...poly.length/2]
#         output[i*2] = poly[i*2] + dx
#         output[i*2+1] = poly[i*2+1] + dy
#       outputs[j] = output
#     return new Polygon outputs

#   #  https://github.com/substack/point-in-polygon
#   #  http://www.ecse.rpi.edu/Homepages/wrf/Research/Short_Notes/pnpoly.html
#   #  http://jsperf.com/point-in-polygon/2
#   #  Checks if the point is inside of the polygon
#   isPointInPoly: (point) ->
#     wn = 0
#     for points in @polys
#       for i in [0...points.length] by 2
#         if points[i] is point[0] and point[1] is points[i+1]
#           return false
#       wn += @windingNumber(point, points)
#     return wn % 2 != 0

#   # cn_PnPoly( Point P, Point V[], int n )
#   # {
#   #     int    cn = 0;    // the  crossing number counter
#   #     // loop through all edges of the polygon
#   #     for (each edge E[i]:V[i]V[i+1] of the polygon) {
#   #         if (E[i] crosses upward ala Rule #1
#   #          || E[i] crosses downward ala  Rule #2) {
#   #             if (P.x <  x_intersect of E[i] with y=P.y)   // Rule #4
#   #                  ++cn;   // a valid crossing to the right of P.x
#   #         }
#   #     }
#   #     return (cn&1);    // 0 if even (out), and 1 if  odd (in)
#   # }
#   crossingNumber: (point, points) ->
#     if not points?
#       vs = @points
#     else
#       vs = points
#     x = point[0]
#     y = point[1]
    
#     cn = 0
#     i = 0
#     j = vs.length - 2

#     while i < (vs.length - 2)
#       xi = vs[i]
#       yi = vs[i+1]
#       if xi is x and yi is y
#         return false
#       xj = vs[j]
#       yj = vs[j+1]
#       intersect = ((yi > y) isnt (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
#       if intersect
#         cn++
#       j = i
#       i += 2
#     cn
      
#   # wn_PnPoly( Point P, Point V[], int n )
#   # {
#   #     int    wn = 0;    // the  winding number counter
#   #     // loop through all edges of the polygon
#   #     for (each edge E[i]:V[i]V[i+1] of the polygon) {
#   #         if (E[i] crosses upward ala Rule #1)  {
#   #             if (P is  strictly left of E[i])    // Rule #4
#   #                  ++wn;   // a valid up intersect right of P.x
#   #         }
#   #         else
#   #         if (E[i] crosses downward ala Rule  #2) {
#   #             if (P is  strictly right of E[i])   // Rule #4
#   #                  --wn;   // a valid down intersect right of P.x
#   #         }
#   #     }
#   #     return wn;    // =0 <=> P is outside the polygon
#   # }
#   windingNumber: (point, points) ->
#     wn = 0
#     if not points?
#       vs = @points
#     else
#       vs = points
    
#     # Because we're not using Typed Arrays
#     # http://jsperf.com/array-copy/13
#     forclone = (arr) ->
#       len = arr.length
#       arr_clone = new Array(len + 2)
#       for i in [0...len]
#         arr_clone[i] = arr[i]
#       arr_clone[len] = arr[0]
#       arr_clone[len+1] = arr[1]
#       arr_clone

#     vs = forclone vs
#     for i in [0...(vs.length/2)-1]
#       if vs[i*2+1] <= point[1]     # start y <= P[1]
#         if vs[(i+1)*2+1] > point[1]    # an upward crossing
#           if @is_left([vs[i*2],vs[i*2+1]],[vs[(i+1)*2], vs[(i+1)*2+1]], point) > 0
#             wn++
#       else
#         if vs[(i+1)*2 + 1] <= point[1]
#           if @is_left([vs[i*2],vs[i*2+1]],[vs[(i+1)*2], vs[(i+1)*2+1]], point) < 0
#             wn--
#     wn

#   is_left: (p0, p1, p2) ->
#     (p1[0] - p0[0]) * (p2[1] - p0[1]) - (p2[0] - p0[0]) * (p1[1] - p0[1])

# module.exports = Polygon