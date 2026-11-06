"""Project-local Python startup customization.

Ensures the src/ layout package is importable when tools (e.g. Quarto/Jupyter)
start Python outside an activated virtual environment.
"""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "src"

# Prepend src/ so `import baldessari` resolves to src/baldessari.
if SRC.is_dir():
    src_str = str(SRC)
    if src_str not in sys.path:
        sys.path.insert(0, src_str)
