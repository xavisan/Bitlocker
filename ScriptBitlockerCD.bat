@echo off

set test /a = "xavisan2021"

:EncriptionVerify
SET DRIVEENCRIPCION=C:
Goto ValidateEncription
:EncryptionCompletedD
SET DRIVEENCRIPCION=D:
Goto ValidateEncription

:ElevateA
goto ElevateAccess

:TPMActivate
powershell Get-BitlockerVolume
echo.
echo  =============================================================
echo  = It looks like your System Drive (%DRIVEENCRIPCION%\) is not              =
echo  = encrypted. Let's try to enable BitLocker.                =
echo  =============================================================
for /F %%A in ('wmic /namespace:\\root\cimv2\security\microsofttpm path win32_tpm get IsEnabled_InitialValue ^| findstr "TRUE"') do (
if "%%A"=="TRUE" goto nextcheck
)
goto TPMFailure

:nextcheck
for /F %%A in ('wmic /namespace:\\root\cimv2\security\microsofttpm path win32_tpm get IsEnabled_InitialValue ^| findstr "TRUE"') do (
if "%%A"=="TRUE" goto starttpm
)
goto TPMFailure


@echo =========================== Start the encription process
:starttpm
powershell Initialize-Tpm

:bitlock_C
SET DRIVEENCRIPCION=C:
Goto bitlock
:bitlock_D
SET DRIVEENCRIPCION=D:
Goto bitlock
:continue_process
Goto EncryptionCompleted


:TPMFailure
echo.
echo  =============================================================
echo  = System Volume Encryption on drive (%DRIVEENCRIPCION%\) failed.           
echo  = The problem could be the Tpm Chip is off in the BiOS.     
echo  = Make sure the TPMPresent and TPMReady is True.            
echo  =                                                           
echo  = See the Tpm Status below                                  
echo  =============================================================
powershell get-tpm
echo  Closing session in 30 seconds...
TIMEOUT /T 30 /NOBREAK
Exit

:EncryptionCompleted
echo.
echo  =============================================================
echo  = It looks like your System drive (%DRIVEENCRIPCION%) is    
echo  = already encrypted or it's in progress. See the drive      
echo  = Protection Status below.                                  
echo  =============================================================
powershell Get-BitlockerVolume
echo  Closing session in 20 seconds...
TIMEOUT /T 20 /NOBREAK
Exit

:ElevateAccess
echo  ==========================================================================
echo  = It looks like your system require that you run this       
echo  = program as an Administrator. 
echo  = Or your system is already Encripted.                             
echo  =                                                           
echo  = Please right-click the file and run as Administrator, if correspond it.     
echo  ==========================================================================
echo  Closing session in 20 seconds...
TIMEOUT /T 20 /NOBREAK
Exit

:bitlock
echo ==============================================================
echo = System Volume Encription on drive (%DRIVEENCRIPCION%)      
echo ==============================================================
powershell Initialize-Tpm
manage-bde -protectors -disable %DRIVEENCRIPCION%
bcdedit /set {default} recoveryenabled No
bcdedit /set {default} bootstatuspolicy ignoreallfailures
manage-bde -protectors -delete %DRIVEENCRIPCION% -type RecoveryPassword
manage-bde -protectors -add %DRIVEENCRIPCION% -RecoveryPassword
for /F "tokens=2 delims=: " %%A in ('manage-bde -protectors -get %DRIVEENCRIPCION% -type recoverypassword ^| findstr "       ID:"') do (
	echo %%A
	manage-bde -protectors -adbackup %DRIVEENCRIPCION% -id %%A
)
manage-bde -protectors -enable %DRIVEENCRIPCION%
manage-bde -on %DRIVEENCRIPCION% -SkipHardwareTest
for /F "tokens=3 delims= " %%A in ('manage-bde -status %DRIVEENCRIPCION% ^| findstr "    Encryption Method:"') do (
	if "%%A"=="None" goto TPMFailure
	)
if "%DRIVEENCRIPCION%"=="C:" goto bitlock_D
goto continue_process
goto :eof


:ValidateEncription
echo =========================================================================
echo = System Volume Validation Encription on drive (%DRIVEENCRIPCION%)      
echo =========================================================================
for /F "tokens=3 delims= " %%A in ('manage-bde -status %DRIVEENCRIPCION% ^| findstr "    Encryption Method:"') do (
	if "%%A"=="AES" goto EncryptionCompletedC
	)
for /F "tokens=3 delims= " %%A in ('manage-bde -status %DRIVEENCRIPCION% ^| findstr "    Encryption Method:"') do (
	if "%%A"=="XTS-AES" goto EncryptionCompletedC
	)
for /F "tokens=3 delims= " %%A in ('manage-bde -status %DRIVEENCRIPCION% ^| findstr "    Encryption Method:"') do (
	if "%%A"=="None" goto TPMActivate
	)
:EncryptionCompletedC
powershell Get-BitlockerVolume
if "%DRIVEENCRIPCION%"=="C:" goto EncryptionCompletedD
Goto ElevateA
goto :eof
