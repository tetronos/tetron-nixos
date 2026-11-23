'''
tetron-nixos main spec
'''

from libspec import Spec
from . import product, declarative, spike0

class MainSpec(Spec):
    def modules(self):
        return [product, declarative, spike0]
