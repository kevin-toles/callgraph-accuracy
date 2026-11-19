namespace App;

public class Account
{
    private decimal balance;

    public Account() { }

    public decimal Balance
    {
        get { return Round(balance); }
    }

    private static decimal Round(decimal d) => d;

    public string Report()
    {
        return "Balance: " + Balance;
    }
}
