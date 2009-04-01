#!/usr/bin/env python
"""
util.py

Created by Alkis Evlogimenos on 2009-04-01.
"""

import os.path

def FindEPGPRootDir():
  if os.path.isfile('epgp.toc'):
    return '.'
  elif os.path.isfile('../epgp.toc'):
    return '..'
  else:
    raise Exception, 'EPGP root not found!'
