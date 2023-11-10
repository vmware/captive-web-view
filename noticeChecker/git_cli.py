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
# Module for spawning a process to run a command.
# https://docs.python.org/3/library/subprocess.html
import subprocess

def git_modified_date(path):
    # Get the date of the last commit.
    with subprocess.Popen(
        (
            'git', 'log', '--max-count=1', '--pretty=format:%cd'
            , '--date=format:%Y %m %d', str(path)
        ), stdout=subprocess.PIPE, text=True
    ) as gitProcess:
        with gitProcess.stdout as gitOutput:
            # The line will be year, month, day separated by spaces. Put
            # them into a tuple, then spread the tuple into the date()
            # constructor.
            components = tuple(
                int(piece) for piece in gitOutput.readline().split())
        gitProcess.wait()
        return datetime.date(*components)

def git_ls_files(*switches):
    # See: https://git-scm.com/docs/git-ls-files  
    # -z switch specifies null-terminators instead of newlines, and verbatim
    # file names for unprintable values.
    with subprocess.Popen(
        ('git', 'ls-files', '-z', *switches)
        , stdout=subprocess.PIPE, text=True
    ) as gitProcess:
        with gitProcess.stdout as gitOutput:
            name = []
            while True:
                readChar = gitOutput.read(1)
                if readChar == "":
                    return
                if readChar == "\x00":
                    yield Path(''.join(name))
                    name = []
                else:
                    name.append(readChar)
