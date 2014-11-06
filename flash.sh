. ~/xilinx/13.3/ISE_DS/settings64.sh

echo 'Generating MCS files for flash programming...'
promgen -w -p mcs -c FF -o sp605.mcs -s 4096 -u 0000 sp605.bit -spi

echo 'Programming SPI flash...'
impact -batch flash.cmd

echo 'DONE!'
