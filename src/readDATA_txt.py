from dataclasses import dataclass
from enum import IntEnum
from typing import List
import numpy as np


def loadData(file_name):
    with open(file_name, "r") as file:
        lines = []
        L = file.readlines()
        for ll in L:
            lines.append(ll.strip())
        return lines


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
    field_type: int
    dim: int
    shape: List[int]
    element_size: int
    values: np.ndarray  # Now a NumPy array, reshaped to `shape`


def parse(data: List[str]) -> List[DataField]:
    assert data[0] == "DATA.*01", "Invalid header"
    idx = 1
    field_count = int(data[idx])
    print(f"Field Count: {field_count}")
    print(f"Total data lines available: {len(data)}")
    idx += 1  # Move past field count
    fields = []

    for field_idx in range(field_count):  # Fixed: was "for * in range(field*count)"
        print(f"\nProcessing field {field_idx + 1}/{field_count}")
        print(f"Current index: {idx}")

        # Check bounds before accessing
        if idx >= len(data):
            raise IndexError(
                f"Not enough data: trying to access index {idx} but only have {len(data)} lines"
            )

        field_type = int(data[idx])
        printFieldType(field_type)
        idx += 1

        if idx >= len(data):
            raise IndexError(f"Not enough data for field name length at index {idx}")
        field_name_len = int(data[idx])  # Fixed: was missing int() conversion
        print("Field Name Len", field_name_len)
        idx += 1

        if idx >= len(data):
            raise IndexError(f"Not enough data for field name at index {idx}")
        field_name = data[idx]
        print("field_name:", field_name)
        idx += 1

        if idx >= len(data):
            raise IndexError(f"Not enough data for dim at index {idx}")
        dim = int(data[idx])
        print("dim:", dim)
        idx += 1

        if idx + dim > len(data):
            raise IndexError(
                f"Not enough data for shape: need {dim} values starting at index {idx}"
            )
        shape = [int(data[idx + i]) for i in range(dim)]
        print("shape:", shape)
        idx += dim

        if idx >= len(data):
            raise IndexError(f"Not enough data for element_size at index {idx}")
        element_size = int(data[idx])
        print("element_size:", element_size)
        idx += 1

        total_values = np.prod(shape)
        print(f"Expected values: {total_values}")
        print(f"Remaining data lines: {len(data) - idx}")

        if idx + total_values > len(data):
            raise IndexError(
                f"Not enough data for values: need {total_values} values starting at index {idx}, but only have {len(data) - idx} lines remaining"
            )

        flat_values = [float(data[idx + i]) for i in range(total_values)]
        idx += total_values

        values = np.array(flat_values, dtype=np.float64).reshape(shape)
        field = DataField(
            name=field_name,
            field_type=field_type,
            dim=dim,
            shape=shape,
            element_size=element_size,
            values=values,
        )
        fields.append(field)

    print(f"\nParsing complete. Final index: {idx}, Total lines: {len(data)}")
    return fields


# from dataclasses import dataclass
# from enum import IntEnum
# from typing import List
# import numpy as np
#
#
# def loadData(file_name):
#     with open(file_name, "r") as file:
#         lines = []
#         L = file.readlines()
#         for ll in L:
#             lines.append(ll.strip())
#         return lines
#
#
# class FieldTypeMarker(IntEnum):
#     _struct = 1
#     slice = 2
#     array = 3
#
#
# def printFieldType(val: int):
#     match val:
#         case FieldTypeMarker._struct:
#             print("struct")
#         case FieldTypeMarker.slice:
#             print("slice")
#         case FieldTypeMarker.array:
#             print("array")
#
#
# @dataclass
# class DataField:
#     name: str
#     field_type: int
#     dim: int
#     shape: List[int]
#     element_size: int
#     values: np.ndarray  # Now a NumPy array, reshaped to `shape`
#
#
# def parse(data: List[str]) -> List[DataField]:
#     assert data[0] == "DATA.*01", "Invalid header"
#     idx = 1
#
#     field_count = int(data[idx])
#     print(f"Field Count: {field_count}")
#     idx += 1  # Move past field count
#
#     fields = []
#
#     for _ in range(field_count):
#         field_type = int(data[idx])
#         printFieldType(field_type)
#         idx += 1
#
#         field_name_len = data[idx]
#         print("Field Name Len", field_name_len)
#         idx += 1
#         field_name = data[idx]
#         print("field_name:", field_name)
#         idx += 1
#
#         dim = int(data[idx])
#         print("dim:", dim)
#         idx += 1
#
#         shape = [int(data[idx + i]) for i in range(dim)]
#         print("shape:", shape)
#         idx += dim
#
#         element_size = int(data[idx])
#         print("element_size:", element_size)
#         idx += 1
#
#         total_values = np.prod(shape)
#         flat_values = [float(data[idx + i]) for i in range(total_values)]
#         idx += total_values
#
#         values = np.array(flat_values, dtype=np.float64).reshape(shape)
#
#         field = DataField(
#             name=field_name,
#             field_type=field_type,
#             dim=dim,
#             shape=shape,
#             element_size=element_size,
#             values=values,
#         )
#         fields.append(field)
#
#     return fields
