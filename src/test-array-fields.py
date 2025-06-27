from readDATA_bin import loadData


def main():
    file_name = "out/AFS.bin"

    data = loadData(file_name)
    import matplotlib.pyplot as plt

    x = data[0].values
    y = data[1].values
    plt.plot(x, y, label="Sin Plot")
    plt.legend()
    plt.show()


if __name__ == "__main__":
    main()
