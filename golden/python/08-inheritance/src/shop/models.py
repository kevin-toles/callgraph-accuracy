from extlib.orm import Model


class Base:
    def save(self):
        return self.validate()

    def validate(self):
        return True


class Order(Base):
    def submit(self):
        self.save()
        return self.audit()

    def audit(self):
        return self.validate()


class Record(Model):
    def persist(self):
        self.commit()
        return self.describe()

    def describe(self):
        return "record"
