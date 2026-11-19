namespace App;

public class Registry
{
    private static int counter = Seed();

    private readonly System.Collections.Generic.List<string> names = new System.Collections.Generic.List<string>();

    static Registry()
    {
        Init();
    }

    public Registry()
    {
        Register("default");
    }

    private static int Seed() => 42;

    private static void Init() { }

    public void Register(string n)
    {
        names.Add(n);
    }
}
