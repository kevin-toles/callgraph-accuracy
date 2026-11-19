import json


def encode(obj):
    return json.dumps(obj)


def main(conn, cb):
    payload = encode({"a": 1})
    conn.send(payload)
    cb(payload)
    return len(payload)


main(None, print)
