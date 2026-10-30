"""Offline DPI simulator and ciadpi (ByeDPI) profile matrix.

Everything listens on 127.0.0.1. Stdlib only, plus the system openssl, make, cc and curl.

Path: curl -> ciadpi (SOCKS5) -> DpiSimulator -> local TLS server.
The simulator sees the client's first flight and resets the connection when the
blocked SNI is visible to its mode:

- stateless: naive filter, searches the first TCP read only, without TLS parsing.
- record:    reassembles TCP up to the first complete ClientHello, then searches
             each TLS record on its own (a SNI split across records is missed).
- stateful:  reassembles the handshake across records and searches the whole thing.
"""

import os
import shutil
import socket
import ssl
import struct
import subprocess
import tempfile
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
UPSTREAM = ROOT / "vendor" / "byedpi" / "upstream"

BLOCKED_SNI = "blocked.test"
ALLOWED_SNI = "allowed.test"
MODES = ("stateless", "record", "stateful")
# Engine profile 4 groups, in the order engine.c tries them (Apple build: no --fake).
AUTO_TRIGGERS = "torst,ssl_err,conn"
AUTO_LADDER_GROUPS = [
    ["--tlsrec", "1+s"],
    ["--tlsrec", "1+s", "--split", "1+s"],
    ["--split", "1+s"],
    ["--disorder", "1+s", "--split", "3+s"],
    ["--oob", "1+s"],
]
# Engine group ids: 1..5 are the presets above in their stable order, id 0 is the
# desync-free base group that only a pinned profile runs.
AUTO_GROUP_IDS = list(range(1, len(AUTO_LADDER_GROUPS) + 1))
AUTO_GROUP_PROFILES = dict(zip(AUTO_GROUP_IDS, (
    "tlsrec 1+s",
    "tlsrec 1+s, split 1+s",
    "split 1+s",
    "disorder 1+s, split 3+s",
    "oob 1+s",
)))
# BYEDPI_ENGINE_STAT_LIMIT: counters stop here instead of overflowing.
STAT_LIMIT = 1_000_000
# DpiStrategyLearner.minimumLearnedResponses: one probe is not evidence.
MINIMUM_LEARNED_RESPONSES = 3


def auto_group_order(first_group: int = 0) -> list[int]:
    """Group ids of the automatic chain in the order engine.c emits them.

    `first_group` is a 0-based preset index; -1 or an out-of-range value keeps
    the built-in order, exactly like byedpi_engine_start_grouped.
    """
    count = len(AUTO_LADDER_GROUPS)
    if not 0 <= first_group < count:
        first_group = 0
    return [1 + (first_group + step) % count for step in range(count)]


def auto_ladder_args(first_group: int = 0) -> list[str]:
    """ciadpi arguments of profile 4 with the chain rotated to `first_group`."""
    return [arg for group in auto_group_order(first_group)
            for arg in ("--auto", AUTO_TRIGGERS, *AUTO_LADDER_GROUPS[group - 1])]


AUTO_LADDER = auto_ladder_args()

# Profile -> ciadpi arguments. "direct" skips ciadpi and connects to the simulator.
PROFILES = {
    "direct": None,
    "split 1+s": ["--split", "1+s"],
    "disorder 1+s": ["--disorder", "1+s"],
    "split 1+s, disorder 3+s": ["--split", "1+s", "--disorder", "3+s"],
    "tlsrec 1+s": ["--tlsrec", "1+s"],
    "tlsrec 1+s, split 1+s": ["--tlsrec", "1+s", "--split", "1+s"],
    "disorder 1+s, split 3+s": ["--disorder", "1+s", "--split", "3+s"],
    "oob 1+s": ["--oob", "1+s"],
    "auto ladder (profile 4)": AUTO_LADDER,
    # Same chain, rotated so the group learned on this network runs first.
    "auto ladder, learned first (profile 4)": auto_ladder_args(3),
}


class GroupCounters:
    """Per-group counters of one automatic engine run, as engine.c keeps them.

    Only group ids and counts exist here, the same contract as
    byedpi_engine_group_stats: no host, address or packet ever reaches it.
    """

    def __init__(self, first_group: int = 0):
        self.order = auto_group_order(first_group)
        self.ok = [0] * (len(AUTO_LADDER_GROUPS) + 1)
        self.fail = [0] * (len(AUTO_LADDER_GROUPS) + 1)
        self.exhausted = 0

    def note_ok(self, group: int) -> None:
        self._note(self.ok, group)

    def note_fail(self, group: int) -> None:
        self._note(self.fail, group)

    def note_exhausted(self) -> None:
        if self.exhausted < STAT_LIMIT:
            self.exhausted += 1

    @staticmethod
    def _note(slots: list[int], group: int) -> None:
        if 0 <= group < len(slots) and slots[group] < STAT_LIMIT:
            slots[group] += 1

    def stats(self) -> list[tuple[int, int, int]]:
        """(group, ok, fail) in stable preset order, whatever the rotation."""
        return [(group, self.ok[group], self.fail[group]) for group in AUTO_GROUP_IDS]


def best_group(stats: list[tuple[int, int, int]]) -> int | None:
    """Mirror of DpiStrategyLearner.bestGroup: ratio ok/(fail+1), threshold 3.

    Ties prefer the earlier preset, so a learned value is deterministic.
    """
    eligible = [entry for entry in stats if entry[1] >= MINIMUM_LEARNED_RESPONSES]
    if not eligible:
        return None
    group, _, _ = max(eligible, key=lambda entry: (entry[1] / (entry[2] + 1), entry[1], -entry[0]))
    return group


class Unavailable(RuntimeError):
    """A required host tool is missing, so the matrix cannot run here."""


def require_tools() -> None:
    missing = [tool for tool in ("cc", "make", "openssl", "curl") if not shutil.which(tool)]
    if missing:
        raise Unavailable("missing host tools: " + ", ".join(missing))


def build_ciadpi(work: Path) -> Path:
    # Build from a copy so vendor/byedpi stays untouched.
    require_tools()
    source = work / "upstream"
    shutil.copytree(UPSTREAM, source)
    built = subprocess.run(["make"], cwd=source, capture_output=True, text=True)
    if built.returncode:
        raise Unavailable("make failed: " + built.stderr[-400:])
    return source / "ciadpi"


def make_cert(work: Path) -> tuple[Path, Path]:
    cert, key = work / "cert.pem", work / "key.pem"
    subprocess.run(
        ["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", str(key),
         "-out", str(cert), "-days", "1", "-subj", f"/CN={BLOCKED_SNI}",
         "-addext", f"subjectAltName=DNS:{BLOCKED_SNI},DNS:{ALLOWED_SNI}"],
        check=True, capture_output=True)
    return cert, key


def _listen() -> socket.socket:
    return socket.create_server(("127.0.0.1", 0))


class TlsServer:
    """Answers HTTP/1.1 204 over TLS on a loopback port."""

    def __init__(self, cert: Path, key: Path):
        self._context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        self._context.load_cert_chain(cert, key)
        self._listener = _listen()
        self.port = self._listener.getsockname()[1]
        threading.Thread(target=self._accept, daemon=True).start()

    def close(self) -> None:
        self._listener.close()

    def _accept(self) -> None:
        while True:
            try:
                raw, _ = self._listener.accept()
            except OSError:
                return
            threading.Thread(target=self._serve, args=(raw,), daemon=True).start()

    def _serve(self, raw: socket.socket) -> None:
        try:
            with self._context.wrap_socket(raw, server_side=True) as tls:
                tls.settimeout(5)
                request = b""
                while b"\r\n\r\n" not in request:
                    chunk = tls.recv(4096)
                    if not chunk:
                        return
                    request += chunk
                tls.sendall(b"HTTP/1.1 204 No Content\r\nConnection: close\r\nContent-Length: 0\r\n\r\n")
        except (OSError, ssl.SSLError):
            pass
        finally:
            raw.close()


def _tls_payloads(data: bytes) -> list[bytes]:
    """Payloads of the complete TLS records at the start of data."""
    payloads, pos = [], 0
    while pos + 5 <= len(data) and data[pos] == 0x16:
        length = struct.unpack(">H", data[pos + 3:pos + 5])[0]
        if pos + 5 + length > len(data):
            break
        payloads.append(data[pos + 5:pos + 5 + length])
        pos += 5 + length
    return payloads


def _hello_complete(flight: bytes) -> bool:
    """True once the ClientHello is fully received, or when the data is not TLS."""
    if not flight or flight[0] != 0x16:
        return bool(flight)
    handshake = b"".join(_tls_payloads(flight))
    if len(handshake) < 4:
        return False
    return len(handshake) >= 4 + int.from_bytes(handshake[1:4], "big")


def _reset(sock: socket.socket) -> None:
    # SO_LINGER with zero timeout makes close() send a RST instead of FIN.
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
    sock.close()


class DpiSimulator:
    """TCP middlebox in front of the TLS server. Logs one event per connection."""

    def __init__(self, mode: str, upstream_port: int):
        if mode not in MODES:
            raise ValueError(f"unknown mode: {mode}")
        self.mode = mode
        self.events: list[dict] = []
        self._upstream_port = upstream_port
        self._listener = _listen()
        self.port = self._listener.getsockname()[1]
        threading.Thread(target=self._accept, daemon=True).start()

    def close(self) -> None:
        self._listener.close()

    def _accept(self) -> None:
        while True:
            try:
                client, _ = self._listener.accept()
            except OSError:
                return
            threading.Thread(target=self._handle, args=(client,), daemon=True).start()

    def _handle(self, client: socket.socket) -> None:
        try:
            upstream = socket.create_connection(("127.0.0.1", self._upstream_port), timeout=5)
        except OSError:
            client.close()
            return
        with upstream:
            flight, chunks = self._read_flight(client)
            blocked = self._blocked(flight)
            self.events.append({"verdict": "rst" if blocked else "pass", "chunks": chunks})
            if blocked:
                _reset(client)
                return
            try:
                upstream.settimeout(None)
                upstream.sendall(flight)
                back = threading.Thread(target=self._pump, args=(upstream, client), daemon=True)
                back.start()
                self._pump(client, upstream)
                back.join()
            except OSError:
                pass
            finally:
                client.close()

    def _read_flight(self, client: socket.socket) -> tuple[bytes, list[int]]:
        # Stateless reads one TCP segment; the others reassemble until the ClientHello is complete.
        flight, chunks = b"", []
        client.settimeout(3)
        while True:
            try:
                data = client.recv(65536)
            except OSError:
                break
            if not data:
                break
            chunks.append(len(data))
            flight += data
            if self.mode == "stateless" or _hello_complete(flight):
                break
        client.settimeout(None)
        return flight, chunks

    def _blocked(self, flight: bytes) -> bool:
        needle = BLOCKED_SNI.encode()
        payloads = _tls_payloads(flight)
        if self.mode == "stateless" or not payloads:
            return needle in flight
        if self.mode == "record":
            return any(needle in payload for payload in payloads)
        return needle in b"".join(payloads)

    @staticmethod
    def _pump(src: socket.socket, dst: socket.socket) -> None:
        try:
            while True:
                data = src.recv(65536)
                if not data:
                    break
                dst.sendall(data)
        except OSError:
            pass
        try:
            dst.shutdown(socket.SHUT_WR)
        except OSError:
            pass


class CiadpiProcess:
    """Context manager: runs ciadpi on a free loopback port and waits until it accepts."""

    def __init__(self, binary: Path, args: list[str]):
        self._binary, self._args = binary, args

    def __enter__(self) -> int:
        with _listen() as probe:
            port = probe.getsockname()[1]
        self._log = tempfile.TemporaryFile()
        # -Z (wait-send) pauses between parts. Without it, loopback coalesces the parts into one
        # read, and a read-based simulator cannot see the split at all.
        self._proc = subprocess.Popen([str(self._binary), "-i", "127.0.0.1", "-p", str(port), "-Z", *self._args],
                                      stdout=subprocess.DEVNULL, stderr=self._log)
        deadline = time.monotonic() + 5
        while True:
            if self._proc.poll() is not None:
                raise RuntimeError(f"ciadpi {self._args} exited {self._proc.returncode}: {self._stderr()}")
            try:
                socket.create_connection(("127.0.0.1", port), timeout=0.2).close()
                return port
            except OSError:
                if time.monotonic() > deadline:
                    raise RuntimeError(f"ciadpi {self._args} did not listen: {self._stderr()}")
                time.sleep(0.05)

    def __exit__(self, *_) -> None:
        self._proc.terminate()
        self._proc.wait(timeout=5)
        self._log.close()

    def _stderr(self) -> str:
        self._log.seek(0)
        return self._log.read().decode(errors="replace")[-400:]


def _curl(cert: Path, sni: str, target_port: int, socks_port: int | None) -> tuple[int, str, str]:
    command = ["curl", "-sS", "--max-time", "10", "--cacert", str(cert), "-o", os.devnull,
               "-w", "%{http_code}", "--connect-to", f"{sni}:443:127.0.0.1:{target_port}"]
    if socks_port:
        command += ["--socks5", f"127.0.0.1:{socks_port}"]
    command.append(f"https://{sni}/")
    done = subprocess.run(command, capture_output=True, text=True)
    return done.returncode, done.stdout.strip(), done.stderr.strip()


def _run_profile(binary: Path, cert: Path, server_port: int, profile: str, mode: str) -> list[dict]:
    args = PROFILES[profile]
    sim = DpiSimulator(mode, server_port)
    cells = []
    try:
        for sni in (BLOCKED_SNI, ALLOWED_SNI):
            before = len(sim.events)
            if args is None:
                code, http, error = _curl(cert, sni, sim.port, None)
            else:
                with CiadpiProcess(binary, args) as socks_port:
                    code, http, error = _curl(cert, sni, sim.port, socks_port)
            seen = sim.events[before:]
            verdict = seen[0]["verdict"] if seen else "none"
            if code == 0 and http == "204":
                outcome = "PASS"
            elif verdict == "rst":
                outcome = "BLOCKED"
            else:
                outcome = "ERROR"
            cells.append({"profile": profile, "mode": mode, "sni": sni, "outcome": outcome,
                          "verdict": verdict, "http": http, "curl_error": error[:200],
                          "chunks": seen[0]["chunks"] if seen else []})
    finally:
        sim.close()
    return cells


def run_matrix(work: Path) -> dict:
    """Runs every profile in every mode against the blocked and the control SNI."""
    cert, key = make_cert(work)
    binary = build_ciadpi(work)
    server = TlsServer(cert, key)
    try:
        cells = []
        for profile in PROFILES:
            for mode in MODES:
                cells.extend(_run_profile(binary, cert, server.port, profile, mode))
    finally:
        server.close()
    return {"blocked_sni": BLOCKED_SNI, "control_sni": ALLOWED_SNI, "modes": list(MODES), "cells": cells}


def outcome(result: dict, profile: str, mode: str, sni: str = BLOCKED_SNI) -> str:
    for cell in result["cells"]:
        if cell["profile"] == profile and cell["mode"] == mode and cell["sni"] == sni:
            return cell["outcome"]
    raise KeyError((profile, mode, sni))


def format_table(result: dict, sni: str = BLOCKED_SNI) -> str:
    columns = ["profile", *MODES]
    rows = [[profile, *(outcome(result, profile, mode, sni) for mode in MODES)] for profile in PROFILES]
    widths = [max(len(str(row[i])) for row in [columns, *rows]) for i in range(len(columns))]
    lines = [f"SNI {sni}"]
    for row in [columns, *rows]:
        lines.append("  ".join(str(cell).ljust(width) for cell, width in zip(row, widths)).rstrip())
    return "\n".join(lines)
