from readDATA_bin import loadData
from readDATA_bin import DataField
from typing import List


def plot_fields_3d(fields: List[DataField]):
    # Extract x, y, z fields
    import matplotlib.pyplot as plt

    data = {field.name: field.values.flatten() for field in fields}

    if not all(k in data for k in ("x", "y", "z")):
        raise ValueError("Missing x, y, or z fields for 3D plot")

    x = data["x"]
    y = data["y"]
    z = data["z"]

    if not (len(x) == len(y) == len(z)):
        raise ValueError("x, y, z fields must have the same length")

    fig = plt.figure()
    ax = fig.add_subplot(111, projection="3d")
    # ax.plot(x, y, z, c="blue", marker="o")
    ax.plot(x, y, z, c="blue", lw=0.2)

    ax.set_xlabel("X")
    ax.set_ylabel("Y")
    ax.set_title("3D Scatter Plot of Fields")

    plt.show()


def main():
    import sys

    if len(sys.argv) <= 1:
        print("Provide Binary file")
        exit()
    file_name = sys.argv[1]

    data = loadData(file_name)
    plot_fields_3d(data)


if __name__ == "__main__":
    main()
