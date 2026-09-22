int main() {
    int bid = 100, ask = 102;
    int bid_size = 50, ask_size = 40;

    for (int i = 0; i < 4; ++i) {
        int mid       = (bid + ask) >> 1; //int for demonstration purposes
        int spread    = ask - bid;
        int imbalance = bid_size - ask_size;

        bid_size += imbalance;
        ask_size += spread;

        bid = mid - 1;
        ask = mid + 1;
    }

    return bid + ask + bid_size + ask_size;
}
