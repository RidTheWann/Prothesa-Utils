; Prothesa Util — Inno Setup script (per-user, tanpa admin).
; Dibangkitkan/diisi versinya oleh Build-Setup.ps1 (app-version.isi).
#define MyAppName "Prothesa Util"
#define MyAppPublisher "Ridwan Gatro (RidTheWann)"
#define MyAppPublisherURL "https://github.com/RidTheWann"
#define MyAppCopyright "Copyright (C) 2026 Ridwan Gatro (RidTheWann) untuk drg. Danny Hanggono"
#define MyAppExe "ProthesaUtil.exe"
#include "app-version.isi"

[Setup]
AppId={{3F2A1B4C-9D8E-4F7A-8C6B-1A2B3C4D5E6F}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppPublisherURL}
AppCopyright={#MyAppCopyright}
DefaultDirName={localappdata}\ProthesaUtil
PrivilegesRequired=lowest
OutputDir=Output
OutputBaseFilename=ProthesaUtil-Setup-{#MyAppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
; Data user (data\ + *.prothesa) SENGAJA tidak dihapus saat uninstall (aman).
UninstallDisplayName={#MyAppName}

[Languages]
; Default English (Indonesian.isl tidak selalu tersedia di instalasi Inno).

[Tasks]
Name: "desktoppicon"; Description: "Ikon Desktop"; GroupDescription: "Ikon tambahan:"
Name: "sampledata"; Description: "Pasang data contoh terenkripsi (DPAPI akun ini)"; GroupDescription: "Data awal:"

[Files]
Source: "stage\ProthesaUtil.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "stage\ProthesaDataVault.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "stage\Seed-Sample.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "stage\ProthesaConfig.default.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "stage\*.prothesa"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "stage\*.prothesa.json"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

[Icons]
Name: "{autoprograms}\Prothesa Util"; Filename: "{app}\{#MyAppExe}"
Name: "{autodesktop}\Prothesa Util"; Filename: "{app}\{#MyAppExe}"; Tasks: desktoppicon

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Seed-Sample.ps1"" -AppDir ""{app}"""; Tasks: sampledata; Flags: runhidden; StatusMsg: "Memasang data contoh..."
Filename: "{app}\{#MyAppExe}"; Description: "Jalankan Prothesa Util"; Flags: nowait postinstall skipifsilent

[Code]
var
  BraceOpen: String;
  BraceClose: String;

function RegSubKey(const Leaf: String): String;
begin
  Result := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + Leaf;
end;

function IsProthesaInstalled(): Boolean;
var
  GuidLeaf: String;
begin
  GuidLeaf := BraceOpen + '3F2A1B4C-9D8E-4F7A-8C6B-1A2B3C4D5E6F' + BraceClose + '_is1';
  Result := RegKeyExists(HKEY_CURRENT_USER, RegSubKey('ProthesaUtil_is1'))
         or RegKeyExists(HKEY_CURRENT_USER, RegSubKey('ProthesaUtil'))
         or RegKeyExists(HKEY_CURRENT_USER, RegSubKey(GuidLeaf));
end;

function InitializeSetup(): Boolean;
begin
  BraceOpen := '{';
  BraceClose := '}';
  Result := True;
  if IsProthesaInstalled() then
  begin
    { Mode senyap: jangan tampilkan dialog (mencegah hang), cukup abort dengan exit code. }
    if not WizardSilent() then
      MsgBox('Prothesa Util sudah terinstall di komputer ini.' + #13#10 + #13#10 + 'Uninstall dulu melalui Settings > Apps sebelum memasang ulang.', mbInformation, MB_OK);
    Result := False;
  end;
end;
