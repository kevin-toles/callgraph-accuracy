namespace App;

public static class TextExt
{
    public static string Shout(this Note n) => n.Body() + "!";
}

public class Note
{
    public Note() { }

    public string Body() => "hi";

    public string Loud()
    {
        return this.Shout();
    }
}
