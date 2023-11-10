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
# Module for file and directory handling.
# https://docs.python.org/3.5/library/shutil.html
import shutil
#
# Temporary file module.
# https://docs.python.org/3/library/tempfile.html
from tempfile import NamedTemporaryFile
#
# Local imports.
#
from noticeChecker.git_cli import git_ls_files
from noticeChecker.noticed_file import NoticeState, NoticedFile

# General TOTH
# https://github.com/vmware-samples/workspace-ONE-SDK-integration-samples/blob/main/IntegrationGuideForAndroid/Apps/samers.py

class NoticeChecker:

    # Properties that are set by the CLI.
    #
    @property
    def exemptNames(self):
        return self._exemptNames
    @exemptNames.setter
    def exemptNames(self, exemptNames):
        self._exemptNames = exemptNames

    @property
    def exemptSuffixes(self):
        return self._exemptSuffixes
    @exemptSuffixes.setter
    def exemptSuffixes(self, exemptSuffixes):
        self._exemptSuffixes = exemptSuffixes

    @property
    def stopAfter(self):
        return self._stopAfter
    @stopAfter.setter
    def stopAfter(self, stopAfter):
        self._stopAfter = stopAfter

    @property
    def verbose(self):
        return self._verbose
    @verbose.setter
    def verbose(self, verbose):
        self._verbose = verbose

    # End of CLI properties.

    def __init__(self):
        self._suffixes = {}

    def __call__(self):
        if not self.verbose:
            for state in NoticeState:
                print(state.value, state.name)
        stopCount = 0
        for path in git_ls_files():
            stopCount += 1
            suffix = path.name if path.suffix == "" else path.suffix
            try:
                noticedFile = (
                    NoticedFile.from_exempt_path(path)
                    if (
                        suffix in self.exemptSuffixes
                        or path.name in self.exemptNames
                    ) else NoticedFile.from_path(path)
                )
            except UnicodeDecodeError:
                print(path)
                print(
                    f"Raised UnicodeDecodeError. Should the suffix {suffix}"
                    " be an exempt binary format?")
                return 1
            except Exception as exception:
                raise RuntimeError(path) from exception

            if self.verbose:
                print(noticedFile)
            else:
                print(
                    noticedFile.state.value, end='', flush=True)
            self.__record_state(
                path.name if path.name in self.exemptNames else suffix
                , noticedFile.state)

            if self.stopAfter > 0 and stopCount >= self.stopAfter:
                break

        if not self.verbose:
            print()
        self.__print_states()
        print(f"Path count:{stopCount}.")
    
    def __record_state(self, suffix, noticeState):
        if suffix not in self._suffixes:
            self._suffixes[suffix] = {}
        if noticeState.name not in self._suffixes[suffix]:
            self._suffixes[suffix][noticeState.name] = 0
        self._suffixes[suffix][noticeState.name] += 1

    def __print_states(self):
        indent = " " * 4
        for suffix in sorted(self._suffixes.keys()):
            print(suffix)
            summary = self._suffixes[suffix]
            for state, count in summary.items():
                print(''.join((indent, state, ": ", str(count), ".")))
