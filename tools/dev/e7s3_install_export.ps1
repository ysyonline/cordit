param([int]$SkipTo = 3)
# 阶段参数：3=解压+导出, 2=校验+解压+导出, 1=下载+全部

$ErrorActionPreference = "Continue"
$proj = "D:\code\cordit"
$tpl = "$env:LOCALAPPDATA\Temp\godot-templates\em2.tpz"
$vdir = "$proj\.godot_user_tmp\Godot\export_templates\4.7.2.stable"
$url = "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
$godot = "C:\Users\weixufeng\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
$log = "D:\code\cordit\evidence\e7s3-export.log"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Log($m) { Write-Output ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $m) }

function Test-Zip($path) {
    try {
        $fs = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $zip = [System.IO.Compression.ZipArchive]::new($fs, [System.IO.Compression.ZipArchiveMode]::Read)
        $c = $zip.Entries.Count
        $zip.Dispose()
        $fs.Dispose()
        return $c
    } catch {
        try { $fs.Dispose() } catch {}
        return -1
    }
}

function Expand-Zip($path) {
    $fs = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
    $zip = [System.IO.Compression.ZipArchive]::new($fs, [System.IO.Compression.ZipArchiveMode]::Read)
    $n = 0
    foreach ($e in $zip.Entries) {
        if ($e.Name -eq "") { continue }
        $rel = $e.FullName
        if ($rel.StartsWith("templates/")) { $rel = $rel.Substring("templates/".Length) }
        $out = Join-Path $script:vdir $rel
        $dir = [System.IO.Path]::GetDirectoryName($out)
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $s = $e.Open()
        $ofs = [System.IO.File]::Create($out)
        $s.CopyTo($ofs)
        $ofs.Dispose()
        $s.Dispose()
        $n = $n + 1
    }
    $zip.Dispose()
    $fs.Dispose()
    return $n
}

# 阶段1: 下载（如需）
if ($SkipTo -le 1) {
    Log "阶段1: 下载模板"
    curl.exe -L -o $tpl $url -s --retry 5 --retry-all-errors
    Log "下载结束"
}

# 阶段2: 校验
$cnt = Test-Zip $tpl
if ($cnt -lt 0) {
    Log "zip 损坏"
    if ($SkipTo -le 1) {
        Remove-Item $tpl -Force
        curl.exe -L -o $tpl $url -s --retry 5 --retry-all-errors
        $cnt = Test-Zip $tpl
    }
    if ($cnt -lt 0) { Log "zip 仍无法校验，终止"; exit 2 }
}
Log "阶段2: zip 校验通过 entries=$cnt"

# 阶段3: 解压
Log "阶段3: 解压到 $vdir"
New-Item -ItemType Directory -Force -Path $vdir | Out-Null
$n = Expand-Zip $tpl
Log "解压完成 files=$n"
Get-ChildItem $vdir | Select-Object Name, Length

# 阶段4: 导出
Log "阶段4: 导出"
$env:APPDATA = "$proj\.godot_user_tmp"
Push-Location $proj
& $godot --headless --path $proj "--export-release" "Windows Desktop" "export/win/轨迹残响.exe" 2>&1 | Tee-Object -FilePath $log
$code = $LASTEXITCODE
Pop-Location
Log "导出退出码=$code"

if (Test-Path "$proj\export\win\轨迹残响.exe") {
    $p = Get-Item "$proj\export\win\轨迹残响.exe"
    Log "产物=$($p.FullName) size=$($p.Length)"
} else {
    Log "失败: 未找到产物"
    Get-ChildItem "$proj\export" -Recurse -ErrorAction SilentlyContinue | Select-Object FullName
}
Log "完成"