package app

import lib.Sink
import lib.Text

class Main {
    private Sink out

    void run() {
        String t = Text.clean(" x ")
        out.emit(t)
    }
}
