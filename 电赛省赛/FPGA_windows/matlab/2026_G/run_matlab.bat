@echo off
REM Run a MATLAB script in non-interactive batch mode
REM Usage: run_matlab.bat <script_name.m>

set SCRIPT=%1
if "%SCRIPT%"=="" set SCRIPT=plot_spectrum.m

set MATLAB="C:\Program Files\Matlab\bin\matlab.exe"
set CODE_DIR=C:\Users\24307\Desktop\FPGA_windows\matlab\2026_G\code

cd /d "%CODE_DIR%"
echo Running %SCRIPT% in %CODE_DIR% ...

%MATLAB% -batch "try, run('%SCRIPT%'), catch err, fprintf('MATLAB error code: %s\n', err.identifier), fprintf('MATLAB msg : %s\n', char(err.message)), exit(1), end, exit(0)"
echo MATLAB finished with errorlevel %errorlevel%