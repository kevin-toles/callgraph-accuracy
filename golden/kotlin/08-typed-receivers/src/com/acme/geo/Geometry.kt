package com.acme.geo

class Geometry(private val primary: Shape, private val holder: Holder) {
    fun run(param: Shape, shapes: List<Shape>): Double {
        val local: Shape = Circle(2.0)
        var sum = local.area() + param.area()
        val c = Circle(1.0)
        sum += c.radius()
        sum += this.primary.area()
        sum += holder.inner.area()
        for (s in shapes) {
            sum += s.area()
        }
        load()
        return sum
    }

    fun load() {
    }
}
