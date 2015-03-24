## Cellular Automata Research Platform - VHDL

This repository contains the hardware design for my work on the Cellular Automata Reasearch Platform at the Norwegian University of Science and Technology

#### How to flash
1. Run source /path/to/ise/settings[32|64].sh
2. Run make flash

#### How to open project in ISE
1. Run source /path/to/ise/settings[32|64].sh
2. Run make rebuild
3. Run ise
4. Open carp.xise

#### Requirements
* SP605 Evaluation Kit
* Xilinx ISE 13.3 or newer (older versions might work if PCIe ipcore is replaced)
* USB driver from http://rmdir.de/~michael/xilinx/ if the one provided by Xilinx does not work
* Basic development tools (Make, Git, Sed)

#### Board setup
* Everything should be set to factory default (as per ug526)
* SW1 should be set to 10
