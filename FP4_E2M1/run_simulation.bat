@echo off
REM Batch file to compile and run DFT testbench using Icarus Verilog
REM Make sure Icarus Verilog is installed and in your PATH

echo ========================================
echo DFT Simulation Setup
echo ========================================
echo.

REM Clean previous build files
if exist sim.vvp del sim.vvp
if exist fft_waveform.vcd del fft_waveform.vcd

echo Compiling Verilog files...
echo.

REM Compile all modules from src and tb directories
iverilog -o sim.vvp ^
    src/multiplier.v ^
    src/adder.v ^
    src/memory_shaivi.v ^
    src/twiddle_rom.v ^
    src/butterfly.v ^
    src/agu.v ^
    src/fft_shaivi.v ^
    tb/tb_fft_shaivi.v 

REM Check if compilation was successful
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Compilation failed!
    echo Please check the error messages above.
    pause
    exit /b 1
)

echo.
echo Compilation successful!
echo.
echo ========================================
echo Running simulation...
echo ========================================
echo.

REM Run the simulation
vvp sim.vvp

REM Check if simulation completed
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Simulation failed!
    pause
    exit /b 1
)

echo.
echo ========================================
echo Simulation completed successfully!
echo ========================================
echo.
echo Waveform saved to: dft_waveform.vcd
echo.
echo To view waveforms, run: gtkwave dft_waveform.vcd
echo.

pause