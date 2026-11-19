namespace Shop.Orders;

public partial class Order
{
    private decimal Subtotal() => 10m;

    private decimal Tax() => Subtotal() * 0.1m;
}
