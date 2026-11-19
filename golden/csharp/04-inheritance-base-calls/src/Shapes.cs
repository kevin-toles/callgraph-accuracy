namespace App;

public class Shape
{
    public Shape() { }

    public virtual string Describe() => "shape";

    protected void Log(string m) { }
}

public class Circle : Shape
{
    public Circle() : base() { }

    public override string Describe()
    {
        Log("describe");
        this.Log("again");
        return base.Describe() + "circle";
    }
}

public class AppError : System.Exception
{
    public AppError(string msg) : base(msg) { }

    public override string ToString() => base.ToString() + "!";
}
