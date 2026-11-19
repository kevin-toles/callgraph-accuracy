struct device_ops {
    int (*open)(int id);
    void (*close)(int id);
};

struct device {
    int id;
    const struct device_ops *ops;
};

static int null_open(int id) {
    return id;
}

static void null_close(int id) {
    (void)id;
}

static const struct device_ops null_ops = {
    .open = null_open,
    .close = null_close,
};

int device_cycle(struct device *dev, struct device_ops local) {
    int rc = dev->ops->open(dev->id);
    dev->ops->close(dev->id);
    local.close(rc);
    return null_ops.open(rc);
}
