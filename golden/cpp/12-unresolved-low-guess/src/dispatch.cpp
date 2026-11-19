namespace net {
struct Packet {
  int id;
};

int checksum(const Packet& p) { return p.id * 31; }

template <typename T>
int dispatch(const T& msg) {
  int c = checksum(msg);
  return c + frobnicate(msg) + net_external_hook(c, msg);
}

int send(const Packet& p) { return checksum(p); }
}  // namespace net
