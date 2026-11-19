class Base:
    def __init__(self, notify):
        self.notify = notify


class Job(Base):
    def configure(self, load_fn, save_fn):
        self.load, self.save = load_fn, save_fn

    def run(self):
        data = self.load()
        self.save(data)
        self.notify(data)
        return self.finish()

    def finish(self):
        return True
