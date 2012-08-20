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

def CopyAddonDirectory(addon_root, dst):
  ignored_dirs = ('scripts', '.svn', '.hg', '.git')
  ignored_files = ('.pkgmeta', 'WowMatrix.dat', 'debug.xml')
  for root, dirs, files in os.walk(addon_root):
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

def UpdateToc(toc, new_version):
  unchanged = False
  assert(os.path.exists(toc))
  lines = list()
  file = open(toc, 'r')
  for line in file:
    if line.startswith('## Version:'):
      new_line = '## Version: %s\n' % new_version
      lines.append(new_line)
      if new_line == line:
        unchanged = True
    else:
      lines.append(line)
  file.close()

  file = open(toc, 'w')
  file.write("".join(lines))
  file.close()

  return unchanged

def RunAndReadOutput(*command):
  lines = list()
  result = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
  for line in result.stdout:
    lines.append(line)
  result.wait()
  if result.returncode != 0:
    logging.info("Command failed: %s" % ' '.join(command))
    return None

  return lines

def CheckRepositoryStatus(version):
  # Have we tagged this version before?
  lines = RunAndReadOutput('git', 'tag')
  if lines is None:
    return False

  for line in lines:
    tag = line.strip()
    if tag == 'v%s' % version:
      logging.info("Version %s already appears to be in the repository; aborting" % version)
      return False

  # Check our current repo status; if we get something besides 'C'
  # (clean) or 'I' (ignored), fail.
  lines = RunAndReadOutput('git', 'status', '--porcelain')
  if lines is None:
    return False
  bad_files = list()
  for line in lines:
    status = line[:2]
    filename = line.strip()[3:]
    status, filename = line.strip().split(" ", 1)
    if status != '  ':
      bad_files.append(filename)

  if bad_files:
    logging.info("Cannot commit a new version with locally modified files: ")
    for file in bad_files:
      logging.info("  %s" % file)
    return False

  return True

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

  if not CheckRepositoryStatus(version):
    return 2

  epgp_root = util.FindAddonRootDir('epgp')
  epgp_toc = os.path.join(epgp_root, 'epgp.toc')
  logging.info('Updating %s with version info' % epgp_toc)
  if not UpdateToc(epgp_toc, version):
    logging.info('Version did not change, cannot commit')

  tmp_dir = tempfile.mkdtemp()
  logging.info('Temporary directory: %s' % tmp_dir)
  stage_dir = os.path.join(tmp_dir, 'epgp')
  logging.info('Stage directory: %s' % stage_dir)
  zip_name = os.path.join(tmp_dir, 'epgp-%s.zip' % version)
  logging.info('Release zip location: %s' % zip_name)

  logging.info('Copying %s to %s', epgp_root, stage_dir)
  CopyAddonDirectory(epgp_root, stage_dir)

  logging.info('Making the release zip: %s' % zip_name)
  zip_file = zipfile.ZipFile(zip_name, 'w')
  for file in ListFiles(stage_dir):
    arc_name = 'epgp' + file[len(stage_dir):]
    zip_file.write(file, arc_name, compress_type=zipfile.ZIP_DEFLATED)
  zip_file.close()

  r = raw_input('Do you want to commit this release to the repository [y/N]? ')
  if r in ('y', 'Y'):
    subprocess.Popen(['git', 'tag', "v%s" % version],
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
