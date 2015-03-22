## Cellular Automata Research Platform - VHDL

This repository contains the hardware design for my work on the Cellular Automata Reasearch Platform at the Norwegian University of Science and Technology

#### How to flash
1. source /path/to/ise/13.3/settings[32|64].sh
2. make regenerate
3. make flash

#### Requirements
* SP605 Evaluation Kit
* Xilinx ISE 13.3 or newer (older versions might work if PCIe ipcore is replaced)
* USB driver from http://rmdir.de/~michael/xilinx/ if the one provided by Xilinx does not work

#### Board setup
* Everything should be set to factory default (as per ug526)
* SW1 should be set to 10
