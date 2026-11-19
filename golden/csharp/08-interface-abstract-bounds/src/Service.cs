namespace App;

public interface IRepo
{
    void Save(string key);
}

public abstract class Shape
{
    protected Shape() { }

    public abstract double Area();

    public double Doubled() => Area() * 2;
}

public class Service
{
    private readonly IRepo repo;

    public Service(IRepo repo)
    {
        this.repo = repo;
    }

    public void Store(Shape s)
    {
        repo.Save("k");
        System.Console.WriteLine(s.Area());
    }

    public static void SaveAll<T>(T r) where T : IRepo
    {
        r.Save("all");
    }

    public static string Show<T>(T value)
    {
        return value.ToString();
    }
}
