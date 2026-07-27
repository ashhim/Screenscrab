[Setup]
AppName=Screenscrab
AppVersion=0.1.0
DefaultDirName={pf}\Screenscrab
DefaultGroupName=Screenscrab
OutputBaseFilename=ScreenscrabSetup
Compression=lzma2
SolidCompression=yes

[Files]
Source: "..\..\..\apps\windows\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\Screenscrab"; Filename: "{app}\screenscrab_windows.exe"

[Run]
Filename: "{app}\screenscrab_windows.exe"; Description: "Launch Screenscrab"; Flags: nowait postinstall skipifsilent
