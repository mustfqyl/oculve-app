import json
import os
import selectors
import shutil
import socket
import ssl
import struct
import threading
import subprocess
import tempfile
import time
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
UPSTREAM = ROOT / "vendor" / "byedpi" / "upstream"


@unittest.skipUnless(os.name == "posix", "ByeDPI CLI lifecycle test requires POSIX signals")
class ByeDpiProcessLifecycleTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not shutil.which("make") or not shutil.which("cc"):
            raise unittest.SkipTest("ByeDPI CLI test requires make and a C compiler")
        cls.build_dir = tempfile.TemporaryDirectory(prefix="oculve-byedpi-lifecycle-")
        source = Path(cls.build_dir.name) / "upstream"
        shutil.copytree(UPSTREAM, source)
        subprocess.run(["make"], cwd=source, check=True, capture_output=True, text=True)
        cls.binary = source / "ciadpi"
        interfaces = {name for _, name in socket.if_nameindex()}
        cls.loopback = next((name for name in ("lo0", "lo") if name in interfaces), None)
        if cls.loopback is None:
            cls.build_dir.cleanup()
            raise unittest.SkipTest("No loopback interface is available")

    @classmethod
    def tearDownClass(cls):
        cls.build_dir.cleanup()

    def test_automatic_retries_real_tls_destination_after_reset(self):
        # A real loopback TLS exchange, with a simulated first-request reset.
        # No Google/Cloudflare response decides the destination's strategy.
        with tempfile.TemporaryDirectory(prefix="oculve-dpi-tls-") as directory:
            cert, key = Path(directory) / "cert.pem", Path(directory) / "key.pem"
            subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
                            "-keyout", str(key), "-out", str(cert), "-days", "1",
                            "-subj", "/CN=blocked.example", "-addext", "subjectAltName=DNS:blocked.example"],
                           check=True, capture_output=True)
            server_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            server_context.load_cert_chain(cert, key)
            listener = socket.socket()
            listener.bind(("127.0.0.1", 0))
            listener.listen()
            listener.settimeout(10)
            destination = listener.getsockname()[1]
            observed = []
            errors = []
            def serve():
                try:
                    first, _ = listener.accept()
                    first.settimeout(4)
                    observed.append(first.recv(16384))
                    first.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
                    first.close()
                    second, _ = listener.accept()
                    second.settimeout(5)
                    with server_context.wrap_socket(second, server_side=True) as tls:
                        observed.append(tls.recv(4096))
                        tls.sendall(b"HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n")
                except Exception as error:
                    errors.append(error)
            worker = threading.Thread(target=serve, daemon=True)
            worker.start()
            strategies = [["--split", "1+s"], ["--split", "1+s", "--disorder", "3+s"],
                          ["--disorder", "1+s"], ["--disorder", "1+s", "--split", "3+s"]]
            automatic = [arg for strategy in strategies for arg in ["--auto", "torst,ssl_err", *strategy]]
            process = subprocess.Popen([str(self.binary), "--internal-ready", "--ip", "127.0.0.1",
                "--port", "0", "--no-domain", "--debug", "0", "--interface", self.loopback, *automatic],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
            try:
                with selectors.DefaultSelector() as selector:
                    selector.register(process.stdout, selectors.EVENT_READ)
                    self.assertTrue(selector.select(5))
                    port = json.loads(process.stdout.readline())["port"]
                proxy = socket.create_connection(("127.0.0.1", port), timeout=8)
                proxy.sendall(b"\x05\x01\x00")
                self.assertEqual(proxy.recv(2), b"\x05\x00")
                proxy.sendall(b"\x05\x01\x00\x01" + socket.inet_aton("127.0.0.1") + struct.pack("!H", destination))
                reply = proxy.recv(10)
                self.assertEqual(reply[:2], b"\x05\x00")
                client_context = ssl.create_default_context(cafile=str(cert))
                with client_context.wrap_socket(proxy, server_hostname="blocked.example") as tls:
                    tls.sendall(b"GET / HTTP/1.1\r\nHost: blocked.example\r\nConnection: close\r\n\r\n")
                    self.assertIn(b"204 No Content", tls.recv(4096))
                worker.join(timeout=2)
                self.assertFalse(errors, errors)
                self.assertEqual(len(observed), 2)
                self.assertTrue(observed[0].startswith(b"\x16"), "First connection must reach the destination as TLS")
            finally:
                process.terminate()
                process.wait(timeout=3)
                process.stdout.close()
                listener.close()

    def test_sigterm_closes_idle_listener(self):
        self.assert_graceful_stop(connect_client=False)

    def test_sigterm_closes_listener_with_connected_client(self):
        self.assert_graceful_stop(connect_client=True)

    def assert_graceful_stop(self, connect_client):
        process = subprocess.Popen(
            [
                str(self.binary),
                "--internal-ready",
                "--ip",
                "127.0.0.1",
                "--port",
                "0",
                "--no-domain",
                "--debug",
                "0",
                "--interface",
                self.loopback,
                "--split",
                "1+s",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
        client = None
        try:
            with selectors.DefaultSelector() as selector:
                selector.register(process.stdout, selectors.EVENT_READ)
                self.assertTrue(selector.select(5), "ByeDPI did not report listener readiness")
                ready = json.loads(process.stdout.readline())
            self.assertEqual(ready.get("state"), "ready")
            port = ready["port"]
            self.assertIsInstance(port, int)
            if connect_client:
                client = socket.create_connection(("127.0.0.1", port), timeout=1)

            process.terminate()
            try:
                exit_code = process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=2)
                self.fail("ByeDPI did not stop after SIGTERM")
            self.assertEqual(exit_code, 0)

            with self.assertRaises(OSError):
                socket.create_connection(("127.0.0.1", port), timeout=0.2)
        finally:
            if client is not None:
                client.close()
            if process.poll() is None:
                process.kill()
                process.wait(timeout=2)
            process.stdout.close()


if __name__ == "__main__":
    unittest.main()
