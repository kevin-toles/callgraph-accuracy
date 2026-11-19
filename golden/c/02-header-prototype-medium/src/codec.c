#include "codec.h"

int codec_encode(int value) {
    return value + 1;
}

int roundtrip(int value) {
    return codec_decode(codec_encode(value));
}
