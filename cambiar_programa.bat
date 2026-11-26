@echo off
REM Uso: cambiar_programa.bat leds   o   cambiar_programa.bat invaders
REM Copia los .hex del programa elegido a la raiz. Despues hay que recompilar en Quartus.
cd /d "%~dp0"
if "%1"=="" goto uso
if not exist "programas\%1\imem.hex" goto uso
copy /Y "programas\%1\imem.hex" . >nul
copy /Y "programas\%1\dmem_b0.hex" . >nul
copy /Y "programas\%1\dmem_b1.hex" . >nul
copy /Y "programas\%1\dmem_b2.hex" . >nul
copy /Y "programas\%1\dmem_b3.hex" . >nul
echo Programa "%1" copiado. Recompila en Quartus y programa el .sof.
goto fin
:uso
echo Uso: cambiar_programa.bat leds ^| invaders
dir /b programas
:fin
