namespace App;

public delegate int Op(int x);

public class Calc
{
    private readonly Op op;
    private readonly System.Func<int, int> transform;
    private int raw;

    public Calc(Op op, System.Func<int, int> transform)
    {
        this.op = op;
        this.transform = transform;
    }

    public int Result => Clamp(op(raw));

    public int Scaled => transform(Bump());

    public int Twice(int v) => Clamp(v) * 2;

    private int Bump() => raw + 1;

    private static int Clamp(int v) => v < 0 ? 0 : v;

    public int Apply() => this.op(1) + this.transform(2);
}
