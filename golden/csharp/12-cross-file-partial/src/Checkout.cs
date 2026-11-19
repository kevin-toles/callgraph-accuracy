using Shop.Orders;

namespace Shop;

public class Checkout
{
    public Checkout() { }

    public decimal Pay()
    {
        var order = new Order();
        return order.Total();
    }
}
