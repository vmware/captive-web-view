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
# Enumeration class module.
# https://docs.python.org/3/library/enum.html
import enum
#
# Temporary file module.
# https://docs.python.org/3/library/tempfile.html
from tempfile import NamedTemporaryFile
#
# Local imports.
#
from noticeChecker.git_cli import git_ls_files
from noticeChecker.noticed_file import NoticeState, NoticedFile, str_quote
from noticeChecker.overwrite import Overwrite

# General TOTH
# https://github.com/vmware-samples/workspace-ONE-SDK-integration-samples/blob/main/IntegrationGuideForAndroid/Apps/samers.py

class Edit(enum.Enum):
    YES = True
    NO = False
    PROMPT = None

def first_or_len(paths):
    return str(paths[0]) if len(paths) == 1 else (str(len(paths)) + ".")

class NoticeChecker:

    # Properties that are set by the CLI.
    #
    @property
    def edit(self):
        return self._edit
    @edit.setter
    def edit(self, edit):
        for choice in Edit:
            if edit[0].lower() == choice.name[0].lower():
                self._edit = choice
                break

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
    def summariseFirst(self):
        return self._summariseFirst
    @summariseFirst.setter
    def summariseFirst(self, summariseFirst):
        self._summariseFirst = summariseFirst

    @property
    def verbose(self):
        return self._verbose
    @verbose.setter
    def verbose(self, verbose):
        self._verbose = verbose

    # End of CLI properties.

    def __init__(self):
        self._noticedFiles = []

    def __call__(self):
        self._overwrite = Overwrite(self.edit.value)
        self.__scan_files()
        if self.__print_errors() > 0: return 1
        self.__print_summary()
        if self.summariseFirst: self.__correct_dates()
        return 0
    
    def __scan_files(self):
        if not self.verbose:
            print("Scan dots:")
            for state in NoticeState:
                print(state.value, state.name)
        stopCount = 0
        for path in git_ls_files():
            stopCount += 1
            noticed = self.__scan_one_file(path)
            if self.verbose: print(noticed)
            else: print(noticed.state.value, end='', flush=True)
            self._noticedFiles.append(noticed)

            if self.stopAfter > 0 and stopCount >= self.stopAfter: break

        if not self.verbose: print()
        print(f"Path count: {stopCount}.")
    
    def __scan_one_file(self, path):
        if (
            path.suffix in self.exemptSuffixes or path.name in self.exemptNames
        ): return NoticedFile.from_exempt_path(path)

        while True:
            noticed = NoticedFile.from_path(path)
            if (not(
                noticed.exception is None
                or type(noticed.exception) is UnicodeDecodeError
            )): raise RuntimeError(path) from noticed.exception

            if (not self.summariseFirst) and self.__correct_one_date(noticed):
                # If the user chose to overwrite, go around again and refresh
                # the file state.
                continue
            
            return noticed

    def __print_errors(self):
        errorCount = 0
        for noticed in self._noticedFiles:
            if noticed.exception is None: continue
            errorCount += 1
            print(noticed.path)
            print(f"Raised {type(noticed.exception).__name__}.")
            if type(noticed.exception) is UnicodeDecodeError: print(
                f"Should the suffix {noticed.path.suffix} be an exempt binary"
                " format?")
        return errorCount

    def __print_summary(self):
        formats = {}
        noticeSuffixes = {}
        for noticed in self._noticedFiles:
            fileFormat = (
                noticed.path.name if (
                    noticed.path.name in self.exemptNames
                    or noticed.path.suffix == ""
                ) else noticed.path.suffix
            )
            if fileFormat not in formats: formats[fileFormat] = {}
            if noticed.state.name not in formats[fileFormat]:
                formats[fileFormat][noticed.state.name] = []
            formats[fileFormat][noticed.state.name].append(noticed.path)

            noticeSuffix = (
                ascii(None) if (
                    noticed.notice is None or noticed.notice.suffix is None
                ) else noticed.notice.suffix)
            if noticeSuffix not in noticeSuffixes:
                noticeSuffixes[noticeSuffix] = []
            noticeSuffixes[noticeSuffix].append(noticed.path)

        indent = " " * 4
        for fileFormat in sorted(formats.keys()):
            print(fileFormat)
            states = formats[fileFormat]
            for state in sorted(states.keys()):
                print(''.join((
                    indent, state, ": ", first_or_len(states[state]) )))
        for noticeSuffix in sorted(noticeSuffixes.keys()):
            print(
                str_quote(None if noticeSuffix == ascii(None) else noticeSuffix)
                , first_or_len(noticeSuffixes[noticeSuffix]))

    def __correct_dates(self):
        for noticed in self._noticedFiles:
            self.__correct_one_date(noticed)

    def __correct_one_date(self, noticedFile):
        if noticedFile.state is not NoticeState.INCORRECT_DATE: return False
        editedPath = noticedFile.notice.rewrite_year(
            noticedFile.gitModifiedDate.year)
        return self._overwrite.prompt(noticedFile.path, editedPath)
