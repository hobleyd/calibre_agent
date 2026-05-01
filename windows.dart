import 'dart:io';

import 'package:version/version.dart';

void main() {
  final version = Version.parse(Platform.environment['VERSION']!);
  final versionStr = Platform.environment['VERSION']!;
  final issPath = 'build/windows/calibre-agent-$versionStr.iss';

  _writeIssFile(issPath, version, versionStr);
  _compile(issPath);
}

void _writeIssFile(String issPath, Version version, String versionStr) {
  final iss = '''
[Setup]
AppName=Calibre Agent
AppVersion=$version
AppPublisher=SharpBlue
AppPublisherURL=https://sharpblue.com.au/
AppSupportURL=https://sharpblue.com.au/
AppUpdatesURL=https://sharpblue.com.au/
DefaultDirName={autopf}\\Calibre Agent
DefaultGroupName=Calibre Agent
OutputDir=.
OutputBaseFilename=calibre-agent-$versionStr
SetupIconFile=..\\..\\windows\\runner\\Resources\\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "x64\\runner\\Release\\calibre_agent.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "x64\\runner\\Release\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\\Calibre Agent"; Filename: "{app}\\calibre_agent.exe"
Name: "{group}\\Uninstall Calibre Agent"; Filename: "{uninstallexe}"
Name: "{autodesktop}\\Calibre Agent"; Filename: "{app}\\calibre_agent.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\\calibre_agent.exe"; Description: "{cm:LaunchProgram,Calibre Agent}"; Flags: nowait postinstall skipifsilent
''';

  File(issPath).writeAsStringSync(iss);
}

void _compile(String issPath) {
  try {
    const iscc = 'iscc';
    final result = Process.runSync(iscc, [issPath], runInShell: true);
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode != 0) {
      throw ProcessException(iscc, [issPath], 'iscc failed with exit code ${result.exitCode}', result.exitCode);
    }
    print('Done.');
  } catch (e, s) {
    print('Failed: $e\n$s');
  }
}
