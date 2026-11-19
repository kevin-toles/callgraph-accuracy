namespace App;

public class Events
{
    public Events() { }

    public static void Handle(string s) { }

    public void Fire(System.Action<string> onDone, System.Func<int, bool> check)
    {
        if (check(3))
        {
            onDone("ok");
        }
    }

    public void Wire(object o, int n)
    {
        System.Action<string> handler = Handle;
        Fire(handler, x => x > 0);
        var s = o as string;
        long wide = (long)n;
        var t = typeof(Events);
        var name = nameof(Handle);
        int size = sizeof(int);
        int zero = default(int);
        handler(name);
    }
}
