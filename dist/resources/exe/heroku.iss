[Setup]
AppName=Heroku
AppVersion=<%= version %>
DefaultDirName={pf}\Heroku
DefaultGroupName=Heroku
Compression=lzma2
SolidCompression=yes
OutputBaseFilename=<%= File.basename(t.name, ".exe") %>
OutputDir=<%= File.dirname(t.name) %>
ChangesEnvironment=yes
UsePreviousSetupType=no

; For Ruby expansion ~ 32MB (installed) - 12MB (installer)
ExtraDiskSpaceRequired=20971520

[Types]
Name: client; Description: "Full Installation";
;Name: language; Description: "Full Installation"
Name: custom; Description: "Custom Installation"; flags: iscustom

[Components]
Name: "toolbelt"; Description: "Heroku Toolbelt"; Types: "client custom"
Name: "toolbelt/cli"; Description: "Heroku CLI"; Types: "client custom"; Flags: fixed
Name: "toolbelt/foreman"; Description: "Foreman"; Types: "client custom"
Name: "toolbelt/git"; Description: "Git"; Types: "client custom"; Check: "not IsProgramInstalled('git.exe')"
Name: "toolbelt/git"; Description: "Git"; Check: "IsProgramInstalled('git.exe')"
;Name: "language"; Description: "Language Packs"; Types: "language custom"
;Name: "language/ruby"; Description: "Ruby"; Types: "language custom"

[Files]
Source: "heroku-toolbelt\*.*"; DestDir: "{app}"; Flags: recursesubdirs; Components: "toolbelt/cli"
Source: "installers\foreman-setup.exe"; DestDir: "{tmp}"; Components: "toolbelt/foreman"
Source: "installers\git.exe"; DestDir: "{tmp}"; Components: "toolbelt/git"
Source: "installers\rubyinstaller.exe"; DestDir: "{tmp}"; Components: "toolbelt/cli"

[UninstallDelete]
Type: filesandordirs; Name: "{app}\ruby"

[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: "expandsz"; ValueName: "HerokuPath"; \
  ValueData: "{app}"
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: "expandsz"; ValueName: "Path"; \
  ValueData: "{olddata};{app}"; Check: NeedsAddPath(ExpandConstant('{app}'))
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: "expandsz"; ValueName: "Path"; \
  ValueData: "{olddata};{pf}\git\bin"; Check: NeedsAddPath(ExpandConstant('{pf}\git\bin'))
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: "expandsz"; ValueName: "Path"; \
  ValueData: "{olddata};{pf}\git\cmd"; Check: NeedsAddPath(ExpandConstant('{pf}\git\cmd'))
Root: HKCU; Subkey: "Environment"; ValueType: "expandsz"; ValueName: "HOME"; \
  ValueData: "%USERPROFILE%"; Flags: createvalueifdoesntexist
; Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: "expandsz"; ValueName: "GEM_HOME"; \
;   ValueData: "{commonappdata}\gems"; Flags: createvalueifdoesntexist; Components: "language/ruby"
; Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: "expandsz"; ValueName: "GEM_PATH"; \
;   ValueData: "{commonappdata}\gems"; Flags: createvalueifdoesntexist; Components: "language/ruby"

[Run]
Filename: "{tmp}\rubyinstaller.exe"; Parameters: "/verysilent /noreboot /nocancel /noicons /dir=""{app}/ruby"""; \
  Flags: shellexec waituntilterminated; StatusMsg: "Installing Heroku CLI"; Components: "toolbelt/cli"
Filename: "{app}\ruby\bin\gem.bat"; Parameters: "install taps --no-rdoc --no-ri"; \
  Flags: runhidden shellexec waituntilterminated; StatusMsg: "Installing Taps"; Components: "toolbelt/cli"
Filename: "{tmp}\foreman-setup.exe"; Parameters: "/silent /nocancel /noicons"; \
  Flags: shellexec waituntilterminated; StatusMsg: "Installing Foreman"; Components: "toolbelt/foreman"
Filename: "{tmp}\git.exe"; Parameters: "/silent /nocancel /noicons"; \
  Flags: shellexec waituntilterminated; StatusMsg: "Installing Git"; Components: "toolbelt/git"
; Filename: "{tmp}\rubyinstaller.exe"; Parameters: "/noreboot /silent /dir=""{pf}/Ruby"" /tasks=""MODPATH,ASSOCFILES"""; \
;   Flags: shellexec waituntilterminated; StatusMsg: "Installing Ruby"; Components: "language/ruby"
; Filename: "{pf}\ruby\bin\gem.bat"; Parameters: "install taps bundler rails sinatra --no-rdoc --no-ri"; \
;   Flags: shellexec waituntilterminated; StatusMsg: "Installing Taps"; Components: "language/ruby"

[Code]

function NeedsAddPath(Param: string): boolean;
var
  OrigPath: string;
begin
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', OrigPath)
  then begin
    Result := True;
    exit;
  end;
  // look for the path with leading and trailing semicolon
  // Pos() returns 0 if not found
  Result := Pos(';' + Param + ';', ';' + OrigPath + ';') = 0;
end;

function IsProgramInstalled(Name: string): boolean;
var
  ResultCode: integer;
begin
  Result := Exec(Name, 'version', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;
