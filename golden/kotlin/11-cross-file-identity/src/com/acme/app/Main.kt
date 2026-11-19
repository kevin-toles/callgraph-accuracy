package com.acme.app

import com.acme.util.Formatter
import com.acme.util.slug
import com.acme.util.title as heading

class Main {
    fun go(f: Formatter, input: String): String {
        val a = slug(input)
        val b = heading(a)
        return f.format(b)
    }
}
