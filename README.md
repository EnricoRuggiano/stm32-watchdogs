# Stm32 Watchdogs

This project contains the SystemVerilog implementation of Indipendent Watchdog and Window Watchdog of the Stm32. 

The specification are taken from chapter 19 and 20 of the STM RM0008 Reference Manual
 accessible taken in this [link](https://www.st.com/content/ccc/resource/technical/document/reference_manual/59/b9/ba/7f/11/af/43/d5/CD00171190.pdf/files/CD00171190.pdf/jcr:content/translations/en.CD00171190.pdf). 

## Wishbone communication

The components implements the wishbone communication protocol whose specification can be found on this [link](https://cdn.opencores.org/downloads/wbspec_b4.pdf).

### Testbenches

Each module has a testbench in which are tested direct on the simulation the main functionalities and the READ, WRITE and RESET operation. 

For more info look direct on the code comments.

## LICENSE
MIT license

Copyright (c) 2019 Enrico Ruggiano

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.