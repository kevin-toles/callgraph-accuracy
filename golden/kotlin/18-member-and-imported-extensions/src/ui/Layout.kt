package com.acme.ui

import org.jetbrains.kotlin.com.intellij.lang.ASTNode
import org.jetbrains.kotlin.psi.psiUtil.leaves

interface Modifier {
    companion object : Modifier
}

interface RowScope {
    fun Modifier.weight(w: Float): Modifier
}

interface ColumnScope {
    fun Modifier.weight(w: Float): Modifier
}

fun Row(content: RowScope.() -> Unit) {
}

fun Column(content: ColumnScope.() -> Unit) {
}

fun screen() {
    Row {
        Modifier.weight(1f)
        Column {
            Modifier.weight(2f)
        }
    }
}

class Rule {
    fun visit(node: ASTNode, file: java.io.File) {
        node.leaves()
        val content = file.readText()
        content.toUniqueId()
    }

    private fun String.toUniqueId(): String = this
}
