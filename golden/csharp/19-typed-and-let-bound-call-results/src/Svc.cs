namespace P {
class Svc {
    public void Run() {}
    public static Svc Make(int n) => new Svc();
    public Svc With(int n) => this;
    public static T Any<T>() => default;
}
class Use {
    void M() {
        var s = Svc.Make(1);
        s.Run();
        Svc.Make(2).With(3).Run();
        Svc.Make(4)?.Run();
        var g = Svc.Any<Svc>();
        g.Run();
        var v = Svc.Make(5);
        v = null;
        v.Run();
    }
}
}
