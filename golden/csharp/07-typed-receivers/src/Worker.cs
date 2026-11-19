namespace App;

public class Item
{
    public Item() { }

    public void Process() { }
}

public class Holder
{
    public Item Current;

    public Holder() { }
}

public class Worker
{
    private Holder holder;

    public Worker(Holder h)
    {
        holder = h;
    }

    public void Run(Item first, System.Collections.Generic.List<Item> items, object o)
    {
        first.Process();
        Item local = new Item();
        local.Process();
        var made = new Item();
        made.Process();
        foreach (Item it in items)
        {
            it.Process();
        }
        if (o is Item matched)
        {
            matched.Process();
        }
        holder.Current.Process();
        try
        {
            items.Clear();
        }
        catch (System.InvalidOperationException ex)
        {
            ex.GetBaseException();
        }
    }
}
