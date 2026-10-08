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

# Flat dark netral pekat + satu aksen biru (modern, minimal).
# Warna hanya bermakna status: biru = info/siap, hijau = ok, kuning = sibuk/waspada, merah = error.
$c_bg            = Col('#1E1E1E')
$c_bg2           = Col('#252526')
$c_bg3           = Col('#2D2D30')
$c_card          = Col('#252526')
$c_cardHover     = Col('#383838')
$c_line          = Col('#3E3E42')
$c_lineDark      = Col('#2D2D30')
$c_text          = Col('#E8E8E8')
$c_dim           = Col('#A6A6A6')
$c_muted         = Col('#767676')

# Satu aksen + warna status (dipakai hemat, bukan dekorasi)
$c_blue          = Col('#4C9BE8')
$c_blueDark      = Col('#0E639C')
$c_purple        = Col('#A78BFA')
$c_teal          = Col('#2DD4BF')
$c_green         = Col('#3BA55D')
$c_greenDark     = Col('#2D7D46')
$c_red           = Col('#ED4245')
$c_redDark       = Col('#A12D2F')
$c_orange        = Col('#E8A33D')
$c_cyan          = Col('#B5B5B5')
$c_pink          = Col('#F472B6')
$c_amber         = Col('#E8A33D')
$c_gray          = Col('#808080')

$colorMap = @{
    'Black' = '#0E0F12'; 'White' = '#F8FAFC'; 'Gray' = '#94A3B8'; 'DarkGray' = '#64748B'
    'Blue' = '#38BDF8'; 'DarkBlue' = '#0284C7'; 'Cyan' = '#22D3EE'; 'DarkCyan' = '#0891B2'
    'Green' = '#34D399'; 'DarkGreen' = '#059669'; 'Yellow' = '#FDE047'; 'DarkYellow' = '#D97706'
    'Red' = '#F87171'; 'DarkRed' = '#DC2626'; 'Magenta' = '#F472B6'; 'DarkMagenta' = '#DB2777'
    'Purple' = '#A78BFA'; 'Orange' = '#FB923C'; 'Pink' = '#F472B6'; 'Teal' = '#2DD4BF'
}

function Lighten { param([System.Drawing.Color]$Col, [int]$Amt = 18) [System.Drawing.Color]::FromArgb([Math]::Min(255, $Col.R + $Amt), [Math]::Min(255, $Col.G + $Amt), [Math]::Min(255, $Col.B + $Amt)) }

function Set-Rounded {    <#
    .SYNOPSIS
    Membuat sudut kontrol membulat (modern) via Region. Panggil SETELAH ukuran final.
    #>
    param($Control, [int]$Radius = 8)
    try {
        $w = $Control.Width
        $h = $Control.Height
        if ($w -le ($Radius * 2) -or $h -le ($Radius * 2)) { return }
        $d = $Radius * 2
        $p = New-Object System.Drawing.Drawing2D.GraphicsPath
        $p.AddArc(0, 0, $d, $d, 180, 90)
        $p.AddArc($w - $d - 1, 0, $d, $d, 270, 90)
        $p.AddArc($w - $d - 1, $h - $d - 1, $d, $d, 0, 90)
        $p.AddArc(0, $h - $d - 1, $d, $d, 90, 90)
        $p.CloseFigure()
        $Control.Region = New-Object System.Drawing.Region($p)
        $p.Dispose()
    } catch { }
}

try {
    if (-not ([System.Management.Automation.PSTypeName]'ProthesaTheme').Type) {
        Add-Type -TypeDefinition @'
        using System;
        using System.Runtime.InteropServices;
        public class ProthesaTheme {
            [DllImport("dwmapi.dll")]
            public static extern int DwmSetWindowAttribute(IntPtr h, int attr, ref int val, int sz);
            [DllImport("uxtheme.dll", CharSet = CharSet.Unicode)]
            public static extern int SetWindowTheme(IntPtr h, string a, string b);
        }
'@ -ErrorAction SilentlyContinue
    }
} catch { }

function Enable-DarkChrome {
    <#
    .SYNOPSIS
    Titlebar gelap (DWM) untuk form; scrollbar gelap (uxtheme) untuk panel scroll.
    PENTING: jangan pernah SetWindowTheme di handle form — itu menonaktifkan
    visual styles dan seluruh jendela jatuh ke gaya klasik.
    API resmi Win10 1809+; gagal diam-diam di OS lama.
    #>
    param($Control, [switch]$TitleBar)
    try {
        $h = $Control.Handle
        if ($TitleBar) {
            $on = 1
            [void][ProthesaTheme]::DwmSetWindowAttribute($h, 20, [ref]$on, 4)
        }
        else {
            [void][ProthesaTheme]::SetWindowTheme($h, 'DarkMode_Explorer', $null)
        }
    } catch { }
}

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
    param([string]$Text, [System.Drawing.Color]$Bg, [int]$W = 200, [int]$H = 46, [switch]$Ghost)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Font = Fui 10.5 $true
    if ($Ghost) {
        $b.BackColor = $c_bg3
        $b.ForeColor = $c_text
        $b.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $b.FlatAppearance.BorderSize = 1
        $b.FlatAppearance.BorderColor = $c_line
        $b.Tag = $c_bg3
    }
    else {
        $b.BackColor = $Bg
        $b.ForeColor = [System.Drawing.Color]::White
        $b.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $b.FlatAppearance.BorderSize = 0
        $b.Tag = $Bg
    }
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    $b.Width = $W
    $b.Height = $H
    $b.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $b.UseCompatibleTextRendering = $false
    $b.UseVisualStyleBackColor = $false
    $b.Margin = New-Object System.Windows.Forms.Padding(0, 6, 0, 4)
    if (-not $Ghost) { $b.Tag = $Bg }
    $b.Add_MouseEnter({ $this.BackColor = Lighten ([System.Drawing.Color]$this.Tag) 14 })
    $b.Add_MouseLeave({ $this.BackColor = [System.Drawing.Color]$this.Tag })
    [void]$Script:AllButtons.Add($b)
    Set-Rounded $b 7
    return $b
}

function New-Box {
    param([string]$Placeholder = '', [int]$W = 340, [int]$H = 34, [single]$Size = 10)
    $t = New-Object System.Windows.Forms.TextBox
    $t.Width = $W
    $t.Height = $H
    $t.Font = Fui $Size
    $t.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $t.BackColor = Col('#2A2A2A')
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
    $n = New-Object System.Windows.Forms.ComboBox
    $n.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $n.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $n.BackColor = Col('#2A2A2A')
    $n.ForeColor = $c_text
    $n.Font = Fui 10.5 $true
    $n.Width = 110
    $n.Height = 34
    $n.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 4)
    2024..2040 | ForEach-Object { [void]$n.Items.Add($_) }
    $nowYear = (Get-Date).Year
    if ($nowYear -lt 2024) { $nowYear = 2024 }
    if ($nowYear -gt 2040) { $nowYear = 2040 }
    $n.SelectedItem = $nowYear
    return $n
}

function Get-YearVal {
    <#
    .SYNOPSIS
    Ambil tahun sebagai int dari ComboBox tahun (atau NumericUpDown lama).
    #>
    param($Box)
    if ($Box -is [System.Windows.Forms.ComboBox]) {
        $sel = $Box.SelectedItem
        if ($null -eq $sel) { $sel = $Box.Text }
        return [int]$sel
    }
    return [int]$Box.Value
}

function New-Drop {
    param($Items, [int]$W = 220)
    $d = New-Object System.Windows.Forms.ComboBox
    $d.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $d.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $d.BackColor = Col('#2A2A2A')
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
    param([string]$Title, [System.Drawing.Color]$Accent, [int]$W = 1080, [string]$Sub = '')
    $f = New-Object System.Windows.Forms.FlowLayoutPanel
    $f.Width = $W
    $f.Height = 200
    $f.BackColor = $c_card
    $f.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $f.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $f.WrapContents = $false
    $f.AutoScroll = $false
    $f.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 26)
    $f.Padding = New-Object System.Windows.Forms.Padding(4, 4, 4, 14)

    # Header section
    $hdr = New-Object System.Windows.Forms.Panel
    $hdr.Width = $W - 8
    $hdr.Height = if ($Sub) { 62 } else { 48 }
    $hdr.BackColor = [System.Drawing.Color]::Transparent
    $hdr.Margin = New-Object System.Windows.Forms.Padding(0)

    $head = New-Lbl $Title 14 $c_text $true
    $head.Location = New-Object System.Drawing.Point(24, 10)
    [void]$hdr.Controls.Add($head)

    if ($Sub) {
        $s = New-Lbl $Sub 9.5 $c_dim
        $s.Location = New-Object System.Drawing.Point(24, 35)
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
    Set-Rounded $Card 10
}

function Add-CardRow {
    param($Flow, [string]$Label, $Control, [int]$LabelW = 180)
    $wrap = New-Object System.Windows.Forms.Panel
    $wrap.Width = $Flow.Width - 48
    $wrap.Height = 50
    $wrap.BackColor = [System.Drawing.Color]::Transparent
    $wrap.Margin = New-Object System.Windows.Forms.Padding(24, 4, 0, 5)
    if ($Label) {
        $lbl = New-Lbl $Label 10.5 $c_text $true
        $lbl.Margin = New-Object System.Windows.Forms.Padding(0)
        $lbl.Location = New-Object System.Drawing.Point(0, 12)
        [void]$wrap.Controls.Add($lbl)
        $Control.Location = New-Object System.Drawing.Point($LabelW, 5)
    }
    else {
        $Control.Location = New-Object System.Drawing.Point(0, 5)
    }
    [void]$wrap.Controls.Add($Control)
    [void]$Flow.Controls.Add($wrap)
}

function Add-Note {
    param($Flow, [string]$Text, [System.Drawing.Color]$Color = $c_dim)
    $l = New-Lbl $Text 10 $Color
    $l.Margin = New-Object System.Windows.Forms.Padding(24, 4, 0, 10)
    [void]$Flow.Controls.Add($l)
}

function Add-ButtonRow {
    param($Flow, [object[]]$Buttons, [int]$BtnW = 180, [int]$BtnH = 42)
    $wrap = New-Object System.Windows.Forms.Panel
    $wrap.Width = $Flow.Width - 48
    $wrap.Height = $BtnH + 18
    $wrap.BackColor = [System.Drawing.Color]::Transparent
    $wrap.Margin = New-Object System.Windows.Forms.Padding(22, 8, 0, 10)
    $x = 0
    foreach ($b in $Buttons) {
        $b.Width = $BtnW
        $b.Height = $BtnH
        $b.Location = New-Object System.Drawing.Point($x, 4)
        Set-Rounded $b 7
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
    $box.BackColor = Col('#2A2A2A')
    $box.ForeColor = $c_text
    $box.Width = 360
    $box.Location = New-Object System.Drawing.Point(20, 114)
    [void]$dlg.Controls.Add($box)
    $btnBrowse = New-Btn 'Pilih...' $c_gray 120 30 -Ghost
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
    $btnUse = New-Btn 'Gunakan Folder Ini' $c_blueDark 220 38
    $btnUse.Location = New-Object System.Drawing.Point(20, 190)
    $btnUse.Add_Click({
        $Script:BasePath = $box.Text
        if ($Script:BoxPath) { $Script:BoxPath.Text = $Script:BasePath }
        Save-Config
        $dlg.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $dlg.Close()
    })
    [void]$dlg.Controls.Add($btnUse)
    $btnDemo = New-Btn 'Buat Bulan Berjalan' $c_gray 220 38 -Ghost
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
        $btnSample = New-Btn ('Pasang Data Contoh (' + $sampleInfo.Name + ')') $c_gray 460 34 -Ghost
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
    $btnSkip = New-Btn 'Lewati (Mode Kosong)' $c_gray 460 34 -Ghost
    $btnSkip.Location = New-Object System.Drawing.Point(20, $(if ($sampleInfo) { 286 } else { 244 }))
    $btnSkip.Add_Click({ $dlg.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $dlg.Close() })
    [void]$dlg.Controls.Add($btnSkip)
    [void]$dlg.ShowDialog($Script:Form)
    try { Refresh-Stats } catch { }
}

function Get-YM {
    param($YearBox, $MonthCombo)
    if (-not $YearBox -or -not $MonthCombo) { return $null }
    $y = Get-YearVal $YearBox
    $m = $MonthCombo.SelectedIndex + 1
    if ($m -lt 1 -or $m -gt 12) { Add-Log 'Bulan tidak valid.' 'Red'; return $null }
    return @($y, $m)
}

function Update-PeriodLabel {
    if (-not $Script:LblPeriod) { return }
    if (-not $Script:YearBox -or -not $Script:MonthCombo) { return }
    $y = Get-YearVal $Script:YearBox
    $m = $Script:MonthCombo.SelectedIndex + 1
    if ($m -lt 1 -or $m -gt 12) {
        $Script:LblPeriod.Text = 'Bulan tidak valid'
        $Script:LblPeriod.ForeColor = $c_muted
        return
    }
    $mp = $null
    try { $mp = Get-MonthPath -Year $y -Month $m } catch { $mp = $null }
    if (-not $mp) {
        $Script:LblPeriod.Text = ('{0} {1}: belum dibuat' -f $Script:BulanNamesLower[$m], $y)
        $Script:LblPeriod.ForeColor = $c_muted
        return
    }
    $val = $null
    try { $val = Test-ProthesaMonthValidation -MonthPath $mp } catch { }
    $st = if ($val) { $val.StatusText } else { 'Kosong' }
    $code = if ($val) { $val.StatusCode } else { 'empty' }
    $Script:LblPeriod.Text = ('{0}: {1}' -f (Split-Path -Leaf $mp), $st)
    $Script:LblPeriod.ForeColor = switch ($code) {
        'complete'     { $c_green }
        'ready_to_zip' { $c_blue }
        'in_progress'  { $c_orange }
        default        { $c_dim }
    }
}

function Invoke-RenameGui {
    if ($Script:Busy) { return }
    $ym = Get-YM $Script:YearBox $Script:MonthCombo
    if (-not $ym) { return }
    $tanya = [System.Windows.Forms.MessageBox]::Show(
        'Samakan nama file bernomor (1.pdf, 2.pdf, ...) pada bulan kerja mengikuti bulan sebelumnya?',
        'Samakan Nama Berkas',
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($tanya -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    Set-Busy $true
    try {
        Rename-BerkasUmumFromPrevious -Year $ym[0] -Month $ym[1]
        Add-Log 'Samakan nama berkas selesai.' 'Green'
    }
    catch { Add-Log "Error: $($_.Exception.Message)" 'Red' }
    finally { Set-Busy $false; Refresh-Stats }
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
    Update-PeriodLabel
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
            elseif ($mo.StatusCode -eq 'ready_to_zip') { $mn.ForeColor = $c_blue }
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
            $nb.Bar.Visible = $true
            $nb.Bar.BringToFront()
        }
        else {
            $nb.Btn.BackColor = $c_bg2
            if ($nb.WrapBox) { $nb.WrapBox.BackColor = $c_bg2 }
            $nb.Btn.ForeColor = $c_dim
            $nb.Bar.Visible = $false
        }
    }

    $tabDesc = @{
        'Home'    = 'Ringkasan arsip dan status klaim'
        'Monthly' = 'Langkah 1-3: siapkan folder bulan, template, dan pasien'
        'Docs'    = 'Langkah 4-6: isi dokumen, samakan nama, arsipkan ZIP'
        'Stats'   = 'Periksa kelengkapan dan status tiap bulan'
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
    $header.Height = 80
    $header.BackColor = $c_bg2

    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'PROTHESA UTIL'
    $title.Font = Fui 17 $true
    $title.ForeColor = [System.Drawing.Color]::White
    $title.AutoSize = $true
    $title.Location = New-Object System.Drawing.Point(26, 14)
    [void]$header.Controls.Add($title)

    $sub = New-Object System.Windows.Forms.Label
    $sub.Text = 'Arsip klaim BPJS Gigi - drg. Danny Hanggono'
    $sub.Font = Fui 9.5
    $sub.ForeColor = $c_dim
    $sub.AutoSize = $true
    $sub.Location = New-Object System.Drawing.Point(28, 50)
    [void]$header.Controls.Add($sub)
    $Script:HeaderSub = $sub

    # ---- Periode kerja bersama (satu pilihan untuk semua tombol) ----
    $periodLbl = New-Lbl 'Bulan kerja:' 10 $c_dim $false
    $periodLbl.Location = New-Object System.Drawing.Point(360, 24)
    [void]$header.Controls.Add($periodLbl)

    $Script:YearBox = New-YearBox
    $Script:YearBox.Location = New-Object System.Drawing.Point(460, 16)
    [void]$header.Controls.Add($Script:YearBox)

    $Script:MonthCombo = New-Drop $Script:MonthItems 240
    $Script:MonthCombo.Location = New-Object System.Drawing.Point(582, 16)
    $Script:MonthCombo.SelectedIndex = (Get-Date).Month - 1
    [void]$header.Controls.Add($Script:MonthCombo)

    $Script:LblPeriod = New-Lbl '' 9 $c_dim
    $Script:LblPeriod.Location = New-Object System.Drawing.Point(460, 50)
    $Script:LblPeriod.AutoSize = $true
    [void]$header.Controls.Add($Script:LblPeriod)

    $Script:YearBox.Add_SelectedIndexChanged({ Update-PeriodLabel })
    $Script:MonthCombo.Add_SelectedIndexChanged({ Update-PeriodLabel })

    $headerSep = New-Object System.Windows.Forms.Panel
    $headerSep.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $headerSep.Height = 1
    $headerSep.BackColor = $c_line
    [void]$header.Controls.Add($headerSep)

    $right = New-Object System.Windows.Forms.Panel
    $right.Dock = [System.Windows.Forms.DockStyle]::Right
    $right.Width = 280
    $right.BackColor = $c_bg2

    $btnRefresh = New-Btn 'Refresh Data' $c_blueDark 130 40
    $btnRefresh.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
    $btnRefresh.Location = New-Object System.Drawing.Point(30, 20)
    $btnRefresh.Add_Click({ Refresh-Stats; Add-Log 'Refresh data selesai.' 'Cyan' })
    [void]$right.Controls.Add($btnRefresh)

    $btnQuit = New-Btn 'Keluar' $c_gray 90 40 -Ghost
    $btnQuit.ForeColor = Col('#E06C6C')
    $btnQuit.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
    $btnQuit.Location = New-Object System.Drawing.Point(170, 20)
    $btnQuit.Add_Click({ $Script:Form.Close() })
    [void]$right.Controls.Add($btnQuit)

    [void]$header.Controls.Add($right)

    # ==================== ICON RAIL (ala activity bar) ====================
    $side = New-Object System.Windows.Forms.Panel
    $side.Dock = [System.Windows.Forms.DockStyle]::Left
    $side.Width = 64
    $side.BackColor = $c_bg2

    $Script:ToolTip = New-Object System.Windows.Forms.ToolTip
    $navIconFont = New-Object System.Drawing.Font('Segoe MDL2 Assets', 17)

    # ==================== BOTTOM CONSOLE ====================
    $consoleWrap = New-Object System.Windows.Forms.Panel
    $consoleWrap.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $consoleWrap.Height = 124
    $consoleWrap.BackColor = Col('#1A1A1A')
    $Script:ConsoleWrap = $consoleWrap

    $consoleBar = New-Object System.Windows.Forms.Panel
    $consoleBar.Dock = [System.Windows.Forms.DockStyle]::Top
    $consoleBar.Height = 32
    $consoleBar.BackColor = $c_bg2

    $consoleTitle = New-Lbl 'LOG SISTEM' 9 $c_dim $true
    $consoleTitle.Location = New-Object System.Drawing.Point(16, 8)
    [void]$consoleBar.Controls.Add($consoleTitle)

    $Script:ConsoleTicker = New-Lbl 'Prothesa Util siap.' 9 $c_muted
    $Script:ConsoleTicker.Location = New-Object System.Drawing.Point(120, 8)
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
        if ($Script:ConsoleWrap.Height -gt 40) {
            $Script:ConsoleWrap.Height = 32
            $btnToggleLog.Text = 'Buka Log'
        }
        else {
            $Script:ConsoleWrap.Height = 160
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
    $console.BackColor = Col('#1A1A1A')
    $console.ForeColor = Col('#D4D4D4')
    $console.Font = New-Object System.Drawing.Font('Consolas', 10)
    $console.ReadOnly = $true
    $console.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $console.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Both

    [void]$consoleWrap.Controls.Add($console)
    [void]$consoleWrap.Controls.Add($consoleBar)
    Enable-DarkChrome $console

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
        @{ Key = 'Home';    Label = 'Beranda';       Glyph = [char]0xE80F }
        @{ Key = 'Monthly'; Label = 'Siapkan Bulan'; Glyph = [char]0xE787 }
        @{ Key = 'Docs';    Label = 'Isi Arsip';     Glyph = [char]0xE104 }
        @{ Key = 'Stats';   Label = 'Monitoring';    Glyph = [char]0xE890 }
    )
    $iconFont = New-Object System.Drawing.Font('Segoe MDL2 Assets', 12)

    $yPos = 48
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
        Enable-DarkChrome $wrap

        # Nav icon (activity-bar style)
        $btnWrap = New-Object System.Windows.Forms.Panel
        $btnWrap.Left = 0
        $btnWrap.Top = $yPos
        $btnWrap.Width = 64
        $btnWrap.Height = 60
        $btnWrap.BackColor = $c_bg2

        $bar = New-Object System.Windows.Forms.Panel
        $bar.Width = 3
        $bar.Height = 32
        $bar.Left = 0
        $bar.Top = 14
        $bar.BackColor = $c_blue
        $bar.Visible = $false
        [void]$btnWrap.Controls.Add($bar)

        $btn = New-Object System.Windows.Forms.Button
        $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btn.FlatAppearance.BorderSize = 0
        $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
        $btn.Text = [string]$def.Glyph
        $btn.Font = $navIconFont
        $btn.ForeColor = $c_dim
        $btn.BackColor = $c_bg2
        $btn.Left = 0
        $btn.Top = 0
        $btn.Width = 64
        $btn.Height = 60
        $btn.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $btn.UseCompatibleTextRendering = $false
        $btn.UseVisualStyleBackColor = $false
        $btn.Tag = $def.Key
        $Script:ToolTip.SetToolTip($btn, $def.Label)

        # Robust closure-bound click and hover handlers
        $targetKey = $def.Key
        $btnRef = $btn
        $wrapRef = $btnWrap

        $btn.Add_Click({ Select-Tab $targetKey }.GetNewClosure())
        $bar.Add_Click({ Select-Tab $targetKey }.GetNewClosure())

        $btn.Add_MouseEnter({
            if ($Script:activeTab -ne $targetKey) {
                $btnRef.BackColor = Col('#383838')
                $wrapRef.BackColor = Col('#383838')
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
        Set-Rounded $btnWrap 10
        Set-Rounded $btn 10

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
        $yPos += 64
    }

    return $form
}

function Add-StatRow {
    param($Flow, $Blocks)
    $wrap = New-Object System.Windows.Forms.Panel
    $wrap.Width = $Flow.Width - 48
    $wrap.Height = 86
    $wrap.BackColor = [System.Drawing.Color]::Transparent
    $wrap.Margin = New-Object System.Windows.Forms.Padding(22, 10, 0, 16)
    $colW = 200
    $x = 0
    $first = $true
    foreach ($blk in $Blocks) {
        if (-not $first) {
            $div = New-Object System.Windows.Forms.Panel
        $div.Width = 1
        $div.Height = 64
            $div.BackColor = $c_line
            $div.Left = $x
            $div.Top = 10
            [void]$wrap.Controls.Add($div)
            $x += 1
        }
        $first = $false

        $cell = New-Object System.Windows.Forms.Panel
        $cell.Width = $colW
        $cell.Height = 86
        $cell.BackColor = [System.Drawing.Color]::Transparent
        $cell.Left = $x
        $cell.Top = 0
        [void]$wrap.Controls.Add($cell)

        $num = New-Lbl '0' 24 $c_text $true
        $num.Left = 22
        $num.Top = 2
        [void]$cell.Controls.Add($num)

        $cap = New-Lbl $blk.Caption 10.5 $c_dim $false
        $cap.Left = 24
        $cap.Top = 58
        [void]$cell.Controls.Add($cap)

        if ($blk.Caption -eq 'Tahun')    { $Script:LblYears = $num }
        if ($blk.Caption -eq 'Bulan')    { $Script:LblMonths = $num }
        if ($blk.Caption -eq 'Pasien')   { $Script:LblPatients = $num }
        if ($blk.Caption -eq 'Lengkap')  { $Script:LblFull = $num }

        $x += $colW + 24
    }
    [void]$Flow.Controls.Add($wrap)
    return $wrap
}

function Build-Tabs {
    # Satu pilihan periode untuk semua tombol (dulu tiap bagian punya pilihan sendiri).
    $Script:YearBox1 = $Script:YearBox
    $Script:YearBox2 = $Script:YearBox
    $Script:YearBox3 = $Script:YearBox
    $Script:YearBox4 = $Script:YearBox
    $Script:YearBox5 = $Script:YearBox
    $Script:MonthCombo1 = $Script:MonthCombo
    $Script:MonthCombo2 = $Script:MonthCombo
    $Script:MonthCombo3 = $Script:MonthCombo
    $Script:MonthCombo4 = $Script:MonthCombo
    $Script:MonthCombo5 = $Script:MonthCombo

    $pageHome = $Script:panels['Home']
    $wrapH = $Script:NavButtons | Where-Object Key -eq 'Home' | Select-Object -ExpandProperty Wrap

    $c1 = New-Card 'Ringkasan' $c_blue 1080 'Kondisi arsip saat ini'
    $statRow = Add-StatRow $c1 @(
        @{ Caption = 'Tahun'; Color = $c_blue }
        @{ Caption = 'Bulan'; Color = $c_teal }
        @{ Caption = 'Pasien'; Color = $c_purple }
        @{ Caption = 'Lengkap'; Color = $c_green }
    )
    Fit-Card $c1
    [void]$wrapH.Controls.Add($c1)

    $c2 = New-Card 'Data Tersimpan Di' $c_green 1080 'Folder utama berisi arsip tahunan (A=2024, B=2025, C=2026, dst)'
    $Script:BoxPath = New-Box '' 620 34
    $Script:BoxPath.ReadOnly = $true
    $Script:BoxPath.Text = $Script:BasePath
    $Script:LblPath = $Script:BoxPath
    Add-CardRow $c2 'Lokasi' $Script:BoxPath 140
    $btnOpen = New-Btn 'Buka Folder' $c_blueDark 200 38
    $btnOpen.Add_Click({ Open-Folder $Script:BasePath })
    $btnChange = New-Btn 'Pindah Lokasi' $c_gray 180 38 -Ghost
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
    Fit-Card $c2
    [void]$wrapH.Controls.Add($c2)

    $c3 = New-Card 'Yang Bisa Dilakukan' $c_blue 1080 'Periksa arsip atau mulai kerjakan bulan berjalan'
    $btnExport = New-Btn 'Periksa Arsip' $c_gray 458 40 -Ghost
    $btnExport.Add_Click({ Invoke-ExportStatus })
    $btnRing = New-Btn 'Lihat Ringkasan' $c_gray 458 40 -Ghost
    $btnRing.Add_Click({ Show-Ringkasan })
    Add-ButtonRow $c3 @($btnExport, $btnRing) 458 40
    $btnOpenRoot = New-Btn 'Buka Folder Arsip' $c_gray 458 40 -Ghost
    $btnOpenRoot.Add_Click({ Open-Folder $Script:BasePath })
    $btnGoMonthly = New-Btn 'Mulai: Siapkan Bulan' $c_blueDark 458 40
    $btnGoMonthly.Add_Click({ Select-Tab 'Monthly' })
    Add-ButtonRow $c3 @($btnOpenRoot, $btnGoMonthly) 458 40
    Fit-Card $c3
    [void]$wrapH.Controls.Add($c3)

    $Script:LblPath = $Script:BoxPath

    $wrapB = $Script:NavButtons | Where-Object Key -eq 'Monthly' | Select-Object -ExpandProperty Wrap
    Add-Note $wrapB 'Ikuti urutan 1 - 2 - 3 di bawah. Semuanya memakai "Bulan kerja" yang dipilih di atas.' $c_dim
    $cm = New-Card 'Langkah 1 - Buat Folder Bulan' $c_blue 1080 'Dibuatkan otomatis: folder tahun, folder bulan, KLAIM, BERKAS UMUM, RJTP'
    $Script:ChkCopy1 = New-Chk 'Juga salinkan 5 template dokumen'
    Add-CardRow $cm '' $Script:ChkCopy1 0
    $Script:ChkAutoCopy = New-Chk 'Langsung isi otomatis setelah disalin'
    $Script:ChkAutoCopy.Checked = $Script:AutoUpdateAfterCopy
    $Script:ChkAutoCopy.Add_CheckedChanged({ $Script:AutoUpdateAfterCopy = $Script:ChkAutoCopy.Checked })
    Add-CardRow $cm '' $Script:ChkAutoCopy 0
    $btnBulan = New-Btn 'Buat Folder Bulan' $c_blueDark 280 42
    $btnBulan.Add_Click({ Invoke-NewMonth })
    Add-CardRow $cm '' $btnBulan 0
    Fit-Card $cm
    [void]$wrapB.Controls.Add($cm)

    $cc = New-Card 'Langkah 2 - Salin Template Dokumen' $c_purple 1080 'Ambil 5 template dari folder _TEMPLATES'
    $Script:ChkAutoCopy2 = New-Chk 'Langsung isi otomatis setelah disalin'
    Add-CardRow $cc '' $Script:ChkAutoCopy2 0
    $btnCopy = New-Btn 'Salin Template' $c_blueDark 280 42
    $btnCopy.Add_Click({ Invoke-CopyTemplate })
    Add-CardRow $cc '' $btnCopy 0
    Add-Note $cc 'Gunakan ini bila Langkah 1 dilewati atau template belum ada.'
    Fit-Card $cc
    [void]$wrapB.Controls.Add($cc)

    $wrapP = $Script:NavButtons | Where-Object Key -eq 'Monthly' | Select-Object -ExpandProperty Wrap
    $cp1 = New-Card 'Langkah 3 - Daftarkan Satu Pasien' $c_green 1080 'Dibuatkan folder bernomor + 3 form kosong (BUKTI LAYANAN, FKPP, RESEP)'
    $Script:BoxPasien = New-Box 'Nama pasien (contoh: SITI AMINAH)' 420 34
    Add-CardRow $cp1 'Nama Pasien' $Script:BoxPasien
    $btnP1 = New-Btn 'Tambah Pasien' $c_blueDark 220 40
    $btnP1.Add_Click({ Invoke-Patient })
    Add-CardRow $cp1 '' $btnP1 0
    Fit-Card $cp1
    [void]$wrapP.Controls.Add($cp1)

    $cp2 = New-Card 'Langkah 3 - Daftarkan Banyak Pasien Sekaligus' $c_pink 1080 'Tulis satu nama tiap baris'
    $Script:BoxBatch = New-Object System.Windows.Forms.TextBox
    $Script:BoxBatch.Multiline = $true
    $Script:BoxBatch.Width = 880
    $Script:BoxBatch.Height = 140
    $Script:BoxBatch.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $Script:BoxBatch.Font = Fui 10
    $Script:BoxBatch.BackColor = Col('#2A2A2A')
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
    $btnP2 = New-Btn 'Buat Semua Folder Pasien' $c_blueDark 280 42
    $btnP2.Add_Click({ Invoke-PatientBatch })
    Add-CardRow $cp2 '' $btnP2 0
    Add-Note $cp2 'File yang dibuat masih kosong - ganti dengan hasil scan PDF asli.'
    Fit-Card $cp2
    [void]$wrapP.Controls.Add($cp2)

    $wrapD = $Script:NavButtons | Where-Object Key -eq 'Docs' | Select-Object -ExpandProperty Wrap
    Add-Note $wrapD 'Lanjutan dari tab Siapkan Bulan. Tetap memakai "Bulan kerja" yang sama.' $c_dim
    $cf = New-Card 'Langkah 4 - Isi Dokumen Otomatis' $c_orange 1080 'Word & Excel diisi otomatis: tanggal, FPK, jumlah kasus, biaya'
    $Script:BoxTanggal = New-Box 'contoh: 6 Maret 2026' 360 34
    Add-CardRow $cf 'Tanggal TTD' $Script:BoxTanggal
    $Script:BoxFpk = New-Box 'contoh: P2601000026282' 360 34
    Add-CardRow $cf 'No. FPK' $Script:BoxFpk
    $Script:BoxKasus = New-Box 'contoh: 7' 200 34
    Add-CardRow $cf 'Jumlah Kasus' $Script:BoxKasus
    $Script:BoxBiaya = New-Box 'contoh: 5250000 (tanpa titik)' 280 34
    Add-CardRow $cf 'Total Biaya (Rp)' $Script:BoxBiaya
    $btnFill = New-Btn 'Isi Dokumen Sekarang' $c_blueDark 360 42
    $btnFill.Add_Click({ Invoke-Update })
    Add-CardRow $cf '' $btnFill 0
    Add-Note $cf 'Butuh Microsoft Word & Excel terpasang di PC ini.'
    Fit-Card $cf
    [void]$wrapD.Controls.Add($cf)

    $cr = New-Card 'Langkah 5 - Samakan Nama Berkas (opsional)' $c_purple 1080 'Ubah "1.pdf, 2.pdf, ..." mengikuti nama bulan sebelumnya'
    $btnRename = New-Btn 'Samakan Nama Berkas' $c_gray 280 42 -Ghost
    $btnRename.Add_Click({ Invoke-RenameGui })
    Add-CardRow $cr '' $btnRename 0
    Add-Note $cr 'Jalankan bila ada file bernomor yang namanya belum lengkap.'
    Fit-Card $cr
    [void]$wrapD.Controls.Add($cr)

    $cz = New-Card 'Langkah 6 - Arsipkan ke ZIP' $c_red 1080 'Berkas bulan dipadatkan jadi satu file .zip siap kirim'
    $btnZip = New-Btn 'Buat ZIP' $c_blueDark 260 42
    $btnZip.Add_Click({ Invoke-Zip })
    Add-CardRow $cz '' $btnZip 0
    Add-Note $cz 'File ZIP tersimpan di samping folder bulan.'
    Fit-Card $cz
    [void]$wrapD.Controls.Add($cz)

    $wrapS = $Script:NavButtons | Where-Object Key -eq 'Stats' | Select-Object -ExpandProperty Wrap
    $cs = New-Card 'Periksa Kelengkapan' $c_teal 1080 'Pindai arsip dan tandai yang kurang'
    $btnScan = New-Btn 'Periksa Sekarang' $c_blueDark 320 40
    $btnScan.Add_Click({ Invoke-ExportStatus })
    $btnRing2 = New-Btn 'Lihat Ringkasan' $c_gray 320 40 -Ghost
    $btnRing2.Add_Click({ Show-Ringkasan })
    Add-ButtonRow $cs @($btnScan, $btnRing2) 320 40
    Fit-Card $cs
    [void]$wrapS.Controls.Add($cs)

    $ct = New-Card 'Status Tiap Bulan' $c_teal 1080 'Klik 2x pada baris untuk membuka foldernya'
    $Script:Tree = New-Object System.Windows.Forms.TreeView
    $Script:Tree.BackColor = Col('#2A2A2A')
    $Script:Tree.ForeColor = $c_text
    $Script:Tree.Font = Fui 9.5
    $Script:Tree.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $Script:Tree.FullRowSelect = $true
    $Script:Tree.Width = 1010
    $Script:Tree.Height = 400
    $Script:Tree.Margin = New-Object System.Windows.Forms.Padding(20, 6, 0, 10)
    $Script:Tree.Add_NodeMouseDoubleClick({
        if ($_.Node.Tag) { Open-Folder ([string]$_.Node.Tag) }
    })
    [void]$ct.Controls.Add($Script:Tree)
    Enable-DarkChrome $Script:Tree
    Fit-Card $ct
    [void]$wrapS.Controls.Add($ct)
}

$form = Build-Main
Build-Tabs
$Script:activeTab = ''
Select-Tab 'Home'
$form.Add_Shown({
    Enable-DarkChrome $Script:Form -TitleBar
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


