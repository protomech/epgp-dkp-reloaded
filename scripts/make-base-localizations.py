#!/usr/bin/env python
"""
make-base-localizations.py

Created by Alkis Evlogimenos on 2009-03-28.
"""

from glob import iglob
from itertools import chain
import logging
import os.path
import re
import sys

import util

_LOCALIZED_STRING_RE = re.compile(r'L\["[^"]*?"\]')

def main():
  strings = []
  base_dir = util.FindAddonRootDir('epgp')
  logging.info('Extracting localization strings from files')
  for dirpath, dirnames, filenames in os.walk(base_dir):
    if dirpath.endswith("localization"):
      continue
    for filename in filenames:
      if not filename.endswith(".lua") and not filename.endswith(".xml"):
        continue
      text = open(os.path.join(dirpath, filename)).read()
      localized_strings = _LOCALIZED_STRING_RE.findall(text)
      strings.extend(localized_strings)

  logging.info('Uniquifying strings')
  strings = list(set(strings))
  logging.info('Sorting strings')
  strings.sort()

  filename = os.path.join(base_dir, 'localization', 'localization.enUS.lua')
  logging.info('Writing %s' % filename)
  file = open(filename, 'w')
  file.writelines([
    'local L = LibStub("AceLocale-3.0"):NewLocale("EPGP", "enUS", true)',
    '\n',
    'if not L then return end',
    '\n',
    '\n',
    ])
  for string in strings:
    file.write(string)
    file.write(' = true\n')
  file.close()

if __name__ == "__main__":
  sys.exit(main())
