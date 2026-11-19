namespace App.Core
{
    public class Outer
    {
        public Outer() { }

        public static int Seed() => 10;

        public class Inner
        {
            public Inner() { }

            public int Value() => Seed() + Helper();

            private static int Helper() => 1;

            public static int Twice(int v) => v * 2;
        }

        public int Use()
        {
            var inner = new Inner();
            return inner.Value() + Outer.Inner.Twice(2);
        }
    }
}
