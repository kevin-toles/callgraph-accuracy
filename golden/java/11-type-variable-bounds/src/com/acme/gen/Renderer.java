package com.acme.gen;

public class Renderer<T extends Widget> {
    private T current;

    void render() {
        current.draw();
    }

    <S extends Widget> void show(S s) {
        s.draw();
    }
}
