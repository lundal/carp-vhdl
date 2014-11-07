"""
-------------------------------------------------------------------------------
-- Title      : twgen
-- Project    : 
-------------------------------------------------------------------------------
-- File       : twgen.py
-- Author     : Ola Martin Tiseth Stoevneng  <ola.martin.st@gmail.com>
-- Company    : 
-- Last update: 2014/04/08
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: Generates twiddle.vhd based on attributes in package.vhd
-------------------------------------------------------------------------------
-- Revisions  :
- Date        Version  Author   Description
-- 2014/04/08  1.0      stovneng Created
-------------------------------------------------------------------------------
"""
from math import cos,sin,pi,sqrt
PRES = None
DSPS = None
N = None
for l in file("package.vhd"):
  if(":=" in l):
    if((not PRES) and "TW_PRES" in l): PRES = int(l.split(":=")[1].split(";")[0])
    if((not DSPS) and "DFT_LG_DSPS" in l): DSPS = 2**int(l.split(":=")[1].split(";")[0])
    if((not N) and "DFT_SIZE" in l): N = int(l.split(":=")[1].split(";")[0])
RUNS_PER_DSP = N/DSPS

point = 2**PRES
lz = [False]*(N*N/2)
def w(i,j,n=N):
  if(not lz[i*j]):
    lz[i*j]=(int(cos(2*pi*i*j/n)*point),-int(sin(2*pi*i*j/n)*point))
  return lz[i*j]

for i in range(N/2+1):
  for j in range(N):
    (wr,wi) = w(i,j)

def negate(inn):
  out = ["0" if i=='1' else "1" for i in inn]
  b = 0
  for i in out:
    b+=int(i)
    b*=2
  b/=2
  b+=1
  out = str(bin(b))
  out = out.split('b')[1]
  return ('1' if inn[0]=='0' else '0')*(PRES-len(out))+out

output = """-------------------------------------------------------------------------------
-- Title      : twiddle
-- Project    : 
-------------------------------------------------------------------------------
-- File       : twiddle.vhd
-- Author     : Ola Martin Tiseth Stoevneng  <ola.martin.st@gmail.com>
-- Company    : 
-- Last update: 2014/04/08
-- Platform   : Spartan-6 LX150T
-------------------------------------------------------------------------------
-- Description: Generated package containing twiddle factor array.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2014/04/08  1.0      stovneng Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
library work;
use work.sblock_package.all;

package twiddle is

  type twat is array(0 to PERDSP*DFT_SIZE-1) of STD_LOGIC_VECTOR(TWLEN-1 downto 0);
  type twa is array(0 to DFT_SIZE/(PERDSP*2)-1) of twat;
  constant TWIDDLES : twa := (
"""

for c in range(DSPS/2):
 output += "("
 for a in range(RUNS_PER_DSP):
  for b in range(N):
   x=(a*DSPS/2+c)*b
   if lz[x]:
     (r,i) = lz[x]
   else:
     (r,i) = (0,0)
   r=str(bin(r))
   i=str(bin(i))
   r=r.split('b')
   i=i.split('b')
   nr = r[0][0]=='-'
   ni = i[0][0]=='-'
   r=("0")*(8-len(r[1]))+r[1]
   i=("0")*(8-len(i[1]))+i[1]
   if nr:
     nr = negate(r)
     r = nr
   if ni:
     ni = negate(i)
     i = ni
   output += '"'+r+i+'"'
   if(not (b==N-1 and a==RUNS_PER_DSP-1)): output += ","
   if(not (b+1)%4): output += "\n"
 output += ")"
 if (not c==DSPS/2-1): output+= ",\n"
output += """);
end twiddle;"""
print(output)
