package com.acme.geo

class Circle(private val r: Double) : Shape {
    override fun area(): Double = r * r

    fun radius(): Double = r
}
