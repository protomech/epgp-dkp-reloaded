#!/usr/bin/env python
"""
util.py

Created by Alkis Evlogimenos on 2009-04-01.
"""

import os.path
import logging

def FindEPGPRootDir():
  if os.path.isfile('epgp.toc'):
    return '.'
  elif os.path.isfile('../epgp.toc'):
    return '..'
  else:
    raise Exception, 'EPGP root not found!'

logging.basicConfig(format=("%(asctime)s %(levelname)s %(filename)s:"
                              "%(lineno)s %(message)s "))
logging.getLogger().setLevel(logging.INFO)
