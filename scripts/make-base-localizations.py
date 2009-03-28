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

def FindEPGPRootDir():
  if os.path.isfile('epgp.toc'):
    return '.'
  elif os.path.isfile('../epgp.toc'):
    return '..'
  else:
    raise Exception, 'EPGP root not found!'

_LOCALIZED_STRING_RE = re.compile(r'L\[.*\]')

def main():
  strings = []
  base_dir = FindEPGPRootDir()
  logging.info('Extracting localization strings from files')
  for file in chain(iglob(os.path.join(base_dir, '*.lua')),
                    iglob(os.path.join(base_dir, '*.xml'))):
    text = open(file).read()
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
  logging.basicConfig(format=("%(asctime)s %(levelname)s %(filename)s:"
                              "%(lineno)s %(message)s "))
  logging.getLogger().setLevel(logging.INFO)

  sys.exit(main())
