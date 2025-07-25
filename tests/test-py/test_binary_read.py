import sys

from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[2] / "src"))
from readDATA_bin import loadData


def main():
    import sys

    if len(sys.argv) <= 1:
        print("Provide Binary file")
        exit()
    file_name = sys.argv[1]

    data = loadData(file_name)
    print(data)


if __name__ == "__main__":
    main()
