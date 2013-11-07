martinez = require './Martinez'

subject = new martinez.Polygon [[{x: 1, y: 1}, {x: 1, y: 2}, {x: 2, y: 2}, {x: 2, y: 1}]] # small square
clipping = new martinez.Polygon [[{x: 0, y: 0}, {x: 0, y: 3}, {x: 3, y: 0}]] # overlapping triangle
result = new martinez.Polygon()

booleanOp = new martinez.BooleanOp subject, clippin, result, martinez.OpTypes.INTERSECTION
boolop.run()
console.log result


