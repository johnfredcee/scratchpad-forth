#!/usr/bin/python3.4

import io
import sys

ko = None
insymbols = False
with open("kernel.map") as kf: 
    kls = kf.readlines()
    for kl in kls:
        if insymbols:
            syms = kl.split()
            if len(syms) == 3 and (syms[2][0] == "_" or syms[2][-1] == "_"):
                print("Found ", syms[2])
                csym = syms[2].lstrip("_").rstrip("_").upper()
                cline ="#define K_" + csym + " " + "0x" + syms[1] 
                print(cline, file=ko)
        if kl[0:3] == "-- " and kl[3:10] == "Symbols":
            print("Found symbols")
            insymbols = True
            ko = open("kernel.h", "wt")
    if (ko != None):
        ko.close()

