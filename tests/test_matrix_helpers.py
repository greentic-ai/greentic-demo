"""Unit tests for the matrix helper utilities."""

import unittest

from scripts.matrix_helpers import combinations, selected_list


class MatrixHelperTests(unittest.TestCase):
    def test_selected_list_uses_defaults(self) -> None:
        self.assertEqual(
            selected_list("", "aws,gcp,azure"), ["aws", "gcp", "azure"]
        )

    def test_selected_list_respects_input(self) -> None:
        self.assertEqual(selected_list("aws, azure", "aws,gcp,azure"), ["aws", "azure"])
        self.assertEqual(selected_list("dev,prod", "dev,prod"), ["dev", "prod"])

    def test_selected_list_filters_empty_values(self) -> None:
        self.assertEqual(
            selected_list("aws,,gcp,", "aws,gcp,azure"), ["aws", "gcp"]
        )

    def test_combinations_return_cartesian_product(self) -> None:
        self.assertEqual(
            combinations(["aws", "gcp"], ["dev", "prod"]),
            [("aws", "dev"), ("aws", "prod"), ("gcp", "dev"), ("gcp", "prod")],
        )
