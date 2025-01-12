# 定义脚本接受的参数，$t用于指定时间范围筛选文件，$o用于指定操作类型
param (
    [string]$t = "",
    [string]$o,
    [switch]$help  # 添加帮助参数
)

# 显示帮助信息的函数
function Show-Help {
    Write-Host "使用说明:"
    Write-Host "脚本参数:"
    Write-Host "-t <时间范围> : 指定时间范围筛选文件，格式为 'Xd'（天），'Xm'（月），'Xy'（年）"
    Write-Host "-o <操作类型> : 指定操作类型，支持 'move'（移动文件），'restore'（还原文件），'decrypt'（解密文件）"
    Write-Host "-help : 显示此帮助信息"
}

# 检查参数有效性
if ($help) {
    Show-Help
    exit
}

if (-not $o -or ($o -ne "move" -and $o -ne "restore" -and $o -ne "decrypt")) {
    Write-Host "无效的操作类型: $o"
    Show-Help
    exit
}

# 获取桌面路径，用于备份和还原文件的目标位置
$desktopPath = [Environment]::GetFolderPath('Desktop')
# 定义微信文件根目录路径，使用当前用户环境变量动态获取用户名，适配不同用户情况
$weChatBasePath = "C:\Users\$($env:USERNAME)\Documents\WeChat Files"

# 定义异或值和文件扩展名的哈希表，用于解密.dat文件，键为文件扩展名，值为文件头对应的异或值
$xorValues = @{
    "png" = @(0x89, 0x50, 0x4E)
    "jpg" = @(0xFF, 0xD8, 0xFF)
    "gif" = @(0x47, 0x49, 0x46)
}

# 解析时间参数的函数，根据传入的时间参数返回对应的截止时间点，如果未传入参数则返回 $null，表示不限制时间
function ParseTimeSpan {
    param (
        [string]$timeParam
    )
    if ($timeParam) {
        $timeSpan = switch -regex ($timeParam) {
            "(\d+)d" { [TimeSpan]::FromDays([int]$matches[1]) }
            "(\d+)m" { [TimeSpan]::FromDays([int]$matches[1] * 30) }
            "(\d+)y" { [TimeSpan]::FromDays([int]$matches[1] * 365) }
            default { throw "无效的时间参数: $timeParam" }
        }
        return (Get-Date).Add(-$timeSpan)
    }
    return $null
}

# 解密.dat文件为图片文件的函数，接收文件路径和输出目录路径作为入参
function ConvertDatToImage($filePath, $outputDir) {
    $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
    $format = $null
    $xorValue = 0

    foreach ($k in $xorValues.Keys) {
        $xorHeader = $xorValues[$k]
        $headerBytes = $fileBytes[0..2]
        $res = @()
        for ($i = 0; $i -lt $headerBytes.Length; $i++) {
            $res += $headerBytes[$i] -bxor $xorHeader[$i]
        }
        if ($res[0] -eq $res[1] -and $res[1] -eq $res[2]) {
            $format = $k
            $xorValue = $res[0]
            break
        }
    }

    if ($format -ne $null) {
        $decodedBytes = $fileBytes | ForEach-Object { $_ -bxor $xorValue }
        $outputFilePath = Join-Path -Path $outputDir -ChildPath ([System.IO.Path]::GetFileNameWithoutExtension($filePath) + ".$format")

        # 确保输出目录存在
        $outputDirPath = [System.IO.Path]::GetDirectoryName($outputFilePath)
        if (-Not (Test-Path -Path $outputDirPath)) {
            New-Item -ItemType Directory -Path $outputDirPath -Force | Out-Null
        }

        [System.IO.File]::WriteAllBytes($outputFilePath, $decodedBytes)
    } else {
        Write-Host "无法识别格式: $filePath"
    }
}

# 处理单个账号文件夹下文件的函数，接收账号路径、备份目录、是否还原操作以及截止时间等参数
function ProcessAccountFiles($accountPath, $backupDir,  $cutoffDate = $null) {
    # 确定视频文件所在路径（FileStorage\Video 文件夹下）
    $videoPath = Join-Path -Path $accountPath -ChildPath "FileStorage\Video"
    # 确定MsgAttach下的Image文件夹路径，该文件夹下存放.dat图片文件，可能存在多层级子目录
    $msgAttachImagePath = Join-Path -Path $accountPath -ChildPath "FileStorage\MsgAttach"

    # 用于存储所有要处理的文件路径，包括视频文件和多层级目录下的.dat图片文件
    $filesToProcess = @()

    # 获取视频文件列表并添加到要处理的文件列表中
    if (-not [string]::IsNullOrEmpty($videoPath) -and (Test-Path $videoPath)) {
        if ($cutoffDate) {
            $filesToProcess += Get-ChildItem -Path $videoPath -Recurse -File | Where-Object {
                $_.CreationTime -lt $cutoffDate
            }
        } else {
            $filesToProcess += Get-ChildItem -Path $videoPath -Recurse -File
        }
    }

    # 递归获取MsgAttach下Image文件夹及其多层级子目录中的.dat图片文件列表，并添加到要处理的文件列表中
    if (-not [string]::IsNullOrEmpty($msgAttachImagePath) -and (Test-Path $msgAttachImagePath)) {
        $msgAttachImageFiles = Get-ChildItem -Path $msgAttachImagePath -Recurse -File | Where-Object {
            $_.DirectoryName -like "*\FileStorage\MsgAttach\*\Image\*" -and $_.Extension -eq ".dat" -and
            (-not $cutoffDate -or $_.CreationTime -lt $cutoffDate)
        }
        $filesToProcess += $msgAttachImageFiles
    }

    # 获取要处理的文件总数
    $totalFiles = $filesToProcess.Count
    if ($totalFiles -eq 0) {
        Write-Host "没有找到符合条件的文件。"
        return
    }

    $currentFileIndex = 0

    foreach ($file in $filesToProcess) {
        # 计算文件相对于微信文件根目录的相对路径，用于在备份目录中保持相同结构
        $relativePath = $file.FullName.Substring($weChatBasePath.Length).TrimStart('\')
        $destination = Join-Path -Path $backupDir -ChildPath $relativePath

        # 创建目标目录（如果不存在），确保备份时目录结构完整
        $destinationDir = [System.IO.Path]::GetDirectoryName($destination)
        if (-Not (Test-Path -Path $destinationDir)) {
            New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
        }

        if ($o -eq "move") {
            try {
                # 移动文件到备份目录，捕获文件已存在的异常并忽略
                Move-Item -Path $file.FullName -Destination $destination -ErrorAction SilentlyContinue
            } catch [System.IO.IOException] {
                continue
            }
        } 

        # 更新进度条信息，展示当前处理文件数量和总文件数量的进度情况
        $currentFileIndex++
        $percentComplete = [math]::Round(($currentFileIndex / $totalFiles) * 100, 2)
        Write-Progress -Activity "微信文件处理" -PercentComplete $percentComplete -Status "处理文件" -CurrentOperation "正在处理文件 $currentFileIndex/$totalFiles"
    }
}

# 解析时间参数，获取截止时间点
$cutoffDate = ParseTimeSpan -timeParam $t

# 根据操作类型执行相应操作
if ($o -eq "move") {
    Get-ChildItem -Path $weChatBasePath -Directory | Where-Object {
        Test-Path -Path (Join-Path -Path $_.FullName -ChildPath "FileStorage")
    } | ForEach-Object {
        $accountPath = $_.FullName
        $accountId = [System.IO.Path]::GetFileName($accountPath)
        $backupDir = Join-Path -Path $desktopPath -ChildPath "WeChatBackup"
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        ProcessAccountFiles -accountPath $accountPath -backupDir $backupDir  -cutoffDate $cutoffDate
    }
} elseif ($o -eq "restore") {
    # 还原文件到原本微信存储的目录
    $backupDir = Join-Path -Path $desktopPath -ChildPath "WeChatBackup"
    $filesToRestore = Get-ChildItem -Path $backupDir -Recurse -File
    $totalFiles = $filesToRestore.Count
    if ($totalFiles -eq 0) {
        Write-Host "没有找到要还原的文件。"
        return
    }
    $currentFileIndex = 0

    foreach ($file in $filesToRestore) {
        $relativePath = $file.FullName.Substring($backupDir.Length).TrimStart('\')
        $originalPath = Join-Path -Path $weChatBasePath -ChildPath $relativePath
        $originalDir = [System.IO.Path]::GetDirectoryName($originalPath)

        # 创建目标目录（如果不存在）
        if (-Not (Test-Path -Path $originalDir)) {
            New-Item -ItemType Directory -Path $originalDir -Force | Out-Null
        }

        # 移动文件到原本的微信存储目录
        Move-Item -Path $file.FullName -Destination $originalPath -ErrorAction SilentlyContinue

        # 更新进度条信息
        $currentFileIndex++
        $percentComplete = [math]::Round(($currentFileIndex / $totalFiles) * 100, 2)
        Write-Progress -Activity "还原微信文件" -PercentComplete $percentComplete -Status "还原文件" -CurrentOperation "正在还原文件 $currentFileIndex/$totalFiles"
    }
} elseif ($o -eq "decrypt") {
    # 解密桌面备份后的 .dat 文件为图片
    $backupDir = Join-Path -Path $desktopPath -ChildPath "WeChatBackup"
    $datFiles = Get-ChildItem -Path $backupDir -Recurse -File -Filter "*.dat"
    $totalFiles = $datFiles.Count
    if ($totalFiles -eq 0) {
        Write-Host "没有找到要解密的文件。"
        return
    }
    $currentFileIndex = 0

    foreach ($file in $datFiles) {
        ConvertDatToImage -filePath $file.FullName -outputDir (Join-Path -Path $desktopPath -ChildPath "DecryptedImages")

        # 更新进度条信息
        $currentFileIndex++
        $percentComplete = [math]::Round(($currentFileIndex / $totalFiles) * 100, 2)
        Write-Progress -Activity "解密微信文件" -PercentComplete $percentComplete -Status "解密文件" -CurrentOperation "正在解密文件 $currentFileIndex/$totalFiles"
    }
} else {
    Write-Host "无效的操作类型: $o"
    Show-Help
}