FAMILY = spartan6
DEVICE = xc6slx45t
PACKAGE = fgg484
SPEED = 3

PROJECT_NAME = carp

COREFILES = $(shell find ipcores -name *.xco)
VHDLFILES = $(shell find modules packages ipcores sp605 -name *.vhd)
CONSTRAINTSFILE = sp605/constraints.ucf

.PHONY: help regenerate synthesize implement flash clean purge

help:
	@echo "make regenerate: Regenerate ip cores"
	@echo "make synthesize: Synthesize the design using parameters in packages/parameters.vhd"
	@echo "make implement:  Implement the synthesized design"
	@echo "make flash:      Flash the implemented design to development board"

regenerate: ipcores/coregen.cgp

synthesize: $(PROJECT_NAME).ngc

implement: $(PROJECT_NAME).ncd

ipcores/coregen.cgp: $(COREFILES) makefile
	@echo
	@echo "##########################################"
	@echo "#                                        #"
	@echo "#  Regenerating ip cores...              #"
	@echo "#                                        #"
	@echo "##########################################"
	@echo
	cd ipcores; echo "SET addpads = false" > coregen.cgp
	cd ipcores; echo "SET asysymbol = true" >> coregen.cgp
	cd ipcores; echo "SET busformat = BusFormatAngleBracketNotRipped" >> coregen.cgp
	cd ipcores; echo "SET createndf = false" >> coregen.cgp
	cd ipcores; echo "SET designentry = VHDL" >> coregen.cgp
	cd ipcores; echo "SET device = $(DEVICE)" >> coregen.cgp
	cd ipcores; echo "SET devicefamily = $(FAMILY)" >> coregen.cgp
	cd ipcores; echo "SET flowvendor = Other" >> coregen.cgp
	cd ipcores; echo "SET formalverification = false" >> coregen.cgp
	cd ipcores; echo "SET foundationsym = false" >> coregen.cgp
	cd ipcores; echo "SET implementationfiletype = Ngc" >> coregen.cgp
	cd ipcores; echo "SET package = $(PACKAGE)" >> coregen.cgp
	cd ipcores; echo "SET removerpms = false" >> coregen.cgp
	cd ipcores; echo "SET simulationfiles = Behavioral" >> coregen.cgp
	cd ipcores; echo "SET speedgrade = -$(SPEED)" >> coregen.cgp
	cd ipcores; echo "SET verilogsim = false" >> coregen.cgp
	cd ipcores; echo "SET vhdlsim = true" >> coregen.cgp
# The core file has to be backed up because coregen overwrites it and hardcodes part info
	cd ipcores; for core in $(COREFILES); do \
	cp -p ../$$core core.tmp; coregen -b ../$$core -p .; mv core.tmp ../$$core; done

%.ucf: %.ucf.in makefile
	@echo
	@echo "##########################################"
	@echo "#                                        #"
	@echo "#  Preprocessing constraints...          #"
	@echo "#                                        #"
	@echo "##########################################"
	@echo
	sed -e "s/@DEVICE/$(DEVICE)/" -e "s/@PACKAGE/$(PACKAGE)/" -e "s/@SPEED/$(SPEED)/" \
	    $< > $@

$(PROJECT_NAME).ngc: $(VHDLFILES) ipcores/coregen.cgp makefile
	@echo
	@echo "##########################################"
	@echo "#                                        #"
	@echo "#  Synthesizing...                       #"
	@echo "#                                        #"
	@echo "##########################################"
	@echo
	echo $(VHDLFILES) | xargs -n 1 > vhdlfiles.tmp
	echo "run " > synthesis.tmp
	echo "-ifn vhdlfiles.tmp" >> synthesis.tmp
	echo "-ifmt VHDL" >> synthesis.tmp
	echo "-p $(DEVICE)-$(PACKAGE)-$(SPEED)" >> synthesis.tmp
	echo "-top toplevel" >> synthesis.tmp
	echo "-opt_level 2" >> synthesis.tmp
	echo "-shreg_min_size 8" >> synthesis.tmp
	echo "-ofn $@" >> synthesis.tmp
	xst -ifn synthesis.tmp | tee synthesis.log
	cat synthesis.srp > synthesis.report

$(PROJECT_NAME).ngd: $(PROJECT_NAME).ngc $(CONSTRAINTSFILE) makefile
	@echo
	@echo "##########################################"
	@echo "#                                        #"
	@echo "#  Translating...                        #"
	@echo "#                                        #"
	@echo "##########################################"
	@echo
	ngdbuild -p $(DEVICE)-$(PACKAGE)-$(SPEED) -uc $(CONSTRAINTSFILE) $< $@ | tee translate.log

$(PROJECT_NAME).pcf: $(PROJECT_NAME).ngd makefile
	@echo
	@echo "##########################################"
	@echo "#                                        #"
	@echo "#  Mapping and placing...                #"
	@echo "#                                        #"
	@echo "##########################################"
	@echo
	map -w -p $(DEVICE)-$(PACKAGE)-$(SPEED) -global_opt speed -logic_opt on -lc auto -mt 2 -o placed.ncd $< $@ | tee map_and_place.log
	cat placed.mrp placed.psr > map_and_place.report

$(PROJECT_NAME).ncd: $(PROJECT_NAME).pcf
	@echo
	@echo "##########################################"
	@echo "#                                        #"
	@echo "#  Routing...                            #"
	@echo "#                                        #"
	@echo "##########################################"
	@echo
	par -w -ol high -mt 4 placed.ncd $@ $< | tee route.log

$(PROJECT_NAME).bit: $(PROJECT_NAME).ncd
	@echo
	@echo "##########################################"
	@echo "#                                        #"
	@echo "#  Generating bit file...                #"
	@echo "#                                        #"
	@echo "##########################################"
	@echo
	bitgen -g INIT_9K:YES $< $@ | tee bitgen.log

$(PROJECT_NAME).mcs: $(PROJECT_NAME).bit
	@echo
	@echo "##########################################"
	@echo "#                                        #"
	@echo "#  Generating programming file...        #"
	@echo "#                                        #"
	@echo "##########################################"
	@echo
	promgen -w -p mcs -c FF -o $@ -s 4096 -u 0000 $< -spi | tee promgen.log

flash: $(PROJECT_NAME).mcs
	@echo
	@echo "##########################################"
	@echo "#                                        #"
	@echo "#  Flashing...                           #"
	@echo "#                                        #"
	@echo "##########################################"
	@echo
	echo "setmode -bs" > flash.tmp
	echo "setcable -port auto" >> flash.tmp
	echo "identify" >> flash.tmp
	echo "attachflash -position 2 -spi \"W25Q64BV\"" >> flash.tmp
	echo "assignfiletoattachedflash -position 2 -file \"$<\"" >> flash.tmp
	echo "program -p 2 -spionly -e -loadfpga " >> flash.tmp
	echo "exit" >> flash.tmp
	impact -batch flash.tmp | tee flash.log

clean:
	git clean -Xdf

purge:
	git clean -xdf
	git reset --hard

