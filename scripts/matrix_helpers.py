from __future__ import annotations

from itertools import product
from typing import Iterable, List


def selected_list(user_input: str, default_value: str) -> List[str]:
    """Parse comma-separated inputs like GitHub actions does for our matrix."""
    raw_value = default_value if user_input == "" else user_input
    cleaned = raw_value.replace(" ", "")
    return [value for value in cleaned.split(",") if value]


def combinations(
    providers: Iterable[str], environments: Iterable[str]
) -> List[tuple[str, str]]:
    """Return all provider/environment pairs (four combos)."""
    return list(product(providers, environments))
