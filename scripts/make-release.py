#!/usr/bin/env python
"""
make-release.py

Created by Alkis Evlogimenos on 2009-04-01.


>>> _VERSION_RE.match('foo')
>>> _VERSION_RE.match('1.foo')
>>> _VERSION_RE.match('1.2foo')
>>> _VERSION_RE.match('1.2.foo')
>>> _VERSION_RE.match('1.2') # doctest:+ELLIPSIS
<_sre.SRE_Match object at ...>
>>> _VERSION_RE.match('1.2.3') # doctest:+ELLIPSIS
<_sre.SRE_Match object at ...>
>>> _VERSION_RE.match('1.2-beta1') # doctest:+ELLIPSIS
<_sre.SRE_Match object at ...>
>>> _VERSION_RE.match('1.2.3-beta9') # doctest:+ELLIPSIS
<_sre.SRE_Match object at ...>
"""

import fnmatch
import glob
import logging
import os
import os.path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

import util

_VERSION_RE = re.compile(r'^\d+\.\d+(\.\d+)?(-beta\d+)?$')

def CopyEPGPDirectory(epgp_root, dst):
  ignored_dirs = ('scripts', '.svn')
  ignored_files = ('.pkgmeta')
  for root, dirs, files in os.walk(epgp_root):
    if not os.path.exists(os.path.join(dst, root)):
      os.makedirs(os.path.join(dst, root))
    for file in files:
      if file in ignored_files:
        continue
      if file.endswith('~'):
        continue
      shutil.copyfile(os.path.join(root, file), os.path.join(dst, root, file))
    dirs[:] = [d for d in dirs if d not in ignored_dirs]
    for dir in dirs:
      os.mkdir(os.path.join(dst, root, dir))

def ListFiles(r):
  result = []
  for root, dirs, files in os.walk(r):
    for file in files:
      result.append(os.path.join(root, file))
  return result

def UpdateToc(toc, version):
  assert(os.path.exists(toc))
  file = open(toc, 'r')
  text = file.read()
  file.close()

  file = open(toc, 'w')
  text = text.replace('## Version:', '## Version: %s' % version)
  file.write(text)
  file.close()

def main(argv=None):
  if argv is None:
    argv = sys.argv

  if not len(argv) is 2:
    print >> sys.stderr, 'Usage: %s release_version' % sys.argv[0].split("/")[-1]
    return 2
  version = argv[1]
  if not _VERSION_RE.match(version):
    print >> sys.stderr, 'Invalid version string: %s' % version
    return 2

  tmp_dir = tempfile.mkdtemp()
  logging.info('Temporary directory: %s' % tmp_dir)
  stage_dir = os.path.join(tmp_dir, 'epgp')
  logging.info('Stage directory: %s' % stage_dir)
  zip_name = os.path.join(tmp_dir, 'epgp-%s.zip' % version)
  logging.info('Release zip location: %s' % zip_name)

  epgp_root = util.FindEPGPRootDir()
  logging.info('Copying %s to %s', epgp_root, stage_dir)
  CopyEPGPDirectory(epgp_root, stage_dir)

  epgp_toc = os.path.join(stage_dir, 'epgp.toc')
  logging.info('Updating %s with version info' % epgp_toc)
  UpdateToc(epgp_toc, version)

  logging.info('Making the release zip: %s' % zip_name)
  zip_file = zipfile.ZipFile(zip_name, 'w')
  for file in ListFiles(stage_dir):
    arc_name = 'epgp' + file[len(stage_dir):]
    zip_file.write(file, arc_name, compress_type=zipfile.ZIP_DEFLATED)

  r = raw_input('Do you want to import this release to the repository [y/N]? ')
  if r in ('y', 'Y'):
    epgp_svn_tag_path = 'https://epgp.googlecode.com/svn/tags/epgp-%s' % version
    subprocess.Popen(['svn', 'import', '-m', 'Tag the %s release.' % version,
                      stage_dir, epgp_svn_tag_path],
                     stdout=sys.stdout, stderr=sys.stderr).communicate()

  r = raw_input('Do you want to upload the zip [y/N]? ')
  if r in ('y', 'Y'):
    sys.path.append(os.path.join(os.path.dirname(__file__), 'googlecode'))
    from googlecode_upload import upload_find_auth
    status, reason, url = upload_find_auth(
      zip_name, 'epgp', 'epgp-%s' % version, ['Featured'])
    if url:
      print('The zip was uploaded successfully.')
      print('URL: %s' % url)
    else:
      print('An error occurred. The zip was not uploaded.')
      print('Google Code upload server said: %s (%s)' % (reason, status))

if __name__ == "__main__":
  sys.exit(main())
