namespace Shop.Orders;

public partial class Order
{
    public Order() { }

    public decimal Total()
    {
        return Subtotal() + Tax();
    }
}
