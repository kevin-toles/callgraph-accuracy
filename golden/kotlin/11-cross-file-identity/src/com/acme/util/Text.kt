package com.acme.util

fun slug(s: String): String {
    return s
}

fun title(s: String): String {
    return slug(s)
}

interface Formatter {
    fun format(s: String): String

    fun name(): String
}
