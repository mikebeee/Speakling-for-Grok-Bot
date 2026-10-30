"""Minimal MiniToo animation packer (clean implementation for Speakling for Grok Bot).

Mirrors Scene.Packets()/Frame() in scene.cs: 128x128 RGB888 frames, zstd level 17 /
window_log 17, uploaded with command 0x8b over Bluetooth RFCOMM channel 1.

Packet file format written by write_packets(): repeated [u16le length][packet bytes].
"""
import zstandard as zstd

SIZE = 128
FRAME_BYTES = SIZE * SIZE * 3
CMD = 0x8B
CHUNK = 256
MAX_PAYLOAD = 13500  # practical clip limit observed on the device


def _frame(body: bytes) -> bytes:
    o = bytearray([0x01, 0, 0, CMD]) + body + b"\0\0\x02"
    dl = len(o) - 4
    o[1], o[2] = dl & 0xFF, (dl >> 8) & 0xFF
    s = sum(o[1:-3]) & 0xFFFF
    o[-3], o[-2] = s & 0xFF, s >> 8
    return bytes(o)


def payload(frames, speed_ms: int) -> bytes:
    if not 1 <= len(frames) <= 255:
        raise ValueError("1..255 frames")
    raw = b"".join(frames)
    if len(raw) != len(frames) * FRAME_BYTES:
        raise ValueError("each frame must be 128x128 RGB888")
    params = zstd.ZstdCompressionParameters.from_level(17, window_log=17, write_content_size=True)
    z = zstd.ZstdCompressor(compression_params=params).compress(raw)
    head = bytes([0x25, len(frames), (speed_ms >> 8) & 0xFF, speed_ms & 0xFF, 8, 8]) + len(z).to_bytes(4, "big")
    return head + z


def packets(p: bytes):
    t = len(p).to_bytes(4, "little")
    out = [_frame(b"\x00" + t)]
    for seq, off in enumerate(range(0, len(p), CHUNK)):
        out.append(_frame(b"\x01" + t + seq.to_bytes(2, "little") + p[off:off + CHUNK]))
    return out


def write_packets(frames, speed_ms: int, path: str, limit: int = MAX_PAYLOAD) -> int:
    p = payload(frames, speed_ms)
    if len(p) > limit:
        raise ValueError(f"payload {len(p)} bytes exceeds {limit}")
    with open(path, "wb") as f:
        for q in packets(p):
            f.write(len(q).to_bytes(2, "little") + q)
    return len(p)


if __name__ == "__main__":  # build assets/idle.bin from assets/idle_raw.bin
    import sys
    src, n, speed, dst = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    raw = open(src, "rb").read()
    fr = [raw[i * FRAME_BYTES:(i + 1) * FRAME_BYTES] for i in range(n)]
    print(dst, write_packets(fr, speed, dst))
