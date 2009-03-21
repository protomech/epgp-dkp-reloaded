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
import re
import sys
import urllib2

from BeautifulSoup import BeautifulSoup

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

class MultipartHTTPPostPreprocessor(urllib2.HTTPHandler):
  def http_request(self, req):
    vars = req.get_data()
    assert type(vars) == dict

    boundary, data = _multipart_encode(vars)
    content_type = 'multipart/form-data; boundary=%s' % boundary
    req.add_unredirected_header('Content-type', content_type)
    req.add_data(data)

    return urllib2.HTTPHandler.http_request(self, req)

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

_SCRIPT_RE = re.compile('<script.*?</script>', re.DOTALL)

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
  html = urllib2.urlopen(
    'http://wow.curseforge.com/projects/epgp-dkp-reloaded/localization/export/',
    params).read()

  # Remove all contents of script tags
  logging.info('Stripping all <script>...</script> content')
  html = _SCRIPT_RE.sub('', html)
  
  soup = BeautifulSoup(html)
  return soup.find('textarea').string

def main():
  for locale in non_enUS_locales:
    localization = GetLocalization(locale)
    filename = 'localization.%s.lua' % locale
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
  logging.basicConfig(format=("%(asctime)s %(levelname)s %(filename)s:"
                              "%(lineno)s %(message)s "))
  logging.getLogger().setLevel(logging.INFO)

  urllib2.install_opener(urllib2.build_opener(MultipartHTTPPostPreprocessor))

  sys.exit(main())
