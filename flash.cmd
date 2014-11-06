setMode -bs
setCable -port auto
Identify
attachflash -position 2 -spi "W25Q64BV"
assignfiletoattachedflash -position 2 -file "sp605.mcs"
Program -p 2 -spionly -e -loadfpga 
exit
