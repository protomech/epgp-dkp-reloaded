#!/usr/bin/env python
"""
make-curseforge-localizations.py

Created by Alkis Evlogimenos on 2009-03-21.
"""

import base64
import cStringIO as StringIO
import logging
import mimetools
import os.path
import sys
import urllib2

import util

# All non enUS locales. We do not want to fetch the enUS locale as
# that is our master locale and it might hold data that is not on
# curseforge yet.
non_enUS_locales = [
  'deDE',
  'esES',
  'esMX',
  'frFR',
  'koKR',
  'ruRU',
  'zhCN',
  'zhTW',
]

def GetLocalization(locale):
  assert(locale in non_enUS_locales)
  params = {
    'format': 'lua_additive_table',
    'language': locale,
    'handle_unlocalized': 'blank',
    'handle_subnamespaces': 'none',
    'escape_non_ascii':'y',
    }

  logging.info('Fetching %s localization' % locale)
  req = urllib2.Request(
    'http://wow.curseforge.com/addons/epgp-dkp-reloaded/localization/export.txt?format=lua_additive_table&language=' + locale)
  req.timeout = 10

  http_handler = urllib2.HTTPHandler()
  localization = http_handler.http_open(req).read()

  return localization

def main():
  for locale in non_enUS_locales:
    localization = GetLocalization(locale)
    base_dir = util.FindAddonRootDir('epgp')
    filename = os.path.join(base_dir,
                            'localization',
                            'localization.%s.lua' % locale)
    logging.info('Writing %s' % filename)
    file = open(filename, 'w')
    file.writelines([
      'local L = LibStub("AceLocale-3.0"):NewLocale("EPGP", "%s")' % locale,
      '\n',
      'if not L then return end',
      '\n',
      '\n',
      ])
    file.write(localization)
    file.close()

if __name__ == "__main__":
  sys.exit(main())
