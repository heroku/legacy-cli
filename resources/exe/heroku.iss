[Setup]
AppName=Heroku Toolbelt
AppVersion=<%= version %>
AppVerName=Heroku Toolbelt <%= version %>
AppPublisher=Heroku, Inc.
AppPublisherURL=http://www.heroku.com/
DefaultDirName={pf}\Heroku
DefaultGroupName=Heroku
Compression=lzma2
SolidCompression=yes
OutputBaseFilename=<%= File.basename(exe_task.name, ".exe") %>
OutputDir=..
ChangesEnvironment=yes
UsePreviousSetupType=no
AlwaysShowComponentsList=no

; For Ruby expansion ~ 32MB (installed) - 12MB (installer)
ExtraDiskSpaceRequired=20971520

[Types]
Name: client; Description: "Full Installation";
Name: custom; Description: "Custom Installation"; flags: iscustom

[Components]
Name: "toolbelt"; Description: "Heroku Toolbelt"; Types: "client custom"
Name: "toolbelt/client"; Description: "Heroku Client"; Types: "client custom"; Flags: fixed
Name: "toolbelt/git"; Description: "Git and SSH"; Types: "client custom"; Check: IsGitNotInstalled()

[Files]
Source: "heroku\*.*"; DestDir: "{app}"; Flags: recursesubdirs; Components: "toolbelt/client"
Source: "installers\rubyinstaller-2.1.7.exe"; DestDir: "{tmp}"; Components: "toolbelt/client"
Source: "installers\git-2.8.0.exe"; DestDir: "{tmp}"; Components: "toolbelt/git"; Check: IsGitNotInstalled()

[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: "expandsz"; ValueName: "HerokuPath"; \
  ValueData: "{app}"
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: "expandsz"; ValueName: "Path"; \
  ValueData: "{olddata};{app}\bin"; Check: NeedsAddPath(ExpandConstant('{app}\bin'))
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: "expandsz"; ValueName: "Path"; \
  ValueData: "{olddata};{pf}\git\cmd"; Check: IsGitNotInstalled() and NeedsAddPath(ExpandConstant('{pf}\git\cmd'))

[Run]
Filename: "{tmp}\rubyinstaller-2.1.7.exe"; Parameters: "/verysilent /noreboot /nocancel /noicons /dir=""{app}/ruby-2.1.7"""; \
  Flags: shellexec waituntilterminated; StatusMsg: "Installing Ruby"; Components: "toolbelt/client"
Filename: "{tmp}\git-2.8.0.exe"; Parameters: "/verysilent /nocancel /noicons"; \
  Flags: shellexec waituntilterminated; StatusMsg: "Installing Git"; Components: "toolbelt/git"; Check: IsGitNotInstalled()

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\heroku"
Type: filesandordirs; Name: "{%UserProfile}\.heroku"

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

function IsGitNotInstalled(): boolean;
begin
  Result := not RegKeyExists(HKLM, 'Software\GitForWindows');
end;
