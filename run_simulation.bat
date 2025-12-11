@echo off
echo Compiling FP4 FFT Memory Testbench...
iverilog -o sim.vvp src/memory.v tb/tb_memory.v

echo.
echo Running Simulation...
vvp sim.vvp

echo.
echo Opening Waveform...
if exist waves.vcd (
    echo Use: gtkwave waves.vcd
    rem Uncomment next line to auto-open:
    rem gtkwave waves.vcd
)

pause