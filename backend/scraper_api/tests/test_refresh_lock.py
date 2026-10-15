import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from services import refresh


class ProcessRefreshLockTests(unittest.TestCase):
    def test_two_processes_cannot_refresh_simultaneously(self):
        script = (
            "from pathlib import Path; import sys; import services.refresh as r; "
            "r.RUNTIME_DIR = Path(sys.argv[1]); "
            "lock = r.process_refresh_lock(); "
            "\ntry:\n lock.__enter__(); print('acquired'); lock.__exit__(None, None, None)"
            "\nexcept r.RefreshInProgress:\n print('busy')"
        )
        with tempfile.TemporaryDirectory() as directory, patch.object(refresh, "RUNTIME_DIR", Path(directory)):
            def probe():
                return subprocess.run(
                    [sys.executable, "-c", script, directory],
                    cwd=Path(__file__).resolve().parents[1],
                    capture_output=True, text=True, timeout=10, check=True,
                ).stdout.strip()

            with refresh.process_refresh_lock():
                self.assertEqual(probe(), "busy")
            self.assertEqual(probe(), "acquired")
