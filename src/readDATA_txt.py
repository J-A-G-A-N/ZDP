from dataclasses import dataclass
from typing import List
import numpy as np


def loadData(file_name):
    with open(file_name, "r") as file:
        lines = []
        L = file.readlines()
        for ll in L:
            lines.append(ll.strip())
        return lines


@dataclass
class DataField:
    name: str
    dim: int
    shape: List[int]
    element_size: int
    values: np.ndarray  # Now a NumPy array, reshaped to `shape`


def parse(data: List[str]) -> List[DataField]:
    assert data[0] == "DATA.*", "Invalid header"
    idx = 1

    field_count = int(data[idx])
    idx += 1
    print(f"Field Count : {field_count}")

    fields = []

    for _ in range(field_count):
        idx += 1

        field_name = data[idx]
        idx += 1

        dim = int(data[idx])
        idx += 1

        shape_len = int(data[idx])
        idx += 1

        shape = [int(data[idx + i]) for i in range(shape_len)]
        idx += shape_len

        element_size = int(data[idx])
        idx += 1

        total_values = np.prod(shape)

        flat_values = [float(data[idx + i]) for i in range(total_values)]
        idx += total_values

        # Convert to numpy array and reshape
        values = np.array(flat_values, dtype=np.float64).reshape(shape)

        field = DataField(
            name=field_name,
            dim=dim,
            shape=shape,
            element_size=element_size,
            values=values,
        )
        fields.append(field)

    return fields
