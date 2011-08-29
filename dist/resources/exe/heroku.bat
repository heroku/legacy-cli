@ECHO OFF
IF NOT "%~f0" == "~f0" GOTO :WinNT
@"%HerokuPath%\\ruby\\bin\\ruby.exe" "heroku" %1 %2 %3 %4 %5 %6 %7 %8 %9
GOTO :EOF
:WinNT
@"%HerokuPath%\\ruby\\bin\\ruby.exe" "%~dpn0" %*
