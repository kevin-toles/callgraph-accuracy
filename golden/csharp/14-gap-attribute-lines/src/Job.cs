namespace App;

[System.Serializable]
public class Job
{
    public Job() { }

    [System.Obsolete(nameof(Legacy))]
    public void Legacy()
    {
        Execute();
    }

    [System.Diagnostics.DebuggerStepThrough]
    private void Execute()
    {
        System.Console.WriteLine(typeof(Job));
    }
}
