PROJECT_NAME = toplevel
BITFILE = $(PROJECT_NAME).bit
PROGFILE = $(PROJECT_NAME).mcs

$(PROGFILE): $(BITFILE)
	promgen -w -p mcs -c FF -o $(PROGFILE) -s 4096 -u 0000 $(BITFILE) -spi

flash: $(PROGFILE)
	echo "setmode -bs" > flash.tmp
	echo "setcable -port auto" >> flash.tmp
	echo "identify" >> flash.tmp
	echo "attachflash -position 2 -spi \"W25Q64BV\"" >> flash.tmp
	echo "assignfiletoattachedflash -position 2 -file \"$(PROGFILE)\"" >> flash.tmp
	echo "program -p 2 -spionly -e -loadfpga " >> flash.tmp
	echo "exit" >> flash.tmp
	impact -batch flash.tmp

clean:
	git clean -xdf

