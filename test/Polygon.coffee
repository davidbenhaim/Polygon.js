assert = require "assert"
Polygon = require "../lib/Polygon"

makeCircle = (radius, steps, centerX, centerY) ->
  points = new Array steps*2
  for i in [0..steps*2] by 2
    points[i] = (centerX + radius * Math.cos((2 * Math.PI * i/2) / steps))
    points[i+1] = (centerY + radius * Math.sin((2 * Math.PI * i/2) / steps))
  points

getRandomArbitary = (min, max) ->
  Math.random() * (max - min) + min

circle = new Polygon makeCircle(10, 1000, 0, 0).reverse()
complex_poly = new Polygon [0,0, 10,0, 10,8, 2,8, 2,5, 8,5, 8,3, 5,3, 5,10, 0,10]

square_subj = new Polygon [0,0, 10,0, 10,10, 0,10]
square_clip = new Polygon [-1,5, 5,5, 5,-1, -1,-1] #[-1,-1, 5,-1, 5,5, -1,5]

paper_subj = (new Polygon [8,0, 8,9, 4,4, 0,9, 0,0]).translate(20,20).scale(5,5)
paper_clip = (new Polygon [-2,14, 14,14, 14,7, -2,7]).translate(20,20).scale(5,5)

describe "Polygon", ->
  describe "#isPointInPoly()", ->
    it "should return true when the point is inside of the polygon", ->
      circle.isPointInPoly([0,0]).should.be.true
      square_subj.isPointInPoly([1,1]).should.be.true
      for j in [0..100]
        circle.isPointInPoly([getRandomArbitary(-5,5), getRandomArbitary(-5,5)]).should.be.true
        square_subj.isPointInPoly([getRandomArbitary(1,5), getRandomArbitary(1,5)]).should.be.true
    it "should return false when the point is not inside of the polygon", ->
      circle.isPointInPoly([-100,0]).should.be.false
    it "should return false when the point is on the edge of the polygon", ->
      circle.isPointInPoly([circle.points[0],circle.points[1]]).should.be.false
      for j in [0..circle.points.length] by 2
        circle.isPointInPoly([circle.points[j], circle.points[j+1]]).should.be.false
  
  describe "#windingNumber()", ->
    it "should return 0 when the point is outside of the polygon", ->
      complex_poly.windingNumber([-10,0]).should.equal(0)
      complex_poly.windingNumber([0,-10]).should.equal(0)
      complex_poly.windingNumber([6,4]).should.equal(0)
    it "should return not 0 when the point is inside of the polygon", ->
      complex_poly.windingNumber([1,1]).should.not.equal(0)
      complex_poly.windingNumber([4,6]).should.not.equal(0)
    it "should return correct winding numbers when the point is inside of the polygon", ->
      complex_poly.windingNumber([1,1]).should.equal(1)
      complex_poly.windingNumber([4,6]).should.equal(2)

  describe "#crossingNumber()", ->
    it "should be even when the point is outside of the polygon", ->
      (complex_poly.crossingNumber([-10,0]) % 2).should.equal(0)
      (complex_poly.crossingNumber([0,-10]) % 2).should.equal(0)
      (complex_poly.crossingNumber([6,4]) % 2).should.equal(0)
    it "should return correct winding numbers when the point is inside of the polygon", ->
      complex_poly.windingNumber([1,1]).should.equal(1)
      complex_poly.windingNumber([4,6]).should.equal(2)

  describe "#intersection()", ->
    it "should have a result", ->
      square_subj = (new Polygon [0,0, 10,0, 10,10, 0,10]).translate(50,50).scale(5,5)
      square_clip = (new Polygon [-1,-1, 5,-1, 5,5, -1,5]).translate(50,50).scale(5,5)
      paper_subj.union(paper_clip).should.not.have.length(0)
      square_subj.union(square_clip).should.not.have.length(0)
