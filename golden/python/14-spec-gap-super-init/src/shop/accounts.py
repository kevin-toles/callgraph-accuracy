class User:
    def __init__(self, name):
        self.name = name


class Admin(User):
    def __init__(self, name):
        super().__init__(name)
