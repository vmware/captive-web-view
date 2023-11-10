# Copyright 2023 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause

# Run with Python 3.9 or later.
"""File in the noticeChecker module."""
#
# Uses the following recent Python features.
# -   Python 3.7 subprocess text output and capture_output.
#
# Standard library imports, in alphabetic order.
#
# Date module.
# https://docs.python.org/3/library/datetime.html
import datetime
#
# Module for OO path handling.
# https://docs.python.org/3/library/pathlib.html
from pathlib import Path
#
# Regular expressions module.
# https://docs.python.org/3/library/re.html
import re
#
# Module for simple immutable objects with type specification.
# https://docs.python.org/3/library/typing.html#typing.NamedTuple
from typing import NamedTuple

# Regular expression for a copyright notice, with these capture groups.
#
# -   style, the part before the year like "Copyright" or "Copyright (c)".
#
# -   year, one to four year digits.
#
# -   suffix, the part after the year which could be the owner like
#     "VMware, Inc."
#
# Use it without anchoring to match ignoring and comment leaders for example.
copyrightYearRE = re.compile(
    r'(?P<style>copyright.*)\s+(?P<year>\d{1,4})\s+(?P<suffix>.*)'
    , re.IGNORECASE)

class CopyrightNotice(NamedTuple):
    lineIndex: int
    match: re.Match
    style: str
    year: int
    suffix: str

    @classmethod
    def from_path(cls, path):
        style = None
        year = None
        suffix = None
        match = None
        matchedIndex = None
        with path.open('r') as file:
            for index, line in enumerate(file):
                match = copyrightYearRE.search(line.rstrip())
                if match:
                    matchedIndex = index
                    break
        
        if matchedIndex is None:
            return cls(None, None, None, None, None)
        
        return cls(
            matchedIndex, match
            , match['style'], int(match['year']), match['suffix']
        )
