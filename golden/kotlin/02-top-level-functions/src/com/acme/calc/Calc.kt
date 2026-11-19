package com.acme.calc

fun square(x: Int): Int = x * x

fun sumOfSquares(a: Int, b: Int): Int {
    return square(a) + square(b)
}

class Report {
    fun line(n: Int): Int {
        return sumOfSquares(n, n)
    }
}

fun main() {
    val r = Report()
    r.line(3)
}
