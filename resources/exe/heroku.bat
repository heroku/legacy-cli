:: Don't use ECHO OFF to avoid possible change of ECHO
:: Use SETLOCAL so variables set in the script are not persisted
@SETLOCAL

:: Add bundled ruby version to the PATH, use HerokuPath as starting point
@SET HEROKU_RUBY="%HerokuPath%\ruby-1.9.3\bin"
@SET PATH=%HEROKU_RUBY%;%PATH%;%ProgramFiles(x86)%\Git\bin

:: Invoke 'heroku' (the calling script) as argument to ruby.
:: Also forward all the arguments provided to it.
@ruby.exe "%~dpn0" %*
