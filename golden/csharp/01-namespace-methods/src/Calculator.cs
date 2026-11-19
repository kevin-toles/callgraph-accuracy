namespace App;

public class Calculator
{
    public Calculator() { }

    public int Add(int a, int b) => a + b;

    public double Add(double a, double b) => a + b;

    private int Twice(int x)
    {
        return Add(x, x);
    }

    public int Run(int x)
    {
        int t = this.Twice(x);
        double d = Add(1.5, 2.5);
        System.Console.WriteLine(d);
        return MathUtil.Square(t);
    }
}

public static class MathUtil
{
    public static int Square(int v) => v * v;
}
