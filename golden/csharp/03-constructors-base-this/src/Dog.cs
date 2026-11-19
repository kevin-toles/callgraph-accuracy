namespace App;

public class Animal
{
    protected string name;

    public Animal(string name)
    {
        this.name = name;
    }
}

public class Dog : Animal
{
    public Dog(string name) : base(Normalize(name))
    {
    }

    public Dog() : this("rex")
    {
    }

    private static string Normalize(string s) => "[" + s + "]";

    public static Dog Create()
    {
        var items = new System.Collections.Generic.List<Dog>();
        items.Add(new Dog());
        return new Dog("max");
    }
}
