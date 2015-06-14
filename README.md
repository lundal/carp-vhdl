## Cellular Automata Research Platform - VHDL

This repository contains the hardware design for my work on the Cellular Automata Research Platform at the Norwegian University of Science and Technology.

#### Requirements
* SP605 Evaluation Kit
* Xilinx ISE 13.3 or newer (older versions might work if PCI Express Core is replaced)
* USB driver from http://rmdir.de/~michael/xilinx/ if the one provided by Xilinx does not work
* Basic development tools (Bash, Make, Git, Sed)

#### SP605 setup
* Everything should be set to factory default (as per UG526)
* SW1 should be set to 10 (M0=1 and M1=0)

#### Customization
* Synthesis parameters are found in parameters.conf
* Fitness parameters must be edited in their respective VHDL files

#### How to flash
1. $ source /path/to/ise/settings[32|64].sh
2. $ make flash

#### How to open project in ISE
1. $ source /path/to/ise/settings[32|64].sh
2. $ make rebuild
3. $ ise
4. Open carp.xise

#### Notes
* Flashing is not supported in ISE
* Simulations can only be started from ISE
* Changing hardware requires replacement of the sp605 directory and the ip core, plus modifications to the makefile
