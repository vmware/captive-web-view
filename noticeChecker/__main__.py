# Copyright 2023 VMware, Inc.  
# SPDX-License-Identifier: BSD-2-Clause
# Run with Python 3
"""Script to check copyright notices.

WiP"""
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
        '-v', '--verbose', action='store_true', help=
        "List every file.")
    argumentParser.add_argument(
        '--stop-after', dest='stopAfter', type=int, default=0, help=
        'Stop after checking the specified number of files. Or specify zero'
        ' not to stop. This is a diagnostic option. Default is zero.')
    argumentParser.add_argument(
        '--exempt-names', dest='exemptNames', default=exemptNames
        , metavar='.SUFFIX', type=str, help=
        'Files with any of these names are exempt from copyright checking.'
        f' Default is {exemptNames}.')
    argumentParser.add_argument(
        '--exempt-suffixes', dest='exemptSuffixes', default=exemptSuffixes
        , metavar='.SUFFIX', type=str, help=
        'Files with any of these suffixes are exempt from copyright checking.'
        f' Default is {exemptSuffixes}.')
    return argumentParser.parse_args(commandLine[1:], NoticeChecker())()

exit(main(argv))
