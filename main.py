"""Compatibility launcher for the native macOS application.

Run `python3 main.py`; the Swift app is built on first use.
"""
from pathlib import Path
import subprocess
import sys


def main():
    root = Path(__file__).resolve().parent
    app = root / "dist" / "Nhip.app"
    if not app.exists() or "--build" in sys.argv:
        subprocess.run(["/bin/zsh", str(root / "scripts" / "build.sh")], cwd=root, check=True)
    arguments = [arg for arg in sys.argv[1:] if arg != "--build"]
    subprocess.run(["/usr/bin/open", str(app), "--args", *arguments], check=True)


if __name__ == "__main__":
    main()
