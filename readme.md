# Trace support for PolarFire SoC (RISC-V + FPGA)

This repository contains resources to implement off-chip trace of the hard RISC-V cores of a PolarFile SoC with Lauterbach tools.

Currently, only 16-bit parallel trace using a PowerTrace 2/3 with an AutoFocus-II preprocessor is implemented.
Serial Aurora/HSSTP trace should be possible using some additional logic in the PolarFire FPGA.
PCIe trace would also be possible, but requires more changes to TRACE32.

Off-chip trace on this platform requires a component in the FPGA that receives trace data from the SMB (System Memory Buffer) component in the HSS and forwards it to the off-chip trace port.
The SMB is normally used for on-chip trace and uses internal RAM or SDRAM as a trace buffer.
However, in this application, the Data is written to a small 4-KiB address range implemented by the `axi_to_pti` IP included in this repository.

Currently, the converter IP uses a single clock source both for the AXI interface as well as for trace output and is hardcoded to use 16 data bits.
This can be changed, see the comments in `axi_to_pti/axi_to_pti.vhd`.

## Supported evaluation boards

We support the following adaptions and evaluation boards:

* PolarFire® SoC Video Kit via FMC connector using one of the following adapters:

  * Lauterbach LA-2785;
    This adapter would also allow testing 32-bit parallel trace or Aurora/HSSTP trace, but neither has been implemented yet.
  * Xilinx/AMD FMC XM105 card;
    This adapter only allows 16-bit parallel trace.

  For 16-bit parallel trace, these adapters are pin compatible, so the same FPGA design can support both cards.
  For the converter's pin map, refer to `script_support/videokit/io_videokit_fmc.pdc` in this repository.
* PolarFire® SoC FPGA Icicle Kit via RPi connector using a Lauterbach adapter that will be available in Q3/2024;
  For the converter's pin map, refer to `script_support/icicle/io_icicle_rpi.pdc` in this repository.

Of course, trace is also possible with other boards, but for these, the user will need to create their own FPGA design.

## Running the demos

Lauterbach hardware/software requirements:

* PowerDebug X50/PRO/II
* PowerTrace 2/3 with AutoFocus-II preprocessor
* IDC20A cable
* Debug and trace licenses for RISC-V
* At reast TRACE32 build 168513., i. e. a nightly from 2024-04-13 or later or R.2024.09 release

Instructions:

1. Use the scripts `lb_cmm/0_program_videokit.cmm` or `lb_cmm/1_program_icicle.cmm` to program the FPGA.
   This takes a few minutes, but only needs to be done once.
2. If you use the icicle demo, set J46 to supply the trace reference voltage to the preprocessor.
3. Use the script `lb_cmm/2_run_sieve_demo.cmm` to debug and trace a simple sieve demo.

## Generating the example bitstreams with Libero

The following instructions will generate a minimal FPGA project with just the HSS (hard software services), trace and SDRAM connection.
The scripts require exactly Libero 2023.2.

1. Start Libero.
2. Invoke Project→Execute Script…
3. Select either `generate_icicle_project.tcl` or `generate_videokit_project.tcl`, depending on the desired evaluation board.
   The script needs no arguments.
4. Click Run.
   This generates the new project as `trace_icicle` or `trace_videokit` in the same directory as the tcl scripts.
   Note that all the settings from the `script_support/` directory as well as all the HDL files from the `axi_to_pti/` directory are copied/imported into the project.
   Changing them after running the script will have no effect.
   Re-running the script will erase and regenerate the `trace_icicle`/`trace_videokit` directory, so all modifications will be lost.
5. Double-click “Place and Route” in the “Design Flow” tab.
   This will run the complete implementation of the design.
6. Double-click “Export Bitstream” in the “Design Flow” tab.
   Select the STAPL format.
   Click OK.
   This generates a bitstream (.stp file) suitable for programming with TRACE32.

## Integrating the `axi_to_pti` IP into an existing FPGA design

The following instructions describe how to add off-chip trace to an existing design.
Use these instructions if you want to use something other than the supported evaluation boards or if your application uses other IP inside the FPGA.

Some familiarity with Libero and FPGA design in general is required to follow these steps.
It is recommended to also generate and study one of the example designs (see previous section).

These instructions were tested with Libero 2023.2, but should work with future releases as well.

1. Import or link all the HDL files under `axi_to_pti` in this repository.
2. Click “Build Hierarchy” in the “Design Hierarchy” tab.
3. Right click on the `axi_to_pti_wrapper(behavioral)` file in the “Design Hierarchy” tab, select “Create core from HDL…”.
4. When it asks you whether you would like to remove parameters or add bus interfaces, click “Yes”.
5. Click “Add/Edit bus interfaces…”.
6. Click “Add Bus Interface”
7. Select “AXI4/AMBA/AMBA4/slave”, click “OK”.
8. The default assignments should be OK. Optionally change the name of the bus interface, then click “Apply” and “Close”.
9. Click “OK”.
10. Instantiate the `axi_to_pti_wrapper` HDL+ component in your design.
11. Connect the `oTraceClk` and `oTraceData` outputs to FPGA pins. These will also need matching I/O constraints matching the board schematic.
12. Connect the AXI interface to either the `FIC_0_AXI4_INITIATOR` or `FIC_1_AXI4_INITIATOR` interfaces of the HSS.
    You will need a CoreAXI4Interconnect component between the HSS and the `axi_to_pti_wrapper` instance.
    The converter IP only needs a 4-KiB address range and only needs write access.
    Check the example designs for more details.
13. The base address where the HSS can write to the converter IP needs to be configured in TRACE32 using the `SYStem.CONFIG USOCSMB.BufferBase` command.
