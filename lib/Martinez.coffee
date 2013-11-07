utils = require('utils')
PriorityQueue = require('priorityqueuejs')
_ = require('lodash')
RBTree = require('bintrees').RBTree

OpTypes = 
  INTERSECTION: 'INTERSECTION'
  UNION: 'UNION'
  DIFFERENCE: 'DIFFERENCE'
  XOR: 'XOR'

SweepEventType = 
  SAME_TRANSITION: "SAME_TRANSITION"
  NORMAL: "NORMAL"
  NON_CONTRIBUTING: "NON_CONTRIBUTING"
  DIFFERENT_TRANSITION: "DIFFERENT_TRANSITION"

class BooleanOp
  constructor: (@subj, @clip, @result, @type) ->
    # event queue (sorted events to be processed)
    @eq = new PriorityQueue SweepEvent.prototype.comp
    
    # segments intersecting the sweep line, sorted by SegmentComp
    @sl = new RBTree Segment.prototype.comp

    # Holds the events generated during the computation of the boolean operation
    @eventHolder = []

    # to compare events
    @sec = SweepEvent.prototype.comp

    @sortedEvents = []

  run: ->
    subjBB = @subj.bbox()
    clipBB = @clip.bbox()
    MINMAX = Math.min(subjBB.xmax, clipBB.xmax)
    #optimization 1
    if @trivialOperation(subjBB, clipBB)
      return
    for c in @subj.contours
      for i in [0...c.points.length]
        @processSegment(c.segment(i), true)
    for c in @clip.contours
      for i in [0...c.points.length]
        @processSegment(c.segment(i), false)
    while !@eq.isEmpty()
      se = @eq.peek()
      #optimization 2
      if (@type == OpTypes.INTERSECTION and se.point.x > MINMAX) or (@type == OpTypes.DIFFERENCE and se.point.x > subjBB.xmax)
        return @connectEdges()
      #may not need this
      @sortedEvents.push se
      @eq.deq()
      #the line segment must be inserted into @sl
      if se.left
        @sl.insert se
        prev = @sl.lowerBound(se)
        if prev == se
          prev = @sl.max()
        next = @sl.upperBound(se)
        @computeFields se, prev
        # Process a possible intersection between "se" and its next neighbor in sl
        if next.data() != sl.max()
          if @possibleIntersection(se, next.data()) == 2
            @computeFields se, prev.data()
            @computeFields next.data(), se
        if prev.data() != sl.max()
          if @possibleIntersection(prev.data(), se) == 2
            p = prev.data()
            @computeFields p, prev.prev().data()
            @computeFields se, p
      else
        se = se.otherEvent
        prev = @sl.lowerBound(se)
        if prev == se
          prev = @sl.max()
        next = @sl.upperBound(se)
        @sl.remove se
        if next.data() != @sl.max() and prev.data() != @sl.max()
          @possibleIntersection prev.data(), next.data()
    @connectEdges()

  trivialOperation: (subjBB, clipBB) ->
    # Test 1 for Trivial Result Case
    if @subj.contours.length*@clip.contours.length == 0
      # At least one Polygon is empty 
      if @type = OpType.DIFFERENCE
        @result = @subj
      if @type == OpType.UNION or @type == OpType.XOR
        @result = if @subj.contours.length == 0 then @clip else @subj
      return true
    # Test 2 for Trivial Result Case
    if (subjBB.xmin > clipBB.xmax or clippingBB.xmin > subjBB.xmax or subjBB.ymin > clipBB.ymax or clipBB.ymin > subjBB.ymax)
      #Bounding Boxes do not overlap
      if @type == OpType.DIFFERENCE
        @result = @subj
      if @type == OpType.UNION or @type == OpType.XOR
        @result = @subj
        @result.join @clip
      return true
    return false

  processSegment: (segment, subject) ->
    e1 = @storeSweepEvent new SweepEvent(true, segment.s, 0, subject)
    e2 = @storeSweepEvent new SweepEvent(true, segment.t, e1, subject)
    e1.otherEvent = e2
    if segment.min() == segment.s
      e2.left = false
    else
      e1.left = false
    @eq.enq e1
    @eq.enq e2
    
  computeFields: (le, prev) ->
    # Compute inOut and otherInOut fields
    if prev == @sl.max()
      le.inOut = false
      le.otherInOut = true
    else if le.pol == prev.pol
      # Previous line segment in sl belongs to the same polygon that "se" belongs to
      le.inOut = !prev.inOut
      le.otherInOut = prev.otherInOut
    else
      # Previous line segment in sl belongs to a different polygon that "se" belongs to
      le.inOut = !prev.otherInOut
      le.otherInOut = if prev.vertical() then !prev.inOut else prev.inOut
    # Compute prevInResult field
    if (prev != @sl.max())
      le.prevInResult = if !@inResult(prev) or prev.vertical() then prev.prevInresult else prev
    # Check if the line segment belongs to the boolean operation
    le.inResult = @inResult le
    return @

  inResult: (le) ->
    switch le.type
      when SweepEventType.NORMAL
        switch @type
          when OpType.INTERSECTION
            return !le.otherInOut
          when OpType.UNION
            return le.otherInOut
          when OpType.DIFFERENCE
            return (le.pol and le.otherInOut) or (!le.pol and !le.otherInOut)
          when OpType.XOR
            return true
      when SweepEventType.SAME_TRANSITION
        return @type == OpType.INTERSECTION or @type == OpType.UNION
      when SweepEventType.DIFFERENT_TRANSITION
        return @type == OpType.DIFFERENCE
      when SweepEventType.NON_CONTRIBUTING
        return false
    return false

  possibleIntersection: (le1, le2) -> 
    ip1 = null
    ip2 = null
    nintersections = utils.findIntersections(le1.segment(), le2.segment(), ip1, ip2)
    if !nintersections
      # no intersections
      return 0
    if nintersections == 1 and (le1.point == le2.point or le.otherEvent.point == le2.otherEvent.point)
      # The Line Segments intersect at an endpoint of both line segments
      return 0
    if nintersections == 2 and le1.pol == le2.pol
      # should raise an error here
      # the line segments overlap, but they belong to the same polygon
      console.log "Sorry, edges of the same polygon overlap"
      return -1
    if nintersections == 1
      # if the intersection point is not an endpoint of le1->segment ()
      if le1.point != ip1 and le1.otherEvent.point != ip1
        @divideSegment le1, ip1
      # if the intersection point is not an endpoint of le2->segment ()
      if le2.point != ip1 and le2.otherEvent.point != ip1
        @divideSegment le2, ip1
      return 1
    # The line segments associated to le1 and le2 overlap
    sortedEvents = []
    if le.point == le2.point
      sortedEvents.push 0
    else if @sec(le1, le2)
      sortedEvents.push le2
      sortedEvents.push le1
    else
      sortedEvents.push le1
      sortedEvents.push le2
    if le.otherEvent.point == le2.otherEvent.point
      sortedEvents.push 0
    else if @sec(le1.otherEvent.point, le2.otherEvent.point)
      sortedEvents.push le2.otherEvent
      sortedEvents.push le1.otherEvent   
    else
      sortedEvents.push le1.otherEvent
      sortedEvents.push le2.otherEvent          
    if sortedEvents.length == 2 or (sortedEvents.length == 3 and sortedEvents[2] != 0)
      # Both line segments are equal or share the left endpoint
      le1.type = SweepEventType.NON_CONTRIBUTING
      le2.type = if le1.inOut == le2.inOut then SweepEventType.SAME_TRANSITION else SweepEventType.DIFFERENT_TRANSITION
      if sortedEvents.length == 3
        @divideSegment sortedEvents[0].otherEvent, sortedEvents[1].point
      return 2
    # the line segments share the right endpoint
    if sortedEvents.length == 3
      @divideSegment sortedEvents[0], sortedEvents[1].point
      return 3
    # no line segment includes totally the other one
    if sortedEvents[0] != sortedEvents[3].otherEvent
      @divideSegment sortedEvents[0], sortedEvents[1].point
      @divideSegment sortedEvents[1], sortedEvents[2].point
      return 3
    # one line segment includes the other one
    @divideSegment sortedEvents[0], sortedEvents[1].point
    @divideSegment sortedEvents[3].otherEvent, sortedEvents[2].point
    return 3

  divideSegment: (le, point)->
    #  "Right event" of the "left line segment" resulting from dividing le->segment ()
    r = @storeSweepEvent new SweepEvent false, point, le, le.pol
    # "Left event" of the "right line segment" resulting from dividing le->segment ()
    l = @storeSweepEvent new SweepEvent true, point, le.otherEvent, le.pol
    # avoid a rounding error. The left event would be processed after the right event
    if @sec(l, le.otherEvent)
      le.otherEvent.left = true
      l.left = false
    le.otherEvent.otherEvent = l
    le.otherEvent = r
    @eq.enq l
    @eq.enq r

  connectEdges: ->
    # copy the events in the result polygon to resultEvents array
    resultEvents = _.filter @sortedEvents, (e) ->
      (e.left and e.inResult) or (!e.left and e.otherEvent.inResult)

    # Due to overlapping edges the resultEvents array can be not wholly sorted
    sorted = false
    while !sorted
      sorted = true
      for i in [0...resultEvents.length]
        if resultEvents[i+1]? and @sec(resultEvents[i], resultEvents[i+1]) > 0
          [resultEvents[i], resultEvents[i+1]] = [resultEvents[i+1], resultEvents[i]]
          sorted = false

    for e, i in resultEvents
      e.pos = i
      if !e.left
        [resultEvents[i].pos, resultEvents[i].otherEvent.pos] = [resultEvents[i].otherEvent.pos, resultEvents[i].pos]
    processed = (false for i in resultEvents)
    depth = []
    holeOf = []
    for i in [0...resultEvents.length]
      if processed[i]
        continue
      contour = new Contour()
      contourId = @results.addContour contour
      depth.push 0
      holeOf.push -1
      if resultEvents[i].prevInResult
        lowerContourId = resultEvents[i].prevInresult.contourId
        if !resultEvents[i].prevInResult.resultInOut
          @results.contours[lowerContourId].addHole contourId
          holeOf[contourId] = lowerContourId
          depth[contourId] = depth[lowerContourId] + 1
          contour.external = false
        else if !@results.contours[lowerContourId].external
          @results.contours[holeOf[lowerContourId]].addHole contourId
          holeOf[contourId] = holeOf[lowerContourId]
          depth[contourId] = depth[lowerContourId]
          contour.external = false
      pos = i
      initial = resultEvents[i].point
      contour.add initial
      while !(resultEvents[pos].otherEvent.point.x == initial.x and resultEvents[pos].otherEvent.point.y == initial.y)
        processed[i] = true
        if resultEvents[pos].left
          resultEvents[pos].resultInOut = false
          resultEvents[pos].contourId = contourId
        else
          resultEvents[pos].otherEvent.resultInOut = true
          resultEvents[pos].otherEvent.contourId = contourId
        processed[pos] = true
        processed[resultEvents[pos].pos] = true
        contour.add resultEvents[pos].point
        pos = @nextPos(pos, resultEvents, processed)
      processed[pos] = true
      processed[resultEvents[pos].pos] = true
      resultEvents[pos].otherEvent.contourId = contourId
      if depth[contourId] % 2 == 1
        contour.changeOrientation()

  nextPos: (pos, resultEvents, processed) ->
    newPos = pos + 1
    while newPos < resultEvents.length and resulteEvents[newPos].point == resultEvents[pos].point
      if !processed[newPos]
        return newPos
      else
        newPos++
    newPos = pos - 1
    while processed[newPos]
      newPos--
    newPos

  # Store the SweepEvent e into the event holder, returns e
  storeSweepEvent: (e) ->
    @eventHolder.push e
    e

class SweepEvent
  constructor: (@left, @point, @otherEvent, @pol, @type) ->
    @prevInResult = 0
    @inResult = false

  # assuming 1 for true, -1 for false
  # Return true means that e1 is placed at the event queue after e2, i.e,, e1 is processed by the algorithm after e2
  comp: (e1, e2) ->
    if e1.point.x > e2.point.x# Different x-coordinate
      return 1
    if e2.point.x > e1.point.x # Different x-coordinate
      return -1
    if e1.point.y != e2.point.y # Different points, but same x-coordinate. The event with lower y-coordinate is processed first
      return if e1.point.y > e2.point.y then 1 else -1
    if (e1.left != e2.left) # Same point, but one is a left endpoint and the other a right endpoint. The right endpoint is processed first
      return if e1.left then 1 else -1
    # Same point, both events are left endpoints or both are right endpoints.
    if utils.signedArea(e1.point, e1.otherEvent.point, e2.otherEvent.point) != 0 # not collinear
      return if e1.above(e2.otherEvent.point) then 1 else -1 # the event associate to the bottom segment is processed first
    return if e1.pol > e2.pol then 1 else -1


  above: (p) ->
    !@below(p)

  below: (p) ->
    if utils.signedArea(@point, @otherEvent.point, p) > 0 then @left else utils.signedArea(@otherEvent.point, @point, p) > 0

  vertical: () ->
    @point.x == @otherEvent.point.x

  segment: ->
    new Segment @point, @otherEvent.point

# BBox has
#   xmin
#   xmax
#   ymin
#   ymax


class Contour
  constructor: (@points) ->
    if !@points?
      @points = []
    #holes are a list of integers that correspond to the hole's position in this contour's polygon
    @holes = []
    @external = true
    @cc = null

  bbox: ->
    xmin = @points[0].x
    xmax = @points[0].x
    ymin = @points[0].y
    ymax = @points[0].y
    for point in @points
      xmin = Math.min(xmin, point.x)
      xmax = Math.max(xmax, point.x)
      ymin = Math.min(ymin, point.y)
      ymax = Math.max(ymax, point.y)
    xmin: xmin
    xmax: xmax
    ymin: ymin
    ymax: ymax

  segment: (p) ->
    if p == @points.length - 1
      new Segment @points[@points.length - 1], @points[0]
    else
      new Segment @points[p], @points[p+1]

  counterclockwise: ->
    if !@cc?
      area = 0
      #might be an indexing problem here
      for i in [0...@points.length-1]
        area += @points[i].x*@points[i+1].y - @points[i+1].x*@points[i].y
      area += @points[@points.length - 1].x*@points[0].y - @points[@points.length - 1].x*@points[0].y
      @cc = area > 0
    @cc

  add: (p) ->
    @points.push p
    @

  clear: ->
    @points = []
    @holes = []

  clearHoles: ->
    @holes = []

  addHole: (h) ->
    @holes.push h

  clockwise: ->
    !@counterclockwise()

  changeOrientation: () ->
    @points = @points.reverse()
    @

  setClockwise: ->
    if @counterclockwise() then @changeOrientation() 
    @

  setCounterClockwise: ->
    if @clockwise() then @changeOrientation()
    @

  move: (x, y) ->
    for i in [0...@points.length]
      @points[i].x += x
      @points[i].y += y
    @

class Polygon
  constructor: (@contours) ->
    if !@contours?
      @contours = []
    else
      for i in [0...@contours.length]
        @contours[i] = new Contour @contours[i]
    @

  addContour: (contour) ->
    id = @contours.length
    @contours.push contour
    id

  bbox: ->
    if @contours.length == 0
      return 
        xmin: 0
        xmax: 0
        ymin: 0
        ymax: 0
    else
      cbox = @contours[0].bbox()
      xmin = cbox.xmin
      xmax = cbox.xmax
      ymin = cbox.ymin
      ymax = cbox.ymax
      for c in @contours
        cbox = c.bbox()
        xmin = Math.min(xmin, cbox.xmin)
        xmax = Math.max(xmax, cbox.xmax)
        ymin = Math.min(ymin, cbox.ymin)
        ymax = Math.max(ymax, cbox.ymax)
      xmin: xmin
      xmax: xmax
      ymin: ymin
      ymax: ymax

  move: (x,y) ->
    for c in @contours
      c.move(x,y)
    @

class Segment
  constructor: (@s, @t) ->

  # Return the point of the segment with lexicographically smallest coordinate
  min: ->
    if (@s.x < @t.x) or (@s.x == @t.x and @s.y < @t.y) )
      return @s
    return @t

  # Return the point of the segment with lexicographically largest coordinate
  max: ->
    if (@s.x > @t.x) or (@s.x == @t.x and @s.y > @t.y)
      return @s
    @t

  degenerate: ->
    @s.x == @t.x and @s.y == @t.y

  vertical: ->
    @s.x == @t.x
    
  # Change the segment orientation
  changeOrientation: ->
    [@s, @t] = [@t, @s]

  # assuming 1 for true, -1 for false
  # le1 and le2 are the left events of line segments (le1->point, le1->otherEvent->point) and (le2->point, le2->otherEvent->point)
  comp: (le1, le2) ->
    comp = SweepEvent.prototype.comp
    if le1 == le2
      return 0
    if utils.signedArea(le1.point, le1.otherEvent.point, le2.point) != 0 or utils.signedArea(le1.point, le1.otherEvent.point, le2.otherEvent.point) != 0
      # Segments are not colinear
      # If they share their left endpoint use the right endpoint to start
      if le.point == le2.point
        return if le1.below(le2.otherEvent.point) then 1 else -1
      # Different left endpoint - use th eleft endpoint to start
      if le1.point.x == le2.point.x
        return if le1.point.y < le2.point.y then 1 else -1
      # has the line segment associated to e1 been inserted into S after the line segment associated to e2 ?
      if comp(le1, le2) > 0
        return if le2.above(le1.point) then 1 else -1
      return le1.below(le2.point) then 1 else -1
    if le1.pol != le2.pol
      return if le1.pol then 1 else -1
    return if comp(le1, le2) then 1 else -1

Martinez = 
  BooleanOp: BooleanOp
  Polygon: Polygon
  Contour: Contour
  Segment: Segment
  OpTypes: OpTypes

module.exports = Martinez