#!/usr/bin/python
"""
-------------------------------------------------------------------------------
-- Title      : Twiddle Generator
-- Project    : Cellular Automata Research Project
-------------------------------------------------------------------------------
-- File       : twgen.py
-- Author     : Ola Martin Tiseth Stoevneng  <ola.martin.st@gmail.com>
--            : Per Thomas Lundal <perthomas@gmail.com>
-- Company    : NTNU
-- Last update: 2014-10-10
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Generates twiddles.vhd based on attributes in package.vhd
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2014-10-10  1.1      lundal   Refactored
-- 2014-04-08  1.0      stovneng Created
-------------------------------------------------------------------------------
"""

from cmath import exp,pi

def read_attributes():
    for line in open("../../packages/constants.vhd"):
        if (":=" in line and ";" in line):
            [declaration, assignment] = line.split(":=")
            value = assignment.split(";")[0]
            if ("TW_PRES" in declaration): twiddle_precision = int(value)
            if ("DFT_LG_DSPS" in declaration): dsp_amount = 2**int(value)
            if ("DFT_SIZE" in declaration): transform_size = int(value)
    return (twiddle_precision, dsp_amount, transform_size)

def calculate_twiddle(k, n, N):
    i = 1j
    twiddle = exp(-i*2*pi*k*n/N)
    return twiddle

def calculate_twiddles(N):
    twiddles = [0 for i in range(int(N*N/2))]
    for k in range(int(N/2)):
        for n in range(N):
            twiddles[k*n] = calculate_twiddle(k, n, N)
    return twiddles

def binary_of_width(number, width):
    negate = number < 0
    if negate:
        number = -1 - number
    representation = "{0:0"+str(width)+"b}"
    binary = representation.format(number)
    if negate:
        binary = "".join(["0" if i=="1" else "1" for i in binary])
    return binary;

def format_twiddle(twiddle, twiddle_precision):
    twiddle = twiddle * 2**twiddle_precision
    real = binary_of_width(int(twiddle.real), 8)
    imag = binary_of_width(int(twiddle.imag), 8)
    return (real, imag)

(twiddle_precision, dsp_amount, transform_size) = read_attributes()
operations_per_dsp = transform_size/dsp_amount
twiddles = calculate_twiddles(transform_size)

output = """\
-------------------------------------------------------------------------------
-- Title      : Twiddles
-- Project    : 
-------------------------------------------------------------------------------
-- File       : twiddles.vhd
-- Author     : Ola Martin Tiseth Stoevneng  <ola.martin.st@gmail.com>
-- Company    : 
-- Last update: 2014-04-08
-- Platform   : Spartan-6
-------------------------------------------------------------------------------
-- Description: Generated package containing twiddle factor array.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2014-04-08  1.0      stovneng Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.constants.all;

package twiddles is

  type twat is array(0 to PERDSP*DFT_SIZE-1) of STD_LOGIC_VECTOR(TWLEN-1 downto 0);
  type twa is array(0 to DFT_SIZE/(PERDSP*2)-1) of twat;
  constant TWIDDLES : twa := (
"""
for c in range(int(dsp_amount/2)):
    output += "("
    for a in range(int(operations_per_dsp)):
        for b in range(transform_size):
            x = int((a*dsp_amount/2+c)*b)
            if twiddles[x]:
                twiddle = twiddles[x]
            else:
                twiddle = complex(0,0)
            (real, imag) = format_twiddle(twiddle, twiddle_precision)
            output += '"'+real+imag+'"'
            if (not (b==transform_size-1 and a==operations_per_dsp-1)): output += ","
            if (not (b+1)%4): output += "\n"
    output += ")"
    if (not c==dsp_amount/2-1): output+= ",\n"
output += """);
end twiddles;"""

print(output)
