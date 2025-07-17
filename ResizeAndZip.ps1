<#
.SYNOPSIS
  指定フォルダー内の画像をリサイズし、10枚ずつ ZIP 化します。

.PARAMETER SrcFolder
  元画像が入っているフォルダーのパス。

.PARAMETER Width
  リサイズ後の横幅（ピクセル）。デフォルト 1366。

.PARAMETER GroupSize
  ZIP にまとめる枚数。デフォルト 10。
#>
Param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SrcFolder,

    [int]$Width     = 1366,
    [int]$GroupSize = 10
)

# 出力先フォルダーを SrcFolder\chatgpt に自動設定
$DstFolder  = Join-Path $SrcFolder "chatgpt"
$BaseName   = Split-Path $SrcFolder -Leaf

# （以下、先ほどのスクリプト本体を貼り付け）
Add-Type -AssemblyName System.IO.Compression.FileSystem

if (!(Test-Path $DstFolder)) {
    New-Item -ItemType Directory -Path $DstFolder | Out-Null
}

# リサイズ
Get-ChildItem -Path $SrcFolder -Filter *.jpg | ForEach-Object {
    $In  = $_.FullName
    $Out = Join-Path $DstFolder $_.Name
    magick convert $In -resize "${Width}" $Out
}

# ZIP 化
$Files      = Get-ChildItem -Path $DstFolder -Filter *.jpg | Sort-Object Name
$BatchCount = 0

for ($i = 0; $i -lt $Files.Count; $i += $GroupSize) {
    $BatchCount++
    $Batch   = $Files[$i..([math]::Min($i + $GroupSize - 1, $Files.Count - 1))]
    $ZipName = "{0}_{1:0000}.zip" -f $BaseName, $BatchCount
    $ZipPath = Join-Path $DstFolder $ZipName

    if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }

    $Zip = [IO.Compression.ZipArchive]::new(
        [IO.File]::Open($ZipPath, [IO.FileMode]::Create),
        [IO.Compression.ZipArchiveMode]::Create
    )

    foreach ($f in $Batch) {
        $EntryStream = $Zip.CreateEntry($f.Name).Open()
        $FileStream  = [IO.File]::OpenRead($f.FullName)
        $FileStream.CopyTo($EntryStream)
        $EntryStream.Close(); $FileStream.Close()
    }

    $Zip.Dispose()
    Write-Host "Created $ZipName"
}
