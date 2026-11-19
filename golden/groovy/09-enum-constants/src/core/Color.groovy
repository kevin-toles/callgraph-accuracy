package core

enum Color {
    RED("f00"),
    GREEN("0f0")

    final String code

    Color(String code) {
        this.code = code
    }

    String hex() {
        return code.toLowerCase()
    }
}

class Painter {
    String paint() {
        return Color.RED.hex()
    }
}
