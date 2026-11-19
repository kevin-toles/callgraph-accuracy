package com.acme.events;

import java.util.List;

public class Bus {
    void wire(List<String> names) {
        Listener l = new Listener() {
            @Override
            public void on(String e) {
                handle(e);
            }
        };
        Job j = new Job("x") {
            @Override
            void exec() {
                handle("job");
            }
        };
        names.forEach(n -> handle(n));
        l.on("start");
        j.exec();
    }

    void handle(String e) {
    }
}
