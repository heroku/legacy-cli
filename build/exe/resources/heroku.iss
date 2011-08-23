[Setup]
AppName=Heroku
AppVersion=<%= version %>
DefaultDirName={pf}\Heroku
DefaultGroupName=Heroku
Compression=lzma2
SolidCompression=yes
OutputBaseFilename=heroku-<%= version %>
OutputDir=<%= original_project_root %>\pkg

; For Ruby expansion ~ 32MB (installed) - 12MB (installer)
ExtraDiskSpaceRequired=20971520

[Files]
Source: "<%= project_root %>\data\git.exe"; DestDir: "{tmp}";
Source: "<%= project_root %>\data\rubyinstaller.exe"; DestDir: "{tmp}";
Source: "<%= project_root %>\*.*"; DestDir: "{app}"; Flags: recursesubdirs;

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
Filename: "{tmp}\rubyinstaller.exe"; Parameters: "/silent /nocancel /noicons /dir=""{app}/ruby"""; \
  Flags: shellexec waituntilterminated; StatusMsg: "Installing Ruby";

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

