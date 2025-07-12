import struct
import math
from dataclasses import dataclass
from typing import List, Optional, Union
import numpy as np
from tqdm import tqdm
from enum import IntEnum


class FieldTypeMarker(IntEnum):
    _struct = 1
    slice = 2
    array = 3


def printFieldType(val: int):
    match val:
        case FieldTypeMarker._struct:
            print("struct")
        case FieldTypeMarker.slice:
            print("slice")
        case FieldTypeMarker.array:
            print("array")


@dataclass
class DataField:
    name: str
    dim: int
    shape: List[int]
    element_size: int
    values: np.ndarray


def get_field_by_name(
    fields: List[DataField], key: Union[int, str]
) -> Optional[DataField]:
    if isinstance(key, int):
        if 0 <= key or key <= len(fields):
            return fields[key]
    elif isinstance(key, str):
        for field in fields:
            if field.name == key:
                return field
        return None
    else:
        raise TypeError(
            "Key must be either a string (field name) or an integer (field index)"
        )


def loadData(file_name: str) -> List[DataField]:
    if not file_name.endswith(".bin"):
        print("Invalid File, Pass File with extension '.bin'")

    with open(file_name, "rb") as file:
        expected_header_bytes = b"DATA.*01"
        header = file.read(8)
        assert header == expected_header_bytes, (
            f"Invalid header: got {header.decode('utf-8')}, expected {expected_header_bytes.decode('utf-8')}"
        )

        field_count_bytes = file.read(8)
        field_count = struct.unpack("<Q", field_count_bytes)[0]
        fields = []

        for _ in tqdm(range(field_count), desc="Loading Fields", unit="field"):
            field_type_mark_bytes = file.read(8)
            field_type_mark = struct.unpack("<Q", field_type_mark_bytes)[0]
            printFieldType(field_type_mark)
            field_name_length_bytes = file.read(8)
            field_name_length = struct.unpack("<Q", field_name_length_bytes)[0]
            field_name_bytes = file.read(field_name_length)
            field_name = struct.unpack(f"{field_name_length}s", field_name_bytes)[
                0
            ].decode()
            field_dim = struct.unpack("<Q", file.read(8))[0]
            field_shape_list = list(
                struct.unpack(f"{field_dim}Q", file.read(8 * field_dim))
            )
            element_size = struct.unpack("<Q", file.read(8))[0]

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
    return fields
