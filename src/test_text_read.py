from readDATA_txt import DataField
from readDATA_txt import loadData
from readDATA_txt import parse
from typing import List
from tqdm import tqdm
import numpy as np


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


def save_animation_frames(
    fields: List[DataField], frame_count: int = 300, out_dir: str = "frames"
):
    import os
    import matplotlib.pyplot as plt

    os.makedirs(out_dir, exist_ok=True)
    data = {field.name: field.values.flatten() for field in fields}

    if not all(k in data for k in ("x", "y", "z")):
        raise ValueError("Missing x, y, or z fields for 3D plot")

    x, y, z = data["x"], data["y"], data["z"]
    assert len(x) == len(y) == len(z)
    n = len(x)

    for frame in tqdm(range(frame_count), desc="Saving frames", unit="frame"):
        progress = frame / frame_count
        idx = max(2, int(progress * n))

        fig = plt.figure(figsize=(6, 6))
        ax = fig.add_subplot(111, projection="3d")
        ax.plot(x[:idx], y[:idx], z[:idx], c="blue", lw=0.6)
        ax.set_xlim(np.min(x), np.max(x))
        ax.set_ylim(np.min(y), np.max(y))
        ax.set_title(f"Frame {frame:03d}")
        ax.set_xlabel("X")
        ax.set_ylabel("Y")

        plt.tight_layout()
        fig.savefig(f"{out_dir}/frame_{frame:04d}.png")
        plt.close(fig)


def main():
    import sys

    file_name = sys.argv[1]

    data = loadData(file_name)
    fields = parse(data)
    for field in fields:
        print(field)


main()
