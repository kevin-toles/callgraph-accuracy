package com.acme.geo;

import java.io.IOException;
import java.util.List;

public class Geometry {
    private Shape primary;
    private Holder holder;

    double run(Shape param, List<Shape> shapes, Object o) {
        Shape local = new Circle(2.0);
        double sum = local.area() + param.area();
        var c = new Circle(1.0);
        sum += c.radius();
        sum += this.primary.area();
        sum += holder.inner.area();
        for (Shape s : shapes) {
            sum += s.area();
        }
        if (o instanceof Circle k) {
            sum += k.radius();
        }
        try {
            load();
        } catch (IOException e) {
            e.printStackTrace();
        }
        return sum;
    }

    void load() throws IOException {
    }
}
