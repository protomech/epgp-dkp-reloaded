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

# The multipart encoder
def _multipart_encode(vars):
  CRLF = '\r\n'

  buf = StringIO.StringIO()
  boundary = mimetools.choose_boundary()
  for key, value in vars.iteritems():
    buf.write('--%s' % boundary)
    buf.write(CRLF)
    buf.write('Content-Disposition: form-data; name="%s"' % key)
    buf.write(CRLF)
    buf.write(CRLF)
    buf.write(value)
    buf.write(CRLF)

  buf.write('--%s--' % boundary)

  return boundary, buf.getvalue()

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
    'http://wow.curseforge.com/addons/epgp-dkp-reloaded/localization/export.txt')
  boundary, data = _multipart_encode(params)
  content_type = 'multipart/form-data; boundary=%s' % boundary
  req.add_unredirected_header('Content-type', content_type)
  req.add_data(data)

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
