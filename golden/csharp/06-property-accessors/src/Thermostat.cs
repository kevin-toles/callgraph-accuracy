namespace App;

public class Thermostat
{
    private double celsius;

    public Thermostat() { }

    public double Fahrenheit
    {
        get
        {
            return ToF(celsius);
        }
        set
        {
            celsius = ToC(value);
            Notify();
        }
    }

    private static double ToF(double c) => c * 9 / 5 + 32;

    private static double ToC(double f) => (f - 32) * 5 / 9;

    private void Notify() { }
}
