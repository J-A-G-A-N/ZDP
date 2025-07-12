import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[2] / "src"))
from readDATA_bin import loadData


def main():
    file_name = "out/MSE.bin"

    data = loadData(file_name)
    import matplotlib.pyplot as plt

    ax = plt.figure().add_subplot(projection="3d")
    x = data[0].values
    y = data[1].values
    z = data[2].values
    ax.plot(x, y, z, label="Lorenz attractor")
    ax.legend()
    plt.show()


if __name__ == "__main__":
    main()
