import json
import os
import selectors
import shutil
import socket
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
