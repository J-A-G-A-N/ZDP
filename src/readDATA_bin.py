import struct
import math
from dataclasses import dataclass
from typing import List
import numpy as np
from tqdm import tqdm


@dataclass
class DataField:
    name: str
    dim: int
    shape: List[int]
    element_size: int
    values: np.ndarray


def loadData(file_name: str) -> List[DataField]:
    if not file_name.endswith(".bin"):
        print("Invalid File, Pass File with extension '.bin'")

    with open(file_name, "rb") as file:
        expected_header_bytes = b"DATA.*"
        expected_header = "DATA.*"
        header = file.read(6)
        assert header == expected_header_bytes, (
            f"Invalid header: got {header}, expected {expected_header}"
        )

        field_count_bytes = file.read(8)
        field_count = struct.unpack("<Q", field_count_bytes)[0]
        fields = []

        for _ in tqdm(range(field_count), desc="Loading Fields", unit="field"):
            field_name_length_bytes = file.read(8)
            field_name_length = struct.unpack("<Q", field_name_length_bytes)[0]
            field_name_bytes = file.read(field_name_length)
            field_name = struct.unpack(f"{field_name_length}s", field_name_bytes)[
                0
            ].decode()
            field_dim_bytes = file.read(8)
            field_dim = struct.unpack("<Q", field_dim_bytes)[0]
            field_dim = struct.unpack("<Q", field_dim_bytes)[0]
            field_shape_len = struct.unpack("<Q", file.read(8))[0]
            field_shape_list = list(
                struct.unpack(f"{field_shape_len}Q", file.read(8 * field_shape_len))
            )
            element_size_bytes = file.read(8)
            element_size = struct.unpack("<Q", element_size_bytes)[0]

            field_len = math.prod(field_shape_list)

            field_values_bytes = file.read(element_size * field_len)
            field_values = struct.unpack(f"{field_len}d", field_values_bytes)
            field_values_reshaped = np.array(field_values, dtype=np.float64).reshape(
                field_shape_list
            )

            field = DataField(
                name=field_name,
                dim=field_dim,
                shape=field_shape_list,
                element_size=element_size,
                values=field_values_reshaped,
            )
            fields.append(field)
        print()
    return fields
