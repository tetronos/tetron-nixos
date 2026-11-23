'''
tetron-nixos main spec
'''

from libspec import Spec
from . import product, declarative

class MainSpec(Spec):
    def modules(self):
        return [product, declarative]
