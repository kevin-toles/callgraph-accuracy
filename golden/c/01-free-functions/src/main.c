static int square(int x);
int cube(int x);

static int square(int x) {
    return x * x;
}

int cube(int x) {
    return square(x) * x;
}

int fact(int n) {
    if (n <= 1)
        return 1;
    return n * fact(n - 1);
}

int sum_to(int n) {
    int total = 0;
    for (int i = cube(0); i < square(n); i++) {
        total += fact(i);
    }
    while (cube(total) > 1000)
        total--;
    return total > 0 ? square(total) : cube(total);
}

int main(void) {
    return sum_to(square(cube(fact(2))));
}
