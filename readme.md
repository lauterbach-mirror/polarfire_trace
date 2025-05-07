# Trace support for PolarFire® SoC (RISC-V + FPGA)

This repository contains resources to implement off-chip trace of the hard RISC-V cores of a PolarFire® SoC with Lauterbach tools.

Trace can be exported using parallel trace (4, 8, or 16 data lines) with a PowerTrace 2/3 with an AutoFocus-II preprocessor.
Alternatively, serial trace can be used with a PowerTrace Serial.
Suggested serial configurations are one lane at 10 Gbit/s or two lanes at 5 GBit/s.
Each configuration is as fast as a 16-bit parallel trace.

Off-chip trace on this platform requires a component in the FPGA that receives trace data from the SMB (System Memory Buffer) component in the MSS and forwards it to the off-chip trace port.
The SMB is normally used for on-chip trace and uses internal RAM or SDRAM as a trace buffer.
However, in this application, the data is written to a small 4-KiB address range implemented by the `axi_to_pti` or `axi_to_aurora` IP included in this repository.

## Supported evaluation boards

We support the following adaptions and evaluation boards:

* PolarFire® SoC Video Kit via FMC connector using one of the following adapters:

  * Lauterbach [LA-2785](https://www.lauterbach.com/products/LA-2785);
    This adapter allows parallel trace or serial trace.
  * Xilinx/AMD [FMC XM105](https://www.xilinx.com/products/boards-and-kits/hw-fmc-xm105-g.html) card;
    This adapter only allows parallel trace.

  For 16-bit parallel trace, these adapters are pin compatible, so the same FPGA design can support both cards.
  For the converter's pin map, refer to `script_support/videokit/io_videokit_fmc.pdc` in this repository.
* PolarFire® SoC FPGA Icicle Kit via RPi connector using Lauterbach [LA-3884](https://www.lauterbach.com/products/LA-3884);
  For the converter's pin map, refer to `script_support/icicle/io_icicle_rpi.pdc` in this repository.

Of course, trace is also possible with other boards, but for these, the user will need to create their own FPGA design.

## Running the demos

Lauterbach hardware/software requirements:

* PowerDebug X50/PRO/II
* parallel trace: PowerTrace 2/3 with AutoFocus-II preprocessor
* serial trace: PowerTrace Serial or PowerTrace Serial 2
* IDC20A cable
* Debug and trace licenses for RISC-V
* TRACE R.2025.02 or a later release

Instructions:

1. Use the scripts `lb_cmm/00_program_videokit_16.cmm`, `lb_cmm/01_program_videokit_1lane.cmm`, `lb_cmm/02_program_videokit_2lane.cmm` or `lb_cmm/03_program_icicle_16.cmm` to program the FPGA.
   This takes a few minutes, but only needs to be done once.
2. If you use the icicle demo, set J46 to supply the trace reference voltage to the preprocessor.
3. Use the script `lb_cmm/10_run_sieve_demo_16.cmm` (parallel trace) or `lb_cmm/11_run_sieve_demo_1lane.cmm`/`lb_cmm/12_run_sieve_demo_2lane.cmm` (serial trace) to debug and trace a simple sieve demo.

## Generating the example bitstreams with Libero

The following instructions will generate a minimal FPGA project with just the MSS (microprocessor subsystem), trace and SDRAM connection.
The scripts require exactly Libero 2024.2.

1. Start Libero.
2. Invoke Project→Execute Script…
3. Select either `generate_icicle_project.tcl`, or `generate_videokit_project.tcl` or `generate_videokit_project_aurora.tcl`, depending on the desired evaluation board and trace type.
   For parallel trace, you can specify the number of trace data bits `<n>` (4, 8, 16) as an argument.
   The default is 16 bits.
   For serial trace, you can specify `1lane` or `2lane` as an argument to choose the desired setup.
   The default is `1lane`.
4. Click Run.
   This generates the new project as `trace_icicle_<n>` or `trace_videokit_<n>` in the same directory as the tcl scripts.
   Note that all the settings from the `script_support/` directory as well as all the HDL files from the `hdl_src/` directory are copied/imported into the project.
   Changing them after running the script will have no effect.
   Re-running the script will erase and regenerate the `trace_icicle_<n>`/`trace_videokit_<n>` directory, so all modifications will be lost.
5. Double-click “Place and Route” in the “Design Flow” tab.
   This will run the complete implementation of the design.
6. Double-click “Export Bitstream” in the “Design Flow” tab.
   Select the STAPL format.
   Click OK.
   This generates a bitstream (.stp file) suitable for programming with TRACE32.

## Simulating the example projects

The example projects include a testbench that can be used to do a pre-synthesis integration test of the complete trace path.
To run the testbench:

1. Open one of the example projects with Libero.
2. In the “Design Flow” tab, double-click on “Create Design→Verify Pre-Synthesized Design→Simulate”.

QuestaSim or Modelsim should open and automatically compile and simulate the project.
The signal `oDone` should switch to `'1'` near the end of the simulation run.
This indicates that all pseudo-random data that was written by the simulated MSS component passed through the `axi_to_pti` or `axi_to_aurora` component and was decoded and verified successfully by the testbench.

## Integrating the `axi_to_pti` IP into an existing FPGA design

The following instructions describe how to add off-chip trace to an existing design.
Use these instructions if you want to use something other than the supported evaluation boards or if your application uses other IP inside the FPGA.

Some familiarity with Libero and FPGA design in general is required to follow these steps.
It is recommended to also generate and study one of the example designs (see previous section).

These instructions were tested with Libero 2024.2, but should work with future releases as well.

1. Open the project you wish to modify.
2. Invoke Project→Execute Script…
3. Select `axi_to_pti.tcl` and click Run.
4. Instantiate the `axi_to_pti` HDL+ component in your design and set the `gOutBits` parameters to the desired trace port size.
5. Connect the `oTraceClk` and `oTraceData` outputs to FPGA pins. These will also need matching I/O constraints matching the board schematic.
6. Connect the AXI interface to either the `FIC_0_AXI4_INITIATOR` or `FIC_1_AXI4_INITIATOR` interfaces of the MSS.
   You will need a CoreAXI4Interconnect component between the MSS and the `axi_to_pti_wrapper` instance.
   The converter IP only needs a 4-KiB address range and only needs write access.
   Check the example designs for more details.
7. The base address where the MSS can write to the converter IP needs to be configured in TRACE32 using the `SYStem.CONFIG USOCSMB.BufferBase` command.

## Integrating the `axi_to_aurora` IP into an existing FPGA design

The following instructions describe how to add off-chip trace to an existing design.
Use these instructions if you want to use something other than the supported evaluation boards or if your application uses other IP inside the FPGA.

Some familiarity with Libero and FPGA design in general is required to follow these steps.
It is recommended to also generate and study one of the example designs (see previous section).

These instructions were tested with Libero 2024.2, but should work with future releases as well.

1. Open the project you wish to modify.
2. Invoke Project→Execute Script…
3. Select `axi_to_aurora.tcl` and click Run.
4. Instantiate the `axi_to_aurora_1lane` or `axi_to_aurora_2lane` HDL+ component in your design.
5. If not already in your design, Instantiate a Transceiver Interface (`PF_XCVR_ERM`) and supporting clocking infrastructure (Transmit PLL and Transceiver Reference clock).
   For the serial trace to work properly ensure to
    - set Transmit PLL into Integer Mode and
    - set `PF_XCVR_ERM` to have either
       - 1 TX lane configured with 8b10b encoding and 32 bit TX PCS-Fabric Interface width or
       - 2 TX lanes configured with 8b10b encoding and 16 bit TX PCS-Fabric Interface width.

   All other parameters (datarate, frequency, clock source) are highly specific to the used board, clocking sources, and the rest of the project.
   Refer to the videokit example project for details.
6. Connect the AXI interface to either the `FIC_0_AXI4_INITIATOR` or `FIC_1_AXI4_INITIATOR` interfaces of the MSS.
   You will need a CoreAXI4Interconnect component between the MSS and the `axi_to_pti_wrapper` instance.
   The converter IP only needs a 4-KiB address range and only needs write access.
   Check the example designs for more details.
7. The base address where the MSS can write to the converter IP needs to be configured in TRACE32 using the `SYStem.CONFIG USOCSMB.BufferBase` command.
