Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Di EXE GUI (-noConsole) tidak ada console handle, jadi guard agar tidak fatal.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$ErrorActionPreference = 'Stop'

# ==============================================================================
# HIGH-DPI AWARENESS & VISUAL STYLES (CRITICAL FOR SHARP 1080P/1440P RENDERING)
# ==============================================================================
try {
    if (-not ([System.Management.Automation.PSTypeName]'ProthesaDpi').Type) {
        Add-Type -TypeDefinition @'
        using System;
        using System.Runtime.InteropServices;
        public class ProthesaDpi {
            [DllImport("user32.dll")]
            public static extern bool SetProcessDPIAware();
            [DllImport("shcore.dll")]
            public static extern int SetProcessDpiAwareness(int awareness);
        }
'@ -ErrorAction SilentlyContinue
    }
    try { [void][ProthesaDpi]::SetProcessDpiAwareness(1) } catch { [void][ProthesaDpi]::SetProcessDPIAware() }
} catch { }

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }

if (-not ($env:PROTHESA_NO_RELAUNCH -eq '1') -and [System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    $env:PROTHESA_NO_RELAUNCH = '1'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "$ScriptRoot\ProthesaWinUtil.ps1" | Out-Null
    exit
}

# WAJIB INSTALL: EXE hasil compile menolak berjalan portabel (double-click langsung).
# Penanda ditulis installer (Install-Prothesa.ps1 / Seed-Sample.ps1) sebagai file .installed.
# Tidak berlaku untuk run .ps1 biasa; untuk dev/testing: $env:PROTHESA_ALLOW_PORTABLE='1'.
if ($env:PROTHESA_ALLOW_PORTABLE -ne '1') {
    $eaLoc = ''
    try { $eaLoc = [System.Reflection.Assembly]::GetEntryAssembly().Location } catch { $eaLoc = '' }
    $eaName = ''
    if ($eaLoc) { try { $eaName = [System.IO.Path]::GetFileNameWithoutExtension($eaLoc) } catch { } }
    $isCompiledExe = ($eaLoc -match '\.exe$') -and ($eaName -notmatch '^(powershell|pwsh)$')
    $hasMarker = (Test-Path -LiteralPath (Join-Path $ScriptRoot 'installed.json')) -or
                 (Test-Path -LiteralPath (Join-Path $ScriptRoot '.installed'))
    if ($isCompiledExe -and -not $hasMarker) {
        [void][System.Windows.Forms.MessageBox]::Show(
            'Prothesa Util belum diinstall di PC ini.' + "`r`n`r`n" + 'Jalankan Setup (ProthesaUtil-Setup) atau Install-Prothesa.ps1 terlebih dahulu, jangan double-click EXE langsung.',
            'Prothesa Util',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        exit 1
    }
}

function Col { param([string]$hex) [System.Drawing.ColorTranslator]::FromHtml($hex) }

# Sleek Obsidian / Slate Dark Theme Palette
$c_bg            = Col('#0B0F17')
$c_bg2           = Col('#111827')
$c_bg3           = Col('#1E293B')
$c_card          = Col('#151D2A')
$c_cardHover     = Col('#1A2434')
$c_line          = Col('#243042')
$c_lineDark      = Col('#1B2433')
$c_text          = Col('#F8FAFC')
$c_dim           = Col('#94A3B8')
$c_muted         = Col('#64748B')

# Semantic Accent Colors
$c_blue          = Col('#38BDF8')
$c_blueDark      = Col('#0284C7')
$c_purple        = Col('#A78BFA')
$c_teal          = Col('#2DD4BF')
$c_green         = Col('#34D399')
$c_greenDark     = Col('#059669')
$c_red           = Col('#F87171')
$c_redDark       = Col('#DC2626')
$c_orange        = Col('#FB923C')
$c_cyan          = Col('#38BDF8')
$c_pink          = Col('#F472B6')
$c_amber         = Col('#FBBF24')
$c_gray          = Col('#64748B')

$colorMap = @{
    'Black' = '#0E0F12'; 'White' = '#F8FAFC'; 'Gray' = '#94A3B8'; 'DarkGray' = '#64748B'
    'Blue' = '#38BDF8'; 'DarkBlue' = '#0284C7'; 'Cyan' = '#22D3EE'; 'DarkCyan' = '#0891B2'
    'Green' = '#34D399'; 'DarkGreen' = '#059669'; 'Yellow' = '#FDE047'; 'DarkYellow' = '#D97706'
    'Red' = '#F87171'; 'DarkRed' = '#DC2626'; 'Magenta' = '#F472B6'; 'DarkMagenta' = '#DB2777'
    'Purple' = '#A78BFA'; 'Orange' = '#FB923C'; 'Pink' = '#F472B6'; 'Teal' = '#2DD4BF'
}

function Lighten { param([System.Drawing.Color]$Col, [int]$Amt = 18) [System.Drawing.Color]::FromArgb([Math]::Min(255, $Col.R + $Amt), [Math]::Min(255, $Col.G + $Amt), [Math]::Min(255, $Col.B + $Amt)) }

function Fui { param([single]$Size, [bool]$Bold = $false) New-Object System.Drawing.Font('Segoe UI', $Size, $(if ($Bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }), [System.Drawing.GraphicsUnit]::Point) }
function Femo { param([single]$Size, [bool]$Bold = $false) New-Object System.Drawing.Font('Segoe UI Emoji', $Size, $(if ($Bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }), [System.Drawing.GraphicsUnit]::Point) }


function New-Lbl {
    param([string]$Text, [single]$Size = 10.5, [System.Drawing.Color]$Color = $c_text, [bool]$Bold = $false)
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text
    $l.Font = $(if ($Bold) { Fui $Size $true } else { Fui $Size })
    $l.ForeColor = $Color
    $l.BackColor = [System.Drawing.Color]::Transparent
    $l.AutoSize = $true
    $l.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 4)
    return $l
}

$Script:AllButtons = New-Object System.Collections.ArrayList

function New-Btn {
    param([string]$Text, [System.Drawing.Color]$Bg, [int]$W = 200, [int]$H = 40)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Font = Fui 10 $true
    $b.BackColor = $Bg
    $b.ForeColor = [System.Drawing.Color]::White
    $b.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $b.FlatAppearance.BorderSize = 0
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    $b.Width = $W
    $b.Height = $H
    $b.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $b.UseCompatibleTextRendering = $false
    $b.UseVisualStyleBackColor = $false
    $b.Margin = New-Object System.Windows.Forms.Padding(0, 6, 0, 4)
    $b.Tag = $Bg
    $b.Add_MouseEnter({ $this.BackColor = Lighten ([System.Drawing.Color]$this.Tag) 18 })
    $b.Add_MouseLeave({ $this.BackColor = [System.Drawing.Color]$this.Tag })
    [void]$Script:AllButtons.Add($b)
    return $b
}

function New-Box {
    param([string]$Placeholder = '', [int]$W = 340, [int]$H = 34, [single]$Size = 10)
    $t = New-Object System.Windows.Forms.TextBox
    $t.Width = $W
    $t.Height = $H
    $t.Font = Fui $Size
    $t.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $t.BackColor = Col('#0F1522')
    $t.ForeColor = $c_text
    $t.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 4)
    $t.Tag = $Placeholder
    if ($Placeholder) {
        $t.Text = $Placeholder
        $t.ForeColor = $c_muted
    }
    $t.Add_GotFocus({
        if ($this.Text -eq [string]$this.Tag) { $this.Text = ''; $this.ForeColor = $c_text }
    })
    $t.Add_LostFocus({
        if ([string]::IsNullOrWhiteSpace($this.Text)) { $this.Text = [string]$this.Tag; $this.ForeColor = $c_muted }
    })
    return $t
}

function Get-Box {
    param($Box)
    $v = $Box.Text.Trim()
    if ($v -eq [string]$Box.Tag) { return '' }
    return $v
}

function New-YearBox {
    $n = New-Object System.Windows.Forms.NumericUpDown
    $n.Minimum = 2024
    $n.Maximum = 2040
    $n.Value = (Get-Date).Year
    $n.Width = 110
    $n.Height = 34
    $n.BackColor = Col('#0F1522')
    $n.ForeColor = $c_text
    $n.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $n.Font = Fui 10.5 $true
    $n.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 4)
    return $n
}

function New-Drop {
    param($Items, [int]$W = 220)
    $d = New-Object System.Windows.Forms.ComboBox
    $d.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $d.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $d.BackColor = Col('#0F1522')
    $d.ForeColor = $c_text
    $d.Height = 34
    $d.Width = $W
    $d.Font = Fui 10
    $d.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 4)
    $d.Items.AddRange($Items)
    if ($Items.Count -gt 0) { $d.SelectedIndex = 0 }
    return $d
}

function New-Chk {
    param([string]$Text, [bool]$Checked = $false)
    $chk = New-Object System.Windows.Forms.CheckBox
    $chk.Text = $Text
    $chk.Checked = $Checked
    $chk.ForeColor = $c_text
    $chk.BackColor = [System.Drawing.Color]::Transparent
    $chk.Font = Fui 10
    $chk.AutoSize = $true
    $chk.Margin = New-Object System.Windows.Forms.Padding(0, 6, 0, 4)
    return $chk
}

function New-Sep {
    $p = New-Object System.Windows.Forms.Panel
    $p.Height = 1
    $p.Width = 936
    $p.BackColor = $c_line
    $p.Margin = New-Object System.Windows.Forms.Padding(20, 10, 0, 10)
    return $p
}

function New-Card {
    param([string]$Title, [System.Drawing.Color]$Accent, [int]$W = 980, [string]$Sub = '')
    $f = New-Object System.Windows.Forms.FlowLayoutPanel
    $f.Width = $W
    $f.Height = 200
    $f.BackColor = $c_card
    $f.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $f.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $f.WrapContents = $false
    $f.AutoScroll = $false
    $f.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 18)
    $f.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 10)

    # Sleek 2px colored top accent line
    $strip = New-Object System.Windows.Forms.Panel
    $strip.Height = 2
    $strip.Width = $W
    $strip.BackColor = $Accent
    $strip.Margin = New-Object System.Windows.Forms.Padding(0)
    [void]$f.Controls.Add($strip)

    # Header section
    $hdr = New-Object System.Windows.Forms.Panel
    $hdr.Width = $W - 4
    $hdr.Height = if ($Sub) { 52 } else { 40 }
    $hdr.BackColor = [System.Drawing.Color]::Transparent
    $hdr.Margin = New-Object System.Windows.Forms.Padding(0)

    $head = New-Lbl $Title 13 $c_text $true
    $head.Location = New-Object System.Drawing.Point(22, 10)
    [void]$hdr.Controls.Add($head)

    if ($Sub) {
        $s = New-Lbl $Sub 9 $c_dim
        $s.Location = New-Object System.Drawing.Point(22, 31)
        [void]$hdr.Controls.Add($s)
    }
    [void]$f.Controls.Add($hdr)
    return $f
}

function Card-Width {
    param($Card)
    $Card.Width = 980
}

function Fit-Card {
    param($Card)
    $m = 0
    foreach ($ct in $Card.Controls) {
        $b = $ct.Top + $ct.Height
        if ($b -gt $m) { $m = $b }
    }
    $Card.Height = $m + 16
}

function Add-CardRow {
    param($Flow, [string]$Label, $Control, [int]$LabelW = 180)
    $wrap = New-Object System.Windows.Forms.Panel
    $wrap.Width = $Flow.Width - 44
    $wrap.Height = 42
    $wrap.BackColor = [System.Drawing.Color]::Transparent
    $wrap.Margin = New-Object System.Windows.Forms.Padding(22, 3, 0, 4)
    if ($Label) {
        $lbl = New-Lbl $Label 10 $c_text $true
        $lbl.Margin = New-Object System.Windows.Forms.Padding(0)
        $lbl.Location = New-Object System.Drawing.Point(0, 9)
        [void]$wrap.Controls.Add($lbl)
        $Control.Location = New-Object System.Drawing.Point($LabelW, 2)
    }
    else {
        $Control.Location = New-Object System.Drawing.Point(0, 2)
    }
    [void]$wrap.Controls.Add($Control)
    [void]$Flow.Controls.Add($wrap)
}

function Add-Note {
    param($Flow, [string]$Text, [System.Drawing.Color]$Color = $c_dim)
    $l = New-Lbl $Text 9.5 $Color
    $l.Margin = New-Object System.Windows.Forms.Padding(20, 2, 0, 8)
    [void]$Flow.Controls.Add($l)
}

function Add-ButtonRow {
    param($Flow, [object[]]$Buttons, [int]$BtnW = 180, [int]$BtnH = 42)
    $wrap = New-Object System.Windows.Forms.Panel
    $wrap.Width = $Flow.Width - 44
    $wrap.Height = $BtnH + 12
    $wrap.BackColor = [System.Drawing.Color]::Transparent
    $wrap.Margin = New-Object System.Windows.Forms.Padding(20, 6, 0, 8)
    $x = 0
    foreach ($b in $Buttons) {
        $b.Width = $BtnW
        $b.Height = $BtnH
        $b.Location = New-Object System.Drawing.Point($x, 4)
        [void]$wrap.Controls.Add($b)
        $x += $BtnW + 16
    }
    [void]$Flow.Controls.Add($wrap)
}

function Set-Busy {
    param([bool]$Busy)
    $Script:Busy = $Busy
    $cursor = $(if ($Busy) { [System.Windows.Forms.Cursors]::WaitCursor } else { [System.Windows.Forms.Cursors]::Default })
    foreach ($b in $Script:AllButtons) {
        $b.Enabled = -not $Busy
        $b.Cursor = $cursor
    }
    if ($Script:StatusBadge) {
        $Script:StatusBadge.Text = if ($Busy) { 'MEMPROSES' } else { 'SIAP' }
        $Script:StatusBadge.ForeColor = if ($Busy) { $c_amber } else { $c_green }
        $Script:StatusBadge.BackColor = if ($Busy) { Col('#451A03') } else { Col('#064E3B') }
    }
}

$Script:GuiInput = New-Object System.Collections.ArrayList
function Push-Input { param([string]$V) [void]$Script:GuiInput.Add($V) }
function Clear-Input { $Script:GuiInput.Clear() }

function Add-Log {
    param([string]$Text, [object]$Color = 'White')
    if (-not $Script:ConsoleBox) { return }
    $colorName = 'White'
    try { if ($null -ne $Color -and "$Color".Trim() -ne '') { $colorName = "$Color".Trim() } } catch { $colorName = 'White' }
    $hex = $colorMap[$colorName]
    if (-not $hex) {
        # Coba konversi enum ConsoleColor -> nama string (mis. DarkGray)
        try { $hex = $colorMap[([string]$colorName)] } catch { }
    }
    if (-not $hex) { $hex = $colorMap['White'] }
    $timeStr = Get-Date -Format 'HH:mm:ss'
    try {
        $rgb = [System.Drawing.ColorTranslator]::FromHtml($hex)
        $Script:ConsoleBox.SelectionStart = $Script:ConsoleBox.TextLength
        $Script:ConsoleBox.SelectionLength = 0
        $Script:ConsoleBox.SelectionColor = $rgb
        $Script:ConsoleBox.AppendText(('[{0}] {1}' -f $timeStr, $Text) + "`r`n")
        $Script:ConsoleBox.SelectionStart = $Script:ConsoleBox.TextLength
        $Script:ConsoleBox.ScrollToCaret()
        if ($Script:ConsoleTicker) {
            $cleanMsg = $Text -replace '^[─\s\-]+|[─\s\-]+$', ''
            if ($cleanMsg.Length -gt 75) { $cleanMsg = $cleanMsg.Substring(0, 72) + '...' }
            $Script:ConsoleTicker.Text = "[$timeStr] $cleanMsg"
        }
        [System.Windows.Forms.Application]::DoEvents()
    }
    catch { }
}

function Write-ColorText {
    param([string]$Text, [object]$Color = 'White')
    if ($Text.Trim() -ne '') { Add-Log $Text $Color }
}

function Write-Host {
    param(
        [Parameter(Position = 0, ValueFromRemainingArguments = $true)][object[]]$Object,
        [object]$ForegroundColor = [System.ConsoleColor]::DarkGray,
        [object]$BackgroundColor = [System.ConsoleColor]::Black,
        [string]$Separator = ' ',
        [switch]$NoNewline
    )
    $t = ''
    if ($Object) { $t = ($Object | ForEach-Object { [string]$_ }) -join $Separator }
    if ($t.Trim() -ne '') { Add-Log $t $ForegroundColor }
}

function Read-Host {
    param([string]$Prompt = '', [string]$AsSecureString)
    if ($Script:GuiInput.Count -gt 0) {
        $v = $Script:GuiInput[0]
        $Script:GuiInput.RemoveAt(0)
        return $v
    }
    if ($Prompt -match 'y/n') { return 'n' }
    return ''
}

function Test-ArchivePath {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    (Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue | Where-Object Name -Match '=PROTHESA \d{4}$').Count -gt 0
}

function Get-DefaultRoot {
    if (Test-ArchivePath $ScriptRoot) { return $ScriptRoot }
    $parent = Split-Path -Parent $ScriptRoot
    if (Test-ArchivePath $parent) { return $parent }
    return $ScriptRoot
}

function Test-ProthesaInstalled {
    <#
    .SYNOPSIS
    True bila app terpasang resmi via installer (entri HKCU atau marker installed.json).
    Dipakai penegakan wajib-install pada host EXE.
    #>
    try {
        if (Test-Path -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ProthesaUtil') { return $true }
        if (Test-Path -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ProthesaUtil_is1') { return $true }
        if (Test-Path -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{3F2A1B4C-9D8E-4F7A-8C6B-1A2B3C4D5E6F}_is1') { return $true }
    } catch { }
    try {
        $approot = if (Get-Command Get-AppScriptRoot -ErrorAction SilentlyContinue) { Get-AppScriptRoot } else { $ScriptRoot }
        if ($approot -and (Test-Path -LiteralPath (Join-Path $approot 'installed.json'))) { return $true }
    } catch { }
    return $false
}

$Script:ConfigPath = Join-Path $ScriptRoot 'ProthesaConfig.json'
$cfg = $null
if (Test-Path -LiteralPath $Script:ConfigPath) {
    try { $cfg = Get-Content -Raw -LiteralPath $Script:ConfigPath | ConvertFrom-Json } catch { }
}
$Script:BasePath = $(if ($cfg -and $cfg.base_path -and (Test-Path -LiteralPath $cfg.base_path)) { [string]$cfg.base_path } else { Get-DefaultRoot })
$Script:AutoUpdateAfterCopy = $(if ($cfg -and $cfg.auto_update_after_copy) { $true } else { $false })

function Save-Config {
    try {
        @{ base_path = $Script:BasePath; auto_update_after_copy = [bool]$Script:AutoUpdateAfterCopy } | ConvertTo-Json | Set-Content -LiteralPath $Script:ConfigPath -Encoding UTF8
    }
    catch { }
}

$env:PROTHESA_SKIP_MENU = '1'
$managerPath = Join-Path $ScriptRoot 'ProthesaManager.ps1'
if (-not (Test-Path -LiteralPath $managerPath)) { throw "ProthesaManager.ps1 tidak ditemukan di: $ScriptRoot" }
. $managerPath
Remove-Item Env:PROTHESA_SKIP_MENU -ErrorAction SilentlyContinue

# Vault opsional (sidecar untuk run .ps1; di EXE merged sudah inline).
try {
    $vaultPath = Join-Path $ScriptRoot 'ProthesaDataVault.ps1'
    if (Test-Path -LiteralPath $vaultPath) { . $vaultPath }
} catch { }

# GUI-safe overrides (Manager menimpa Write-ColorText di atas, kembalikan ke versi Add-Log langsung
# agar warna non-ConsoleColor seperti Purple/Orange tetap aman + hindari binding Write-Host kustom)
function Write-ColorText {
    param([string]$Text, [object]$Color = 'White')
    if ($Text.Trim() -ne '') { Add-Log $Text $Color }
}

function Write-Host {
    param(
        [Parameter(Position = 0, ValueFromRemainingArguments = $true)][object[]]$Object,
        [object]$ForegroundColor = [System.ConsoleColor]::DarkGray,
        [object]$BackgroundColor = [System.ConsoleColor]::Black,
        [string]$Separator = ' ',
        [switch]$NoNewline
    )
    $t = ''
    if ($Object) { $t = ($Object | ForEach-Object { [string]$_ }) -join $Separator }
    if ($t.Trim() -ne '') { Add-Log $t $ForegroundColor }
}

$Script:MonthItems = 1..12 | ForEach-Object { '{0:00} - {1}' -f $_, $Script:BulanNamesLower[$_] }

function Show-FirstRunWizard {
    <#
    .SYNOPSIS
    Wizard setup awal GUI untuk fresh clone GitHub (arsip kosong).
    No-op jika folder tahun sudah ada.
    #>
    try {
        if (-not (Test-ArchiveEmpty)) { return }
    } catch { return }
    if ($env:PROTHESA_SMOKE -eq '1') { Add-Log 'Smoke: wizard setup dilewati.' 'DarkGray'; return }
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = 'Prothesa Util — Setup Awal'
    $dlg.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
    $dlg.ClientSize = New-Object System.Drawing.Size(520, 330)
    $dlg.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false
    $dlg.BackColor = $c_bg2
    $dlg.Font = Fui 10
    $title = New-Lbl 'Selamat datang — arsip belum ditemukan' 12 $c_text $true
    $title.Location = New-Object System.Drawing.Point(20, 14)
    [void]$dlg.Controls.Add($title)
    $info = New-Lbl 'Repo publik fresh-clone tidak menyertakan data (A=/B=/C=, prothesa-status.json, template asli). Pilih folder arsip atau buat contoh.' 9 $c_dim
    $info.Location = New-Object System.Drawing.Point(20, 44)
    $info.Width = 480
    $info.Height = 40
    [void]$dlg.Controls.Add($info)
    $lblPath = New-Lbl 'Folder arsip:' 9.5 $c_text $true
    $lblPath.Location = New-Object System.Drawing.Point(20, 92)
    [void]$dlg.Controls.Add($lblPath)
    $box = New-Object System.Windows.Forms.TextBox
    $box.Text = $Script:BasePath
    $box.ReadOnly = $true
    $box.BackColor = Col('#0F1522')
    $box.ForeColor = $c_text
    $box.Width = 360
    $box.Location = New-Object System.Drawing.Point(20, 114)
    [void]$dlg.Controls.Add($box)
    $btnBrowse = New-Btn 'Pilih...' $c_blueDark 120 30
    $btnBrowse.Location = New-Object System.Drawing.Point(388, 112)
    $btnBrowse.Add_Click({
        $f = New-Object System.Windows.Forms.FolderBrowserDialog
        $f.Description = 'Pilih folder arsip (atau folder kerja baru)'
        $f.SelectedPath = $Script:BasePath
        if ($f.ShowDialog() -eq 'OK') { $box.Text = $f.SelectedPath }
    })
    [void]$dlg.Controls.Add($btnBrowse)
    $note = New-Lbl 'Template asli via repo privat, lihat _TEMPLATES/README.md' 8.5 $c_muted
    $note.Location = New-Object System.Drawing.Point(20, 152)
    $note.Width = 480
    [void]$dlg.Controls.Add($note)
    $btnUse = New-Btn 'Gunakan Folder Ini' $c_greenDark 220 38
    $btnUse.Location = New-Object System.Drawing.Point(20, 190)
    $btnUse.Add_Click({
        $Script:BasePath = $box.Text
        if ($Script:BoxPath) { $Script:BoxPath.Text = $Script:BasePath }
        Save-Config
        $dlg.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $dlg.Close()
    })
    [void]$dlg.Controls.Add($btnUse)
    $btnDemo = New-Btn 'Buat Bulan Berjalan' $c_blueDark 220 38
    $btnDemo.Location = New-Object System.Drawing.Point(268, 190)
    $btnDemo.Add_Click({
        $Script:BasePath = $box.Text
        if ($Script:BoxPath) { $Script:BoxPath.Text = $Script:BasePath }
        Save-Config
        try {
            $now = Get-Date
            New-MonthFolder -Year $now.Year -Month $now.Month -Force -NoPromptCopy | Out-Null
            Add-Log ('Contoh bulan awal dibuat: {0} {1}.' -f $Script:BulanNamesLower[$now.Month], $now.Year) 'Green'
        } catch { Add-Log "Gagal buat contoh: $($_.Exception.Message)" 'Red' }
        $dlg.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $dlg.Close()
    })
    [void]$dlg.Controls.Add($btnDemo)
    $sampleInfo = $null
    try {
        if (Get-Command Find-ProthesaBundle -ErrorAction SilentlyContinue) { $sampleInfo = Find-ProthesaBundle }
    } catch { $sampleInfo = $null }
    if ($sampleInfo) {
        $btnSample = New-Btn ('Pasang Data Contoh (' + $sampleInfo.Name + ')') $c_teal 460 34
        $btnSample.Location = New-Object System.Drawing.Point(20, 244)
        $btnSample.Add_Click({
            try {
                $Script:BasePath = $box.Text
                if ($Script:BoxPath) { $Script:BoxPath.Text = $Script:BasePath }
                Save-Config
                $r = Install-ProthesaSample -BundleFile $sampleInfo.FullName -BasePath $Script:BasePath
                Add-Log ('Data contoh dipasang: {0} ({1} file).' -f $r.Path, $r.Files) 'Green'
            } catch { Add-Log "Gagal pasang sampel: $($_.Exception.Message)" 'Red' }
            $dlg.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $dlg.Close()
        })
        [void]$dlg.Controls.Add($btnSample)
    }
    $btnSkip = New-Btn 'Lewati (Mode Kosong)' $c_gray 460 34
    $btnSkip.Location = New-Object System.Drawing.Point(20, $(if ($sampleInfo) { 286 } else { 244 }))
    $btnSkip.Add_Click({ $dlg.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $dlg.Close() })
    [void]$dlg.Controls.Add($btnSkip)
    [void]$dlg.ShowDialog($Script:Form)
    try { Refresh-Stats } catch { }
}

function Get-YM {
    param($YearBox, $MonthCombo)
    if (-not $YearBox -or -not $MonthCombo) { return $null }
    $y = [int]$YearBox.Value
    $m = $MonthCombo.SelectedIndex + 1
    if ($m -lt 1 -or $m -gt 12) { Add-Log 'Bulan tidak valid.' 'Red'; return $null }
    return @($y, $m)
}

function Open-Folder {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        $null = Start-Process explorer.exe -ArgumentList $Path
    }
    else {
        Add-Log "Folder tidak ditemukan: $Path" 'Red'
    }
}

function Invoke-ExportStatus {
    if ($Script:Busy) { return }
    Set-Busy $true
    Add-Log 'Scan seluruh arsip dengan Single-Source Validation...' 'Yellow'
    try {
        Export-StatusJson | Out-Null
        $src = Join-Path $Script:BasePath 'prothesa-status.json'
        if (Test-Path -LiteralPath $src) {
            $dst = Join-Path $ScriptRoot 'prothesa-status.json'
            Copy-Item -LiteralPath $src -Destination $dst -Force -ErrorAction SilentlyContinue
        }
        Add-Log 'Validasi & status arsip berhasil diperbarui.' 'Green'
    }
    catch { Add-Log "Gagal scan arsip: $($_.Exception.Message)" 'Red' }
    finally {
        Set-Busy $false
        Refresh-Stats
    }
}

$Script:Overview = @()
$Script:YearTotal = 0
$Script:MonthTotal = 0
$Script:PatientTotal = 0
$Script:FullTotal = 0

function Refresh-Stats {
    $years = @()
    $monthTotal = 0
    $patientTotal = 0
    $fullTotal = 0

    $yearFolders = Get-ChildItem -LiteralPath $Script:BasePath -Directory -ErrorAction SilentlyContinue | Where-Object Name -Match '=PROTHESA \d{4}$' | Sort-Object Name
    foreach ($yf in $yearFolders) {
        $yearData = [pscustomobject]@{ Name = $yf.Name; Full = $yf.FullName; Months = @() }
        $mfList = Get-ChildItem -LiteralPath $yf.FullName -Directory -ErrorAction SilentlyContinue | Where-Object Name -Match '^\d+=PROTHESA' | Sort-Object { [int]($_.Name -replace '=.*', '') }
        foreach ($mf in $mfList) {
            $monthTotal++
            $val = Test-ProthesaMonthValidation -MonthPath $mf.FullName
            
            $patientCount = if ($val) { $val.Patients.Count } else { 0 }
            $patientTotal += $patientCount
            $isComplete = ($val -and $val.StatusCode -eq 'complete')
            if ($isComplete) { $fullTotal++ }
            
            $mo = [pscustomobject]@{
                Name = $mf.Name
                Full = $mf.FullName
                Admin = if ($val) { $val.Admin.ValidCount } else { 0 }
                Berkas = if ($val) { $val.BerkasUmum.ValidCount } else { 0 }
                Pasien = $patientCount
                Zip = if ($val) { [bool]$val.Zip.Exists } else { $false }
                Complete = $isComplete
                StatusText = if ($val) { $val.StatusText } else { 'Kosong' }
                StatusCode = if ($val) { $val.StatusCode } else { 'empty' }
                Validation = $val
            }
            $yearData.Months += $mo
        }
        $years += $yearData
    }

    $Script:Overview = $years
    $Script:YearTotal = $years.Count
    $Script:MonthTotal = $monthTotal
    $Script:PatientTotal = $patientTotal
    $Script:FullTotal = $fullTotal

    if ($Script:LblYears) { $Script:LblYears.Text = "$Script:YearTotal" }
    if ($Script:LblMonths) { $Script:LblMonths.Text = "$Script:MonthTotal" }
    if ($Script:LblPatients) { $Script:LblPatients.Text = "$Script:PatientTotal" }
    if ($Script:LblFull) { $Script:LblFull.Text = "$Script:FullTotal" }
    if ($Script:LblPath) { $Script:LblPath.Text = $Script:BasePath }
}

function Show-Ringkasan {
    if ($Script:Busy) { return }
    Add-Log '────── Ringkasan Cepat Arsip (Single-Source Validation) ──────' 'Cyan'
    Refresh-Stats
    foreach ($yd in $Script:Overview) {
        Add-Log $yd.Name 'Cyan'
        foreach ($mo in $yd.Months) {
            $mc = switch ($mo.StatusCode) {
                'complete'     { 'Green' }
                'ready_to_zip' { 'Cyan' }
                'in_progress'  { 'Yellow' }
                default        { 'DarkGray' }
            }
            Add-Log ('   {0,-36}  Status:{1,-13} Admin:{2}/5 Berkas:{3}/9 Pasien:{4}{5}' -f $mo.Name, $mo.StatusText, $mo.Admin, $mo.Berkas, $mo.Pasien, $(if ($mo.Zip) { '   [ZIP]' } else { '' })) $mc
        }
    }
    Add-Log ('Total: {0} tahun, {1} bulan, {2} pasien, {3} bulan lengkap' -f $Script:YearTotal, $Script:MonthTotal, $Script:PatientTotal, $Script:FullTotal) 'White'
}

function Refresh-Tree {
    if (-not $Script:Tree) { return }
    Refresh-Stats
    $Script:Tree.BeginUpdate()
    $Script:Tree.Nodes.Clear()
    $root = New-Object System.Windows.Forms.TreeNode('ARSIP PROTHESA')
    $root.ForeColor = $c_amber
    $root.NodeFont = Fui 10.5 $true
    foreach ($yd in $Script:Overview) {
        $tn = New-Object System.Windows.Forms.TreeNode($yd.Name)
        $tn.Tag = $yd.Full
        $tn.ForeColor = $c_cyan
        foreach ($mo in $yd.Months) {
            $icon = if ($mo.Zip) { ' [ZIP]' } else { '' }
            $label = '{0}{1}   |  {2}  (Admin {3}/5, Berkas {4}/9, Pasien {5})' -f $mo.Name, $icon, $mo.StatusText, $mo.Admin, $mo.Berkas, $mo.Pasien
            $mn = New-Object System.Windows.Forms.TreeNode($label)
            $mn.Tag = $mo.Full
            if ($mo.StatusCode -eq 'complete') { $mn.ForeColor = $c_green }
            elseif ($mo.StatusCode -eq 'ready_to_zip') { $mn.ForeColor = $c_teal }
            elseif ($mo.StatusCode -eq 'in_progress') { $mn.ForeColor = $c_orange }
            else { $mn.ForeColor = $c_dim }
            [void]$tn.Nodes.Add($mn)
        }
        [void]$root.Nodes.Add($tn)
        if ($yd -eq $Script:Overview[-1]) { $tn.Expand() }
    }
    [void]$Script:Tree.Nodes.Add($root)
    $root.Expand()
    $Script:Tree.EndUpdate()
}

function Get-UpdateFields {
    $tgl = Get-Box $Script:BoxTanggal
    $fpk = Get-Box $Script:BoxFpk
    $k = Get-Box $Script:BoxKasus
    $b = Get-Box $Script:BoxBiaya
    $kasus = 0; $biaya = 0
    if ($k -match '^\d+$') { $kasus = [int]$k }
    if ($b -match '^\d+$') { $biaya = [decimal]$b }
    if ($kasus -lt 1 -or $biaya -lt 1) {
        Add-Log 'Untuk isi/auto-fill dokumen: Jumlah Kasus & Biaya harus angka lebih dari 0 (tab "Isi Dokumen").' 'Yellow'
        return $null
    }
    return @{ tanggal = $tgl; fpk = $fpk; kasus = $kasus; biaya = $biaya }
}

function Invoke-UpdateCore {
    param(
        [Parameter(Mandatory)][int]$Year,
        [Parameter(Mandatory)][int]$Month,
        [Parameter(Mandatory)][hashtable]$Fields
    )
    $monthPath = Get-MonthPath -Year $Year -Month $Month
    if (-not $monthPath) {
        Add-Log 'Folder bulan tidak ditemukan.' 'Red'
        return
    }
    $bulan = $Script:BulanNames[$Month]
    $bulanLower = $Script:BulanNamesLower[$Month]

    $prevMonth = $Month - 1
    $prevYear = $Year
    if ($prevMonth -lt 1) { $prevMonth = 12; $prevYear = $Year - 1 }
    $actualPrev = Get-MonthPath -Year $prevYear -Month $prevMonth
    if (-not $actualPrev) {
        for ($i = 1; $i -le 12; $i++) {
            $m = $Month - $i
            $y = $Year
            while ($m -lt 1) { $m += 12; $y -= 1 }
            if (Get-MonthPath -Year $y -Month $m) {
                $prevMonth = $m
                $prevYear = $y
                break
            }
        }
    }
    $oldBulan = $Script:BulanNames[$prevMonth]
    $oldBulanLower = $Script:BulanNamesLower[$prevMonth]

    $submitMonth = $Month + 1
    $submitYear = $Year
    if ($submitMonth -gt 12) { $submitMonth = 1; $submitYear = $Year + 1 }
    $newRomawi = $Script:RomawiNames[$submitMonth]
    $oldRomawi = $Script:RomawiNames[$Month]

    Add-Log "Memproses Word files..." 'Yellow'
    Update-WordTemplates `
        -MonthPath $monthPath `
        -OldBulan $oldBulan `
        -NewBulan $bulan `
        -OldBulanLower $oldBulanLower `
        -NewBulanLower $bulanLower `
        -OldYear $prevYear `
        -NewYear $Year `
        -TanggalTTD $Fields.tanggal `
        -OldRomawi $oldRomawi `
        -NewRomawi $newRomawi `
        -JumlahKasus $Fields.kasus

    Add-Log "Memproses Excel file..." 'Yellow'
    Update-ExcelTemplate `
        -MonthPath $monthPath `
        -OldBulanLower $oldBulanLower `
        -NewBulanLower $bulanLower `
        -OldYear $prevYear `
        -NewYear $Year `
        -OldRomawi $oldRomawi `
        -NewRomawi $newRomawi `
        -NoFPK $Fields.fpk `
        -JumlahKasus $Fields.kasus `
        -Biaya $Fields.biaya
}

function Invoke-NewMonth {
    if ($Script:Busy) { return }
    $ym = Get-YM $Script:YearBox1 $Script:MonthCombo1
    if (-not $ym) { return }
    $y = $ym[0]; $m = $ym[1]

    $copy = $Script:ChkCopy1.Checked
    $auto = $false
    if ($copy -and $Script:ChkAutoCopy.Checked) {
        $u = Get-UpdateFields
        if ($u) { $auto = $true }
    }

    Set-Busy $true
    Add-Log ('─── Buat Folder Bulan: {0} {1} ───' -f $Script:BulanNamesLower[$m], $y) 'Cyan'
    try {
        $created = New-MonthFolder -Year $y -Month $m -Force -NoPromptCopy
        if ($created -and $copy) {
            Add-Log ('─── Copy Template: {0} {1} ───' -f $Script:BulanNamesLower[$m], $y) 'Purple'
            Copy-TemplatesFromPrevious -Year $y -Month $m -NoPromptAutoFill | Out-Null
            if ($auto -and $u) {
                Invoke-UpdateCore -Year $y -Month $m -Fields $u
            }
        }
        Add-Log 'Buat folder bulan selesai.' 'Green'
    }
    catch { Add-Log "Error: $($_.Exception.Message)" 'Red' }
    finally { Set-Busy $false; Refresh-Stats }
}

function Invoke-CopyTemplate {
    if ($Script:Busy) { return }
    $ym = Get-YM $Script:YearBox2 $Script:MonthCombo2
    if (-not $ym) { return }
    $y = $ym[0]; $m = $ym[1]

    $auto = $false
    if ($Script:ChkAutoCopy2.Checked) {
        $u = Get-UpdateFields
        if ($u) { $auto = $true }
    }

    Set-Busy $true
    Add-Log ('─── Copy Template: {0} {1} ───' -f $Script:BulanNamesLower[$m], $y) 'Purple'
    try {
        Copy-TemplatesFromPrevious -Year $y -Month $m -NoPromptAutoFill | Out-Null
        if ($auto -and $u) {
            Invoke-UpdateCore -Year $y -Month $m -Fields $u
        }
        Add-Log 'Copy template selesai.' 'Green'
    }
    catch { Add-Log "Error: $($_.Exception.Message)" 'Red' }
    finally { Set-Busy $false; Refresh-Stats }
}

function Invoke-Patient {
    if ($Script:Busy) { return }
    $ym = Get-YM $Script:YearBox3 $Script:MonthCombo3
    if (-not $ym) { return }
    $y = $ym[0]; $m = $ym[1]
    $name = (Get-Box $Script:BoxPasien).Trim()
    if (-not $name) { Add-Log 'Nama pasien kosong.' 'Red'; return }
    Set-Busy $true
    Add-Log ('─── Tambah Pasien: {0} ───' -f $name.ToUpper()) 'Green'
    try {
        if (New-PatientFolder -Year $y -Month $m -PatientName $name) {
            Add-Log 'OK.' 'Green'
            if ($Script:BoxPasien) {
                $Script:BoxPasien.Text = [string]$Script:BoxPasien.Tag
                $Script:BoxPasien.ForeColor = $c_gray
            }
        }
    }
    catch { Add-Log "Error: $($_.Exception.Message)" 'Red' }
    finally { Set-Busy $false; Refresh-Stats }
}

function Invoke-PatientBatch {
    if ($Script:Busy) { return }
    $ym = Get-YM $Script:YearBox3 $Script:MonthCombo3
    if (-not $ym) { return }
    $y = $ym[0]; $m = $ym[1]
    $names = @($Script:BoxBatch.Lines | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    if ($names.Count -eq 0) { Add-Log 'Belum ada nama pasien di daftar.' 'Red'; return }
    Set-Busy $true
    Add-Log ('─── Batch Pasien: {0} nama ───' -f $names.Count) 'Green'
    try {
        New-BatchPatients -Year $y -Month $m -Names $names
        Add-Log 'Batch selesai.' 'Green'
        if ($Script:BoxBatch) { $Script:BoxBatch.Clear() }
        if ($Script:LblBatchCount) { $Script:LblBatchCount.Text = '0 pasien terdaftar' }
    }
    catch { Add-Log "Error: $($_.Exception.Message)" 'Red' }
    finally { Set-Busy $false; Refresh-Stats }
}

function Invoke-Update {
    if ($Script:Busy) { return }
    $ym = Get-YM $Script:YearBox4 $Script:MonthCombo4
    if (-not $ym) { return }
    $y = $ym[0]; $m = $ym[1]
    $u = Get-UpdateFields
    if (-not $u) { return }
    Set-Busy $true
    Add-Log ('─── Update Isi Dokumen: {0} {1} ───' -f $Script:BulanNamesLower[$m], $y) 'Orange'
    try {
        Invoke-UpdateCore -Year $y -Month $m -Fields $u
        Add-Log 'Update dokumen selesai.' 'Green'
    }
    catch { Add-Log "Error: $($_.Exception.Message)" 'Red' }
    finally { Set-Busy $false; Refresh-Stats }
}

function Invoke-Zip {
    if ($Script:Busy) { return }
    $ym = Get-YM $Script:YearBox5 $Script:MonthCombo5
    if (-not $ym) { return }
    $y = $ym[0]; $m = $ym[1]
    Set-Busy $true
    Add-Log ('─── ZIP: {0} {1} ───' -f $Script:BulanNamesLower[$m], $y) 'Red'
    try {
        Compress-MonthToZip -Year $y -Month $m -Force
        Add-Log 'ZIP selesai.' 'Green'
    }
    catch { Add-Log "Error: $($_.Exception.Message)" 'Red' }
    finally { Set-Busy $false; Refresh-Stats }
}

function Select-Tab {
    param([string]$Key)
    if (-not $Key) { return }
    if ($Script:activeTab -eq $Key) { return }
    $Script:activeTab = $Key

    if ($Script:AreaPanel) { $Script:AreaPanel.SuspendLayout() }

    foreach ($k in $Script:panels.Keys) {
        $vis = ($k -eq $Key)
        $panel = $Script:panels[$k]
        $panel.Visible = $vis
        if ($vis) {
            $panel.BringToFront()
        }
    }

    if ($Script:AreaPanel) { $Script:AreaPanel.ResumeLayout($true) }

    foreach ($nb in $Script:NavButtons) {
        if ($nb.Key -eq $Key) {
            $nb.Btn.BackColor = $c_bg3
            if ($nb.WrapBox) { $nb.WrapBox.BackColor = $c_bg3 }
            $nb.Btn.ForeColor = [System.Drawing.Color]::White
            $nb.Btn.Font = Fui 10 $true
            $nb.Bar.Visible = $true
            $nb.Bar.BringToFront()
        }
        else {
            $nb.Btn.BackColor = $c_bg2
            if ($nb.WrapBox) { $nb.WrapBox.BackColor = $c_bg2 }
            $nb.Btn.ForeColor = $c_dim
            $nb.Btn.Font = Fui 10 $false
            $nb.Bar.Visible = $false
        }
    }

    $tabDesc = @{
        'Home'    = 'Ringkasan Arsip & Status Data Klaim BPJS Gigi'
        'Month'   = 'Buat Folder Bulan Baru & Struktur Klaim BPJS'
        'Copy'    = 'Salin Template Dokumen Master Mandiri _TEMPLATES'
        'Patient' = 'Pendaftaran Pasien & Batch Generate Folder Pasien'
        'Fill'    = 'Otomasi Pengisian Dokumen Klaim (Word & Excel)'
        'Zip'     = 'Kompresi Berkas Klaim Bulan Menjadi Arsip ZIP'
        'Stats'   = 'Monitoring Arsip, Pohon Status & Validasi Dokumen'
    }
    if ($Script:HeaderSub -and $tabDesc.ContainsKey($Key)) {
        $Script:HeaderSub.Text = $tabDesc[$Key]
    }

    if ($Key -eq 'Home') { Refresh-Stats }
    if ($Key -eq 'Stats') { Refresh-Tree }
}

function Build-Main {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Prothesa Util - drg. Danny Hanggono'
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.ClientSize = New-Object System.Drawing.Size(1280, 850)
    $form.MinimumSize = New-Object System.Drawing.Size(1120, 680)
    $form.BackColor = $c_bg
    $form.Font = Fui 10
    $form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Font
    $Script:Form = $form

    # ==================== TOP HEADER ====================
    $header = New-Object System.Windows.Forms.Panel
    $header.Dock = [System.Windows.Forms.DockStyle]::Top
    $header.Height = 64
    $header.BackColor = $c_bg2

    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'PROTHESA UTIL'
    $title.Font = Fui 14 $true
    $title.ForeColor = [System.Drawing.Color]::White
    $title.AutoSize = $true
    $title.Location = New-Object System.Drawing.Point(24, 12)
    [void]$header.Controls.Add($title)

    $statusBadge = New-Object System.Windows.Forms.Label
    $statusBadge.Text = 'SIAP'
    $statusBadge.Font = Fui 8.5 $true
    $statusBadge.ForeColor = $c_green
    $statusBadge.BackColor = Col('#064E3B')
    $statusBadge.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $statusBadge.AutoSize = $true
    $statusBadge.Padding = New-Object System.Windows.Forms.Padding(6, 2, 6, 2)
    $statusBadge.Location = New-Object System.Drawing.Point(175, 14)
    [void]$header.Controls.Add($statusBadge)
    $Script:StatusBadge = $statusBadge

    $sub = New-Object System.Windows.Forms.Label
    $sub.Text = 'Tools Otomasi Arsip Klaim BPJS - drg. Danny Hanggono (Praktek Waru)'
    $sub.Font = Fui 9
    $sub.ForeColor = $c_dim
    $sub.AutoSize = $true
    $sub.Location = New-Object System.Drawing.Point(26, 38)
    [void]$header.Controls.Add($sub)
    $Script:HeaderSub = $sub

    $headerSep = New-Object System.Windows.Forms.Panel
    $headerSep.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $headerSep.Height = 1
    $headerSep.BackColor = $c_line
    [void]$header.Controls.Add($headerSep)

    $right = New-Object System.Windows.Forms.Panel
    $right.Dock = [System.Windows.Forms.DockStyle]::Right
    $right.Width = 280
    $right.BackColor = $c_bg2

    $btnRefresh = New-Btn 'Refresh Data' $c_blueDark 130 36
    $btnRefresh.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
    $btnRefresh.Location = New-Object System.Drawing.Point(30, 14)
    $btnRefresh.Add_Click({ Refresh-Stats; Add-Log 'Refresh data selesai.' 'Cyan' })
    [void]$right.Controls.Add($btnRefresh)

    $btnQuit = New-Btn 'Keluar' $c_redDark 90 36
    $btnQuit.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
    $btnQuit.Location = New-Object System.Drawing.Point(170, 14)
    $btnQuit.Add_Click({ $Script:Form.Close() })
    [void]$right.Controls.Add($btnQuit)

    [void]$header.Controls.Add($right)

    # ==================== LEFT SIDEBAR ====================
    $side = New-Object System.Windows.Forms.Panel
    $side.Dock = [System.Windows.Forms.DockStyle]::Left
    $side.Width = 230
    $side.BackColor = $c_bg2

    $brandPanel = New-Object System.Windows.Forms.Panel
    $brandPanel.Left = 0
    $brandPanel.Top = 0
    $brandPanel.Width = 230
    $brandPanel.Height = 72
    $brandPanel.BackColor = $c_bg2

    $sideBrand = New-Object System.Windows.Forms.Label
    $sideBrand.Text = 'PROTHESA'
    $sideBrand.Font = Fui 13 $true
    $sideBrand.ForeColor = $c_blue
    $sideBrand.Location = New-Object System.Drawing.Point(20, 14)
    $sideBrand.AutoSize = $true
    [void]$brandPanel.Controls.Add($sideBrand)

    $sideSub = New-Object System.Windows.Forms.Label
    $sideSub.Text = 'Klaim BPJS Gigi - drg. Danny'
    $sideSub.Font = Fui 8.5
    $sideSub.ForeColor = $c_dim
    $sideSub.Location = New-Object System.Drawing.Point(21, 38)
    $sideSub.AutoSize = $true
    [void]$brandPanel.Controls.Add($sideSub)

    $sideSep = New-Object System.Windows.Forms.Panel
    $sideSep.Height = 1
    $sideSep.Width = 196
    $sideSep.BackColor = $c_line
    $sideSep.Location = New-Object System.Drawing.Point(17, 65)
    [void]$brandPanel.Controls.Add($sideSep)

    [void]$side.Controls.Add($brandPanel)

    # ==================== BOTTOM CONSOLE ====================
    $consoleWrap = New-Object System.Windows.Forms.Panel
    $consoleWrap.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $consoleWrap.Height = 96
    $consoleWrap.BackColor = Col('#070A0F')
    $Script:ConsoleWrap = $consoleWrap

    $consoleBar = New-Object System.Windows.Forms.Panel
    $consoleBar.Dock = [System.Windows.Forms.DockStyle]::Top
    $consoleBar.Height = 28
    $consoleBar.BackColor = $c_bg2

    $consoleTitle = New-Lbl 'LOG SISTEM' 8.5 $c_dim $true
    $consoleTitle.Location = New-Object System.Drawing.Point(14, 6)
    [void]$consoleBar.Controls.Add($consoleTitle)

    $Script:ConsoleTicker = New-Lbl 'Prothesa Util siap.' 8.5 $c_muted
    $Script:ConsoleTicker.Location = New-Object System.Drawing.Point(110, 6)
    $Script:ConsoleTicker.AutoSize = $true
    [void]$consoleBar.Controls.Add($Script:ConsoleTicker)

    $btnToggleLog = New-Object System.Windows.Forms.Button
    $btnToggleLog.Text = 'Kecilkan'
    $btnToggleLog.Font = Fui 8.5
    $btnToggleLog.ForeColor = $c_dim
    $btnToggleLog.BackColor = [System.Drawing.Color]::Transparent
    $btnToggleLog.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnToggleLog.FlatAppearance.BorderSize = 0
    $btnToggleLog.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnToggleLog.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
    $btnToggleLog.Location = New-Object System.Drawing.Point(1185, 2)
    $btnToggleLog.Width = 75
    $btnToggleLog.Height = 24
    $btnToggleLog.Add_Click({
        if ($Script:ConsoleWrap.Height -gt 35) {
            $Script:ConsoleWrap.Height = 28
            $btnToggleLog.Text = 'Buka Log'
        }
        else {
            $Script:ConsoleWrap.Height = 110
            $btnToggleLog.Text = 'Kecilkan'
        }
    })
    [void]$consoleBar.Controls.Add($btnToggleLog)

    $btnClearLog = New-Object System.Windows.Forms.Button
    $btnClearLog.Text = 'Bersihkan'
    $btnClearLog.Font = Fui 8.5
    $btnClearLog.ForeColor = $c_dim
    $btnClearLog.BackColor = [System.Drawing.Color]::Transparent
    $btnClearLog.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnClearLog.FlatAppearance.BorderSize = 0
    $btnClearLog.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnClearLog.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
    $btnClearLog.Location = New-Object System.Drawing.Point(1100, 2)
    $btnClearLog.Width = 80
    $btnClearLog.Height = 24
    $btnClearLog.Add_Click({ if ($Script:ConsoleBox) { $Script:ConsoleBox.Clear(); Add-Log 'Log dibersihkan.' 'DarkGray' } })
    [void]$consoleBar.Controls.Add($btnClearLog)

    $btnCopyLog = New-Object System.Windows.Forms.Button
    $btnCopyLog.Text = 'Salin'
    $btnCopyLog.Font = Fui 8.5
    $btnCopyLog.ForeColor = $c_dim
    $btnCopyLog.BackColor = [System.Drawing.Color]::Transparent
    $btnCopyLog.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnCopyLog.FlatAppearance.BorderSize = 0
    $btnCopyLog.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnCopyLog.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
    $btnCopyLog.Location = New-Object System.Drawing.Point(1030, 2)
    $btnCopyLog.Width = 65
    $btnCopyLog.Height = 24
    $btnCopyLog.Add_Click({ 
        if ($Script:ConsoleBox -and $Script:ConsoleBox.TextLength -gt 0) {
            [System.Windows.Forms.Clipboard]::SetText($Script:ConsoleBox.Text)
            Add-Log 'Seluruh isi log disalin ke clipboard.' 'Cyan'
        }
    })
    [void]$consoleBar.Controls.Add($btnCopyLog)

    $console = New-Object System.Windows.Forms.RichTextBox
    $console.Dock = [System.Windows.Forms.DockStyle]::Fill
    $console.BackColor = Col('#070A0F')
    $console.ForeColor = Col('#CBD5E1')
    $console.Font = New-Object System.Drawing.Font('Consolas', 9)
    $console.ReadOnly = $true
    $console.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $console.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Both

    [void]$consoleWrap.Controls.Add($console)
    [void]$consoleWrap.Controls.Add($consoleBar)

    # ==================== MAIN CONTENT AREA ====================
    $area = New-Object System.Windows.Forms.Panel
    $area.Dock = [System.Windows.Forms.DockStyle]::Fill
    $area.BackColor = $c_bg
    $Script:AreaPanel = $area

    [void]$form.Controls.Add($area)
    [void]$form.Controls.Add($side)
    [void]$form.Controls.Add($consoleWrap)
    [void]$form.Controls.Add($header)
    $header.BringToFront()
    $consoleWrap.BringToFront()
    $side.BringToFront()
    $area.BringToFront()

    $Script:ConsoleBox = $console
    $Script:panels = @{}
    $Script:NavButtons = @()

    $navOrder = @(
        @{ Key = 'Home';    Label = 'Beranda' }
        @{ Key = 'Month';   Label = 'Buat Bulan' }
        @{ Key = 'Copy';    Label = 'Copy Template' }
        @{ Key = 'Patient'; Label = 'Kelola Pasien' }
        @{ Key = 'Fill';    Label = 'Isi Dokumen' }
        @{ Key = 'Zip';     Label = 'Kompresi ZIP' }
        @{ Key = 'Stats';   Label = 'Monitoring Arsip' }
    )

    $yPos = 80
    foreach ($def in $navOrder) {
        $page = New-Object System.Windows.Forms.Panel
        $page.Dock = [System.Windows.Forms.DockStyle]::Fill
        $page.BackColor = $c_bg
        $page.Visible = $false

        $wrap = New-Object System.Windows.Forms.FlowLayoutPanel
        $wrap.Dock = [System.Windows.Forms.DockStyle]::Fill
        $wrap.AutoScroll = $true
        $wrap.WrapContents = $false
        $wrap.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
        $wrap.Padding = New-Object System.Windows.Forms.Padding(25, 20, 25, 25)
        $page.Controls.Add($wrap)

        # Nav button item container (Pill style)
        $btnWrap = New-Object System.Windows.Forms.Panel
        $btnWrap.Left = 12
        $btnWrap.Top = $yPos
        $btnWrap.Width = 206
        $btnWrap.Height = 42
        $btnWrap.BackColor = $c_bg2

        $bar = New-Object System.Windows.Forms.Panel
        $bar.Width = 3
        $bar.Height = 24
        $bar.Left = 0
        $bar.Top = 9
        $bar.BackColor = $c_blue
        $bar.Visible = $false
        [void]$btnWrap.Controls.Add($bar)

        $btn = New-Object System.Windows.Forms.Button
        $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btn.FlatAppearance.BorderSize = 0
        $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
        $btn.Text = ('   ' + $def.Label)
        $btn.Font = Fui 10 $false
        $btn.ForeColor = $c_dim
        $btn.BackColor = $c_bg2
        $btn.Left = 0
        $btn.Top = 0
        $btn.Width = 206
        $btn.Height = 42
        $btn.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $btn.UseCompatibleTextRendering = $false
        $btn.UseVisualStyleBackColor = $false
        $btn.Tag = $def.Key

        # Robust closure-bound click and hover handlers
        $targetKey = $def.Key
        $btnRef = $btn
        $barRef = $bar
        $wrapRef = $btnWrap

        $btn.Add_Click({ Select-Tab $targetKey }.GetNewClosure())
        $bar.Add_Click({ Select-Tab $targetKey }.GetNewClosure())

        $btn.Add_MouseEnter({
            if ($Script:activeTab -ne $targetKey) {
                $btnRef.BackColor = Col('#1A2434')
                $wrapRef.BackColor = Col('#1A2434')
                $btnRef.ForeColor = [System.Drawing.Color]::White
            }
        }.GetNewClosure())

        $btn.Add_MouseLeave({
            if ($Script:activeTab -ne $targetKey) {
                $btnRef.BackColor = $c_bg2
                $wrapRef.BackColor = $c_bg2
                $btnRef.ForeColor = $c_dim
            }
        }.GetNewClosure())

        [void]$btnWrap.Controls.Add($btn)
        $bar.BringToFront()

        [void]$side.Controls.Add($btnWrap)
        [void]$area.Controls.Add($page)

        $Script:NavButtons += [pscustomobject]@{
            Key = $def.Key
            Btn = $btn
            Bar = $bar
            WrapBox = $btnWrap
            Page = $page
            Wrap = $wrap
        }
        $Script:panels[$def.Key] = $page
        $yPos += 46
    }

    $ver = New-Object System.Windows.Forms.Label
    $ver.Text = 'v2.1 | Ridwan Gatro'
    $ver.Font = Fui 8.5
    $ver.ForeColor = $c_muted
    $ver.AutoSize = $true
    $ver.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Bottom
    $ver.Location = New-Object System.Drawing.Point(20, 680)
    [void]$side.Controls.Add($ver)

    return $form
}

function Add-StatRow {
    param($Flow, $Blocks)
    $wrap = New-Object System.Windows.Forms.Panel
    $wrap.Width = $Flow.Width - 44
    $wrap.Height = 92
    $wrap.BackColor = [System.Drawing.Color]::Transparent
    $wrap.Margin = New-Object System.Windows.Forms.Padding(20, 8, 0, 14)
    $tileW = 222
    $tileH = 84
    $gap = 16
    $x = 0
    foreach ($blk in $Blocks) {
        $p = New-Object System.Windows.Forms.Panel
        $p.Width = $tileW
        $p.Height = $tileH
        $p.BackColor = Col('#0F1522')
        $p.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $p.Left = $x
        $p.Top = 4

        $topBar = New-Object System.Windows.Forms.Panel
        $topBar.Height = 2
        $topBar.Width = $tileW
        $topBar.BackColor = $blk.Color
        $topBar.Dock = [System.Windows.Forms.DockStyle]::Top
        [void]$p.Controls.Add($topBar)

        $num = New-Lbl '0' 20 $blk.Color $true
        $num.Left = 16
        $num.Top = 12
        [void]$p.Controls.Add($num)

        $cap = New-Lbl $blk.Caption 8.5 $c_dim $true
        $cap.Left = 18
        $cap.Top = 54
        [void]$p.Controls.Add($cap)

        if ($blk.Caption -eq 'Tahun')    { $Script:LblYears = $num }
        if ($blk.Caption -eq 'Bulan')    { $Script:LblMonths = $num }
        if ($blk.Caption -eq 'Pasien')   { $Script:LblPatients = $num }
        if ($blk.Caption -eq 'Lengkap')  { $Script:LblFull = $num }

        [void]$wrap.Controls.Add($p)
        $x += $tileW + $gap
    }
    [void]$Flow.Controls.Add($wrap)
    return $wrap
}

function Build-Tabs {
    $pageHome = $Script:panels['Home']
    $wrapH = $Script:NavButtons | Where-Object Key -eq 'Home' | Select-Object -ExpandProperty Wrap

    $c1 = New-Card 'Ringkasan Arsip' $c_blue 980 'Status data klaim seluruh arsip prothesa'
    $statRow = Add-StatRow $c1 @(
        @{ Caption = 'Tahun'; Color = $c_blue }
        @{ Caption = 'Bulan'; Color = $c_teal }
        @{ Caption = 'Pasien'; Color = $c_purple }
        @{ Caption = 'Lengkap'; Color = $c_green }
    )
    Fit-Card $c1
    [void]$wrapH.Controls.Add($c1)

    $c2 = New-Card 'Folder Arsip (Lokasi Data)' $c_green 980 'Semua folder tahunan (A=2024, B=2025, C=2026, dst) berada di lokasi ini'
    $Script:BoxPath = New-Box '' 620 34
    $Script:BoxPath.ReadOnly = $true
    $Script:BoxPath.Text = $Script:BasePath
    $Script:LblPath = $Script:BoxPath
    Add-CardRow $c2 'Lokasi Folder' $Script:BoxPath 140
    $btnOpen = New-Btn 'Buka di Explorer' $c_greenDark 200 38
    $btnOpen.Add_Click({ Open-Folder $Script:BasePath })
    $btnChange = New-Btn 'Ganti Folder' $c_blueDark 180 38
    $btnChange.Add_Click({
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = 'Pilih folder tempat arsip prothesa (berisi A=PROTHESA 2024, dll)'
        $dlg.SelectedPath = $Script:BasePath
        if ($dlg.ShowDialog() -eq 'OK') {
            $Script:BasePath = $dlg.SelectedPath
            $Script:BoxPath.Text = $Script:BasePath
            Save-Config
            Refresh-Stats
            Add-Log "Base path diganti ke: $Script:BasePath" 'Green'
        }
    })
    Add-ButtonRow $c2 @($btnOpen, $btnChange) 200 38
    Add-Note $c2 'Kosong = folder tempat program ini dijalankan / induknya (auto-detect).'
    Fit-Card $c2
    [void]$wrapH.Controls.Add($c2)

    $c3 = New-Card 'Aksi Cepat' $c_blue 980 'Pindai arsip, tampilkan ringkasan, atau buka berkas'
    $btnExport = New-Btn 'Scan Seluruh Arsip' $c_blueDark 458 40
    $btnExport.Add_Click({ Invoke-ExportStatus })
    $btnRing = New-Btn 'Tampilkan Ringkasan Teks' $c_purple 458 40
    $btnRing.Add_Click({ Show-Ringkasan })
    Add-ButtonRow $c3 @($btnExport, $btnRing) 458 40
    $btnOpenRoot = New-Btn 'Buka Folder Arsip' $c_teal 458 40
    $btnOpenRoot.Add_Click({ Open-Folder $Script:BasePath })
    $btnZipTab = New-Btn 'Buka Tab ZIP' $c_amber 458 40
    $btnZipTab.Add_Click({ Select-Tab 'Zip' })
    Add-ButtonRow $c3 @($btnOpenRoot, $btnZipTab) 458 40
    Fit-Card $c3
    [void]$wrapH.Controls.Add($c3)

    $Script:LblPath = $Script:BoxPath

    $wrapM = $Script:NavButtons | Where-Object Key -eq 'Month' | Select-Object -ExpandProperty Wrap
    $cm = New-Card 'Buat Folder Bulan Baru' $c_blue 980 'Struktur folder bulan + subfolder klaim, berkas umum & RJTP'
    $Script:YearBox1 = New-YearBox
    Add-CardRow $cm 'Tahun' $Script:YearBox1
    $Script:MonthCombo1 = New-Drop $Script:MonthItems 220
    $Script:MonthCombo1.SelectedIndex = (Get-Date).Month - 1
    Add-CardRow $cm 'Bulan' $Script:MonthCombo1
    $Script:ChkCopy1 = New-Chk 'Copy template (.doc/.xlsx) dari master mandiri _TEMPLATES/'
    Add-CardRow $cm '' $Script:ChkCopy1 0
    $Script:ChkAutoCopy = New-Chk 'Langsung perbarui data isi Word/Excel setelah copy'
    $Script:ChkAutoCopy.Checked = $Script:AutoUpdateAfterCopy
    $Script:ChkAutoCopy.Add_CheckedChanged({ $Script:AutoUpdateAfterCopy = $Script:ChkAutoCopy.Checked })
    Add-CardRow $cm '' $Script:ChkAutoCopy 0
    $btnBulan = New-Btn 'Buat Folder Bulan Baru' $c_blueDark 280 42
    $btnBulan.Add_Click({ Invoke-NewMonth })
    Add-CardRow $cm '' $btnBulan 0
    Add-Note $cm 'Urutan otomatis: folder tahun -> folder bulan -> KLAIM -> BERKAS UMUM -> RJTP, lalu salin template.'
    Fit-Card $cm
    [void]$wrapM.Controls.Add($cm)

    $wrapC = $Script:NavButtons | Where-Object Key -eq 'Copy' | Select-Object -ExpandProperty Wrap
    $cc = New-Card 'Copy Template Master Mandiri' $c_purple 980 'Menyalin 5 file template (.doc & .xlsx) dari folder _TEMPLATES/'
    $Script:YearBox2 = New-YearBox
    Add-CardRow $cc 'Tahun' $Script:YearBox2
    $Script:MonthCombo2 = New-Drop $Script:MonthItems 220
    $Script:MonthCombo2.SelectedIndex = (Get-Date).Month - 1
    Add-CardRow $cc 'Bulan' $Script:MonthCombo2
    $Script:ChkAutoCopy2 = New-Chk 'Langsung perbarui data isi Word/Excel setelah copy'
    Add-CardRow $cc '' $Script:ChkAutoCopy2 0
    $btnCopy = New-Btn 'Salin 5 File Template' $c_purple 280 42
    $btnCopy.Add_Click({ Invoke-CopyTemplate })
    Add-CardRow $cc '' $btnCopy 0
    Add-Note $cc 'Template diprioritaskan dari folder master mandiri _TEMPLATES/ (bebas tanpa folder arsip tahun lama).'
    Fit-Card $cc
    [void]$wrapC.Controls.Add($cc)

    $wrapP = $Script:NavButtons | Where-Object Key -eq 'Patient' | Select-Object -ExpandProperty Wrap
    $cp1 = New-Card 'Tambah 1 Pasien' $c_green 980 'Buat subfolder nomor + 3 berkas placeholder PDF (BUKTI LAYANAN, FKPP, RESEP)'
    $Script:YearBox3 = New-YearBox
    Add-CardRow $cp1 'Tahun' $Script:YearBox3
    $Script:MonthCombo3 = New-Drop $Script:MonthItems 220
    $Script:MonthCombo3.SelectedIndex = (Get-Date).Month - 1
    Add-CardRow $cp1 'Bulan' $Script:MonthCombo3
    $Script:BoxPasien = New-Box 'Nama pasien (contoh: SITI AMINAH)' 420 34
    Add-CardRow $cp1 'Nama Pasien' $Script:BoxPasien
    $btnP1 = New-Btn 'Tambah Pasien' $c_greenDark 220 40
    $btnP1.Add_Click({ Invoke-Patient })
    Add-CardRow $cp1 '' $btnP1 0
    Fit-Card $cp1
    [void]$wrapP.Controls.Add($cp1)

    $cp2 = New-Card 'Batch Buat Folder Pasien' $c_pink 980 'Satu nama per baris - cepat untuk pendaftaran awal bulan'
    $Script:BoxBatch = New-Object System.Windows.Forms.TextBox
    $Script:BoxBatch.Multiline = $true
    $Script:BoxBatch.Width = 880
    $Script:BoxBatch.Height = 140
    $Script:BoxBatch.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $Script:BoxBatch.Font = Fui 10
    $Script:BoxBatch.BackColor = Col('#0F1522')
    $Script:BoxBatch.ForeColor = $c_text
    $Script:BoxBatch.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $Script:BoxBatch.AcceptsReturn = $true
    $Script:BoxBatch.Margin = New-Object System.Windows.Forms.Padding(0, 5, 0, 5)
    Add-CardRow $cp2 'Daftar Nama' $Script:BoxBatch 120
    $Script:LblBatchCount = New-Lbl '0 pasien terdaftar' 9.5 $c_dim
    $Script:BoxBatch.Add_TextChanged({
        $n = @($Script:BoxBatch.Lines | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }).Count
        $Script:LblBatchCount.Text = "$n pasien terdaftar"
    })
    $btnP2 = New-Btn 'Buat Semua Folder Pasien' $c_pink 280 42
    $btnP2.Add_Click({ Invoke-PatientBatch })
    Add-CardRow $cp2 '' $btnP2 0
    Add-Note $cp2 'Berkas yang dibuat adalah placeholder kosong - ganti dengan scan PDF asli.'
    Fit-Card $cp2
    [void]$wrapP.Controls.Add($cp2)

    $wrapF = $Script:NavButtons | Where-Object Key -eq 'Fill' | Select-Object -ExpandProperty Wrap
    $cf = New-Card 'Perbarui Isi Dokumen Klaim (Word & Excel)' $c_orange 980 'Auto-fill bulan, romawi surat, tanggal TTD, FPK, jumlah kasus & biaya'
    $Script:YearBox4 = New-YearBox
    Add-CardRow $cf 'Tahun' $Script:YearBox4
    $Script:MonthCombo4 = New-Drop $Script:MonthItems 220
    $Script:MonthCombo4.SelectedIndex = (Get-Date).Month - 1
    Add-CardRow $cf 'Bulan' $Script:MonthCombo4
    $Script:BoxTanggal = New-Box 'contoh: 6 Maret 2026' 360 34
    Add-CardRow $cf 'Tanggal TTD' $Script:BoxTanggal
    $Script:BoxFpk = New-Box 'contoh: P2601000026282' 360 34
    Add-CardRow $cf 'No. FPK' $Script:BoxFpk
    $Script:BoxKasus = New-Box 'contoh: 7' 200 34
    Add-CardRow $cf 'Jumlah Kasus' $Script:BoxKasus
    $Script:BoxBiaya = New-Box 'contoh: 5250000 (tanpa titik)' 280 34
    Add-CardRow $cf 'Biaya Total (Rp)' $Script:BoxBiaya
    $btnFill = New-Btn 'Perbarui Semua Dokumen Word & Excel' $c_orange 360 42
    $btnFill.Add_Click({ Invoke-Update })
    Add-CardRow $cf '' $btnFill 0
    Add-Note $cf 'Otomasi COM aman dengan pelepasan memori (FinalReleaseComObject) untuk mencegah proses zombie.'
    Fit-Card $cf
    [void]$wrapF.Controls.Add($cf)

    $wrapZ = $Script:NavButtons | Where-Object Key -eq 'Zip' | Select-Object -ExpandProperty Wrap
    $cz = New-Card 'Kompresi Folder Bulan ke ZIP' $c_red 980 'Mengkompresi seluruh berkas klaim bulan menjadi file .zip siap kirim'
    $Script:YearBox5 = New-YearBox
    Add-CardRow $cz 'Tahun' $Script:YearBox5
    $Script:MonthCombo5 = New-Drop $Script:MonthItems 220
    $Script:MonthCombo5.SelectedIndex = (Get-Date).Month - 1
    Add-CardRow $cz 'Bulan' $Script:MonthCombo5
    $btnZip = New-Btn 'Buat Berkas ZIP' $c_redDark 260 42
    $btnZip.Add_Click({ Invoke-Zip })
    Add-CardRow $cz '' $btnZip 0
    Add-Note $cz 'File ZIP dibuat di folder tahun, di samping folder bulan aslinya.'
    Fit-Card $cz
    [void]$wrapZ.Controls.Add($cz)

    $wrapS = $Script:NavButtons | Where-Object Key -eq 'Stats' | Select-Object -ExpandProperty Wrap
    $cs = New-Card 'Monitoring & Validasi Arsip' $c_teal 980 'Pindai arsip dengan Single-Source Validation & perbarui status'
    $btnScan = New-Btn 'Scan Seluruh Arsip' $c_teal 320 40
    $btnScan.Add_Click({ Invoke-ExportStatus })
    $btnRing2 = New-Btn 'Tampilkan Ringkasan Teks' $c_purple 320 40
    $btnRing2.Add_Click({ Show-Ringkasan })
    Add-ButtonRow $cs @($btnScan, $btnRing2) 320 40
    Fit-Card $cs
    [void]$wrapS.Controls.Add($cs)

    $ct = New-Card 'Pohon Status Arsip' $c_teal 980 'Klik ganda folder mana saja untuk langsung membuka di Windows Explorer'
    $Script:Tree = New-Object System.Windows.Forms.TreeView
    $Script:Tree.BackColor = Col('#0F1522')
    $Script:Tree.ForeColor = $c_text
    $Script:Tree.Font = Fui 9.5
    $Script:Tree.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $Script:Tree.FullRowSelect = $true
    $Script:Tree.Width = 936
    $Script:Tree.Height = 400
    $Script:Tree.Margin = New-Object System.Windows.Forms.Padding(20, 6, 0, 10)
    $Script:Tree.Add_NodeMouseDoubleClick({
        if ($_.Node.Tag) { Open-Folder ([string]$_.Node.Tag) }
    })
    [void]$ct.Controls.Add($Script:Tree)
    Fit-Card $ct
    [void]$wrapS.Controls.Add($ct)
}

$form = Build-Main
Build-Tabs
$Script:activeTab = ''
Select-Tab 'Home'
$form.Add_Shown({
    Add-Log 'Prothesa Util siap. Pilih menu di sisi kiri.' 'Cyan'
    Add-Log "Base path arsip: $Script:BasePath" 'DarkGray'
    Refresh-Stats
    if (Test-ArchiveEmpty) {
        Add-Log 'Arsip kosong (fresh clone). Membuka wizard setup awal...' 'Yellow'
        if (-not (Get-TemplateSourceDir)) {
            Add-Log 'Template belum ada — lihat _TEMPLATES/README.md (repo privat).' 'Yellow'
        }
        Show-FirstRunWizard
    }
})
$form.Add_FormClosed({ Save-Config })

if ($env:PROTHESA_SMOKE -eq '1') {
    $smokeTimer = New-Object System.Windows.Forms.Timer
    $smokeTimer.Interval = 1600
    $smokeTimer.Add_Tick({ $Script:Form.Close() })
    $smokeTimer.Start()
}

try {
    [void]$form.ShowDialog()
}
catch {
    $err = "PROTHESA UTIL ERROR: $($_.Exception.Message)"
    Add-Log $err 'Red'
    try { $err | Out-File -FilePath (Join-Path $env:TEMP 'prothesa-util-error.log') -Encoding UTF8 } catch { }
    try {
        [void][System.Windows.Forms.MessageBox]::Show($err, 'Prothesa Util - Error', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    catch { }
}
