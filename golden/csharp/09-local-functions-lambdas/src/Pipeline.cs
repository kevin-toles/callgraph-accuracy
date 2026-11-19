namespace App;

public class Pipeline
{
    public Pipeline() { }

    private static int Square(int x) => x * x;

    private static void Log(int x) { }

    private static void Apply(System.Action<int> action)
    {
        action(1);
    }

    public int Run(int n)
    {
        int Local(int v)
        {
            return Square(v) + 1;
        }

        System.Func<int, int> twice = v => Local(v) * 2;
        Apply(x => Log(x));
        return twice(Local(n));
    }
}
