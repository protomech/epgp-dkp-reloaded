#!/usr/bin/env python
"""
util.py

Created by Alkis Evlogimenos on 2009-04-01.
"""

import os.path
import logging

def FindAddonRootDir(addon):
  if os.path.isfile('%s.toc' % addon):
    return '.'
  elif os.path.isfile('../%s.toc' % addon):
    return '..'
  else:
    raise Exception, '%s root not found!' % addon

logging.basicConfig(format=("%(asctime)s %(levelname)s %(filename)s:"
                              "%(lineno)s %(message)s "))
logging.getLogger().setLevel(logging.INFO)
