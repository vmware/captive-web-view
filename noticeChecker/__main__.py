# Copyright 2023 VMware, Inc.  
# SPDX-License-Identifier: BSD-2-Clause
# Run with Python 3
"""Script to check copyright notices.

1.  Scans the current directory for files under revision control by running git
    ls-files.
2.  Runs git log to determine the last modified date for each file.
3.  Reads each file to discover any embedded copyright notice.

Each file then has one of these states.

-   MISSING, if the file doesn't have a copyright notice.
-   INCORRECT_DATE, if the year in the copyright doesn't match the git modified
    date.
-   CORRECT, otherwise.

The script will, with user confirmation, edit in a corrected date to each file
with INCORRECT_DATE status.

A summary of file statuses is printed.

Some file formats and names are exempt, such as binary formats and the
gradlew.bat file."""
# This file makes the directory a runnable module. To get the command line
# usage, run it like this.
#
#     cd /path/where/you/cloned/captive-web-view/
#     python3 -m noticeChecker --help

#
# Standard library imports, in alphabetic order.
# 
# Module for command line switches.
# Tutorial: https://docs.python.org/3/howto/argparse.html
# Reference: https://docs.python.org/3/library/argparse.html
import argparse
#
# Module for the operating system interface.
# https://docs.python.org/3/library/sys.html
from sys import argv, exit
#
# Module for text dedentation.
# Only used for --help description.
# https://docs.python.org/3/library/textwrap.html
import textwrap
#
# Local imports.
#
from noticeChecker.notice_checker import NoticeChecker

exemptNames = ('gradlew', 'gradlew.bat')
exemptSuffixes = ('.png', '.json', '.jar')

def main(commandLine):
    argumentParser = argparse.ArgumentParser(
        prog="python3 -m noticeChecker",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=textwrap.dedent(__doc__))
    argumentParser.add_argument(
        '-e', '--edit', choices=['yes', 'y', 'no', 'n', 'prompt']
        , default='prompt', help=
        "yes or y to edit without user confirmation; no or n to edit nothing."
        " Default is to prompt for each file.")
    argumentParser.add_argument(
        '-s', '--summarise-first', dest='summariseFirst', action='store_true'
        , help=
        "Finish the scan and print the summary before offering any edits."
        " Default is to offer edits as soon as editable files are scanned.")
    argumentParser.add_argument(
        '--stop-after', dest='stopAfter', type=int, default=0, help=
        'Stop after checking the specified number of files. Or specify zero'
        ' not to stop. This is a diagnostic option. Default is zero.')
    argumentParser.add_argument(
        '--exempt-names', dest='exemptNames', default=exemptNames
        , metavar='NAME.SUF', type=str, nargs='*', help=
        'Files with any of these names are exempt from copyright checking.'
        f' Default is {exemptNames}.')
    argumentParser.add_argument(
        '--exempt-suffixes', dest='exemptSuffixes', default=exemptSuffixes
        , metavar='.SUFFIX', type=str, nargs='*', help=
        'Files with any of these suffixes are exempt from copyright checking.'
        f' Default is {exemptSuffixes}.')
    argumentParser.add_argument(
        '-v', '--verbose', action='store_true', help=
        "Print every file path and its notice state during the scan. Default is"
        " to print only a single state indicator character per file during the"
        " scan.")
    return argumentParser.parse_args(commandLine[1:], NoticeChecker())()

exit(main(argv))
