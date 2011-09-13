[Setup]
AppName=Heroku
AppVersion=<%= version %>
DefaultDirName={pf}\Heroku
DefaultGroupName=Heroku
Compression=lzma2
SolidCompression=yes
OutputBaseFilename=<%= File.basename(t.name, ".exe") %>
OutputDir=<%= File.dirname(t.name) %>

; For Ruby expansion ~ 32MB (installed) - 12MB (installer)
ExtraDiskSpaceRequired=20971520

[Files]
Source: "installers\git.exe"; DestDir: "{tmp}";
Source: "installers\foreman-setup.exe"; DestDir: "{tmp}";
Source: "installers\rubyinstaller.exe"; DestDir: "{tmp}";
Source: "heroku-toolbelt\*.*"; DestDir: "{app}"; Flags: recursesubdirs;

[UninstallDelete]
Type: filesandordirs; Name: "{app}\ruby"

[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: "expandsz"; ValueName: "HerokuPath"; \
  ValueData: "{app}"
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: "expandsz"; ValueName: "Path"; \
  ValueData: "{olddata};{app}"; Check: NeedsAddPath(ExpandConstant('{app}'))

[Run]
Filename: "{tmp}\git.exe"; Parameters: "/silent /nocancel /noicons"; \
  Flags: shellexec waituntilterminated; StatusMsg: "Installing Git";
Filename: "{tmp}\foreman-setup.exe"; Parameters: "/silent /nocancel /noicons"; \
  Flags: shellexec waituntilterminated; StatusMsg: "Installing Foreman";
Filename: "{tmp}\rubyinstaller.exe"; Parameters: "/verysilent /noreboot /nocancel /noicons /dir=""{app}/ruby"""; \
  Flags: shellexec waituntilterminated; StatusMsg: "Installing Components";

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

