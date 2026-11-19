namespace App;

public class Reader
{
    public Reader() { }

    private static string Lookup(int id) => "x" + id;

    public string First(string path)
    {
        var r = System.IO.File.OpenText(path);
        var line = r.ReadLine();
        var key = Lookup(1).Trim();
        return key + line;
    }
}
