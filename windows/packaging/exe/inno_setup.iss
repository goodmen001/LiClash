[Setup]
AppId={{APP_ID}}
AppVersion={{APP_VERSION}}
AppName={{DISPLAY_NAME}}
AppPublisher={{PUBLISHER_NAME}}
AppPublisherURL={{PUBLISHER_URL}}
AppSupportURL={{PUBLISHER_URL}}
AppUpdatesURL={{PUBLISHER_URL}}
DefaultDirName={{INSTALL_DIR_NAME}}
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename={{OUTPUT_BASE_FILENAME}}
Compression=lzma
SolidCompression=yes
SetupIconFile={{SETUP_ICON_FILE}}
WizardStyle=modern
PrivilegesRequired={{PRIVILEGES_REQUIRED}}
ArchitecturesAllowed={{ARCH}}
ArchitecturesInstallIn64BitMode={{ARCH}}

[Code]
procedure KillProcesses;
var
  Processes: TArrayOfString;
  i: Integer;
  ResultCode: Integer;
begin
  Processes := ['LiClash.exe', 'LiClashCore.exe', 'LiClashHelperService.exe'];

  for i := 0 to GetArrayLength(Processes)-1 do
  begin
    Exec('taskkill', '/f /im ' + Processes[i], '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

procedure RegisterHelperService;
var
  ResultCode: Integer;
  HelperPath: String;
  ServiceName: String;
begin
  ServiceName := 'LiClashHelperService';
  HelperPath := ExpandConstant('{app}\LiClashHelperService.exe');
  
  // 停止并删除旧服务（如果存在）
  Exec('sc', 'stop ' + ServiceName, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec('sc', 'delete ' + ServiceName, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  
  // 创建新服务
  Exec('sc', 'create ' + ServiceName + ' binPath= "' + HelperPath + '" start= auto', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  
  // 启动服务
  Exec('sc', 'start ' + ServiceName, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

procedure UnregisterHelperService;
var
  ResultCode: Integer;
  ServiceName: String;
begin
  ServiceName := 'LiClashHelperService';
  
  // 停止并删除服务
  Exec('sc', 'stop ' + ServiceName, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec('sc', 'delete ' + ServiceName, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

function InitializeSetup(): Boolean;
begin
  KillProcesses;
  Result := True;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // 安装完成后注册 Helper 服务
    RegisterHelperService;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    // 卸载前停止进程
    KillProcesses;
  end;
  
  if CurUninstallStep = usPostUninstall then
  begin
    // 卸载后删除服务
    UnregisterHelperService;
  end;
end;

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
{% if LOCALES %}
{% for locale in LOCALES %}
{% if locale.lang == 'zh' %}
Name: "chineseSimplified"; MessagesFile: {% if locale.file %}{{ locale.file }}{% else %}"compiler:Languages\\ChineseSimplified.isl"{% endif %}
{% endif %}
{% endfor %}
{% endif %}

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: {% if CREATE_DESKTOP_ICON != true %}unchecked{% else %}checkedonce{% endif %}
[Files]
Source: "{{SOURCE_DIR}}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"
Name: "{autodesktop}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"; Tasks: desktopicon
[Run]
Filename: "{app}\\{{EXECUTABLE_NAME}}"; Description: "{cm:LaunchProgram,{{DISPLAY_NAME}}}"; Flags: {% if PRIVILEGES_REQUIRED == 'admin' %}runascurrentuser{% endif %} nowait postinstall skipifsilent