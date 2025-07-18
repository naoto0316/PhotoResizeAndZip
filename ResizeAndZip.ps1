# <--- 設定読み込み（JSON or CSV いずれか）
# $config = Get-Content 'config.json' -Raw | ConvertFrom-Json
$config = Import-Csv 'config.csv'

# ZIP 処理に必要な型
Add-Type -AssemblyName System.IO.Compression.FileSystem

foreach ($item in $config) {
    $SrcFolder  = $item.SrcFolder
    $Width      = [int]$item.Width
    $GroupSize  = [int]$item.GroupSize
    $DstFolder  = Join-Path $SrcFolder 'chatgpt'
    $BaseName   = Split-Path $SrcFolder -Leaf

    # 出力フォルダー作成
    if (!(Test-Path $DstFolder)) {
        New-Item -ItemType Directory -Path $DstFolder | Out-Null
    }

    # --- リサイズ処理 ---
    Get-ChildItem -Path $SrcFolder -Filter *.jpg | ForEach-Object {
        $in  = $_.FullName
        $out = Join-Path $DstFolder $_.Name
        magick convert $in -resize "${Width}" $out
    }

    # --- ZIP 化処理 ---
    $files     = Get-ChildItem -Path $DstFolder -Filter *.jpg | Sort-Object Name
    $batchCount = 0

    for ($i = 0; $i -lt $files.Count; $i += $GroupSize) {
        $batchCount++
        $batch   = $files[$i..([math]::Min($i + $GroupSize - 1, $files.Count - 1))]
        $zipName = "{0}_{1:0000}.zip" -f $BaseName, $batchCount
        $zipPath = Join-Path $DstFolder $zipName

        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

        $zip = [IO.Compression.ZipArchive]::new(
            [IO.File]::Open($zipPath, [IO.FileMode]::Create),
            [IO.Compression.ZipArchiveMode]::Create
        )
        foreach ($f in $batch) {
            $streamEntry = $zip.CreateEntry($f.Name).Open()
            $fs = [IO.File]::OpenRead($f.FullName)
            $fs.CopyTo($streamEntry)
            $streamEntry.Close(); $fs.Close()
        }
        $zip.Dispose()
        Write-Host "Created $zipName"
    }
}
