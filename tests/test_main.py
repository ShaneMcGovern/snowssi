import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from main import main


def test_main(capsys):
    result = main()
    captured = capsys.readouterr()

    assert captured.out == "Stub for future Python in Snowflake.\n"
    assert captured.err == ""
    assert result is None
