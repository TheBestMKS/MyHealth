#ifndef SourceDir
  #error SourceDir is required
#endif
#ifndef OutputDir
  #error OutputDir is required
#endif
#ifndef Edition
  #define Edition "Lite"
#endif
#ifndef ArtifactName
  #define ArtifactName "MyHealth-Windows-Setup"
#endif

#define MyAppName "Моё здоровье"
#ifndef MyAppVersion
  #define MyAppVersion "1.8.1"
#endif
#define MyAppExeName "my_health.exe"

[Setup]
AppId={{77BDF7A3-52A4-4C1D-9258-F695C30F2AC8}
AppName={#MyAppName} ({#Edition})
AppVersion={#MyAppVersion}
AppPublisher=MyHealth
DefaultDirName={localappdata}\Programs\MyHealth
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir={#OutputDir}
OutputBaseFilename={#ArtifactName}
SetupIconFile={#SourcePath}\..\icon\logo.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/max
SolidCompression=no
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Excludes: "*.gguf"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SourceDir}\data\flutter_assets\assets\models\*.gguf"; DestDir: "{app}\data\flutter_assets\assets\models"; Flags: ignoreversion nocompression skipifsourcedoesntexist

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Создать значок на рабочем столе"; GroupDescription: "Дополнительные значки:"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Запустить {#MyAppName}"; Flags: nowait postinstall skipifsilent
