package com.acme.parse

class Parser(val text: String) {
    companion object {
        operator fun invoke(n: Int): Parser {
            return Parser("n")
        }
    }
}

class Token(val text: String, val pos: Int)

fun Token(text: String): Token {
    return Token(text, 0)
}
