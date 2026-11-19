namespace App;

public class Query
{
    public Query() { }

    public Query Select() => this;

    public Query Distinct() => this;

    public Query Where(string clause) => this;

    public string Build() => "q";
}

public class Repo
{
    public Repo() { }

    public string Find(Query q)
    {
        return q.Select()
            .Distinct()
            .Build();
    }

    public void Filter(Query q)
    {
        q.Where("a")
            .Where("b");
    }
}
