using System.Collections.Generic;

namespace App;

public class Logger
{
    public Logger() { }

    public void Log(string m) { }
}

public class Service
{
    private readonly List<string> seen = new();

    private Logger logger;

    public Service()
    {
        logger = new();
    }

    public void Handle(string m)
    {
        logger?.Log(m);
        Logger backup = new();
        backup?.Log(m);
        seen?.Add(m);
    }
}
