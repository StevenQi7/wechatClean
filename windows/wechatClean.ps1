# ����ű����ܵĲ�����$t����ָ��ʱ�䷶Χɸѡ�ļ���$o����ָ����������
param (
    [string]$t = "",
    [string]$o,
    [switch]$help  # ��Ӱ�������
)

# ��ʾ������Ϣ�ĺ���
function Show-Help {
    Write-Host "ʹ��˵��:"
    Write-Host "�ű�����:"
    Write-Host "-t <ʱ�䷶Χ> : ָ��ʱ�䷶Χɸѡ�ļ�����ʽΪ 'Xd'���죩��'Xm'���£���'Xy'���꣩"
    Write-Host "-o <��������> : ָ���������ͣ�֧�� 'move'���ƶ��ļ�����'restore'����ԭ�ļ�����'decrypt'�������ļ���"
    Write-Host "-help : ��ʾ�˰�����Ϣ"
}

# ��������Ч��
if ($help) {
    Show-Help
    exit
}

if (-not $o -or ($o -ne "move" -and $o -ne "restore" -and $o -ne "decrypt")) {
    Write-Host "��Ч�Ĳ�������: $o"
    Show-Help
    exit
}

# ��ȡ����·�������ڱ��ݺͻ�ԭ�ļ���Ŀ��λ��
$desktopPath = [Environment]::GetFolderPath('Desktop')
# ����΢���ļ���Ŀ¼·����ʹ�õ�ǰ�û�����������̬��ȡ�û��������䲻ͬ�û����
$weChatBasePath = "C:\Users\$($env:USERNAME)\Documents\WeChat Files"

# �������ֵ���ļ���չ���Ĺ�ϣ�����ڽ���.dat�ļ�����Ϊ�ļ���չ����ֵΪ�ļ�ͷ��Ӧ�����ֵ
$xorValues = @{
    "png" = @(0x89, 0x50, 0x4E)
    "jpg" = @(0xFF, 0xD8, 0xFF)
    "gif" = @(0x47, 0x49, 0x46)
}

# ����ʱ������ĺ��������ݴ����ʱ��������ض�Ӧ�Ľ�ֹʱ��㣬���δ��������򷵻� $null����ʾ������ʱ��
function ParseTimeSpan {
    param (
        [string]$timeParam
    )
    if ($timeParam) {
        $timeSpan = switch -regex ($timeParam) {
            "(\d+)d" { [TimeSpan]::FromDays([int]$matches[1]) }
            "(\d+)m" { [TimeSpan]::FromDays([int]$matches[1] * 30) }
            "(\d+)y" { [TimeSpan]::FromDays([int]$matches[1] * 365) }
            default { throw "��Ч��ʱ�����: $timeParam" }
        }
        return (Get-Date).Add(-$timeSpan)
    }
    return $null
}

# ����.dat�ļ�ΪͼƬ�ļ��ĺ����������ļ�·�������Ŀ¼·����Ϊ���
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

        # ȷ�����Ŀ¼����
        $outputDirPath = [System.IO.Path]::GetDirectoryName($outputFilePath)
        if (-Not (Test-Path -Path $outputDirPath)) {
            New-Item -ItemType Directory -Path $outputDirPath -Force | Out-Null
        }

        [System.IO.File]::WriteAllBytes($outputFilePath, $decodedBytes)
    } else {
        Write-Host "�޷�ʶ���ʽ: $filePath"
    }
}

# �������˺��ļ������ļ��ĺ����������˺�·��������Ŀ¼���Ƿ�ԭ�����Լ���ֹʱ��Ȳ���
function ProcessAccountFiles($accountPath, $backupDir,  $cutoffDate = $null) {
    # ȷ����Ƶ�ļ�����·����FileStorage\Video �ļ����£�
    $videoPath = Join-Path -Path $accountPath -ChildPath "FileStorage\Video"
    # ȷ��MsgAttach�µ�Image�ļ���·�������ļ����´��.datͼƬ�ļ������ܴ��ڶ�㼶��Ŀ¼
    $msgAttachImagePath = Join-Path -Path $accountPath -ChildPath "FileStorage\MsgAttach"

    # ���ڴ洢����Ҫ������ļ�·����������Ƶ�ļ��Ͷ�㼶Ŀ¼�µ�.datͼƬ�ļ�
    $filesToProcess = @()

    # ��ȡ��Ƶ�ļ��б���ӵ�Ҫ������ļ��б���
    if (-not [string]::IsNullOrEmpty($videoPath) -and (Test-Path $videoPath)) {
        if ($cutoffDate) {
            $filesToProcess += Get-ChildItem -Path $videoPath -Recurse -File | Where-Object {
                $_.CreationTime -lt $cutoffDate
            }
        } else {
            $filesToProcess += Get-ChildItem -Path $videoPath -Recurse -File
        }
    }

    # �ݹ��ȡMsgAttach��Image�ļ��м����㼶��Ŀ¼�е�.datͼƬ�ļ��б�����ӵ�Ҫ������ļ��б���
    if (-not [string]::IsNullOrEmpty($msgAttachImagePath) -and (Test-Path $msgAttachImagePath)) {
        $msgAttachImageFiles = Get-ChildItem -Path $msgAttachImagePath -Recurse -File | Where-Object {
            $_.DirectoryName -like "*\FileStorage\MsgAttach\*\Image\*" -and $_.Extension -eq ".dat" -and
            (-not $cutoffDate -or $_.CreationTime -lt $cutoffDate)
        }
        $filesToProcess += $msgAttachImageFiles
    }

    # ��ȡҪ������ļ�����
    $totalFiles = $filesToProcess.Count
    if ($totalFiles -eq 0) {
        Write-Host "û���ҵ������������ļ���"
        return
    }

    $currentFileIndex = 0

    foreach ($file in $filesToProcess) {
        # �����ļ������΢���ļ���Ŀ¼�����·���������ڱ���Ŀ¼�б�����ͬ�ṹ
        $relativePath = $file.FullName.Substring($weChatBasePath.Length).TrimStart('\')
        $destination = Join-Path -Path $backupDir -ChildPath $relativePath

        # ����Ŀ��Ŀ¼����������ڣ���ȷ������ʱĿ¼�ṹ����
        $destinationDir = [System.IO.Path]::GetDirectoryName($destination)
        if (-Not (Test-Path -Path $destinationDir)) {
            New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
        }

        if ($o -eq "move") {
            try {
                # �ƶ��ļ�������Ŀ¼�������ļ��Ѵ��ڵ��쳣������
                Move-Item -Path $file.FullName -Destination $destination -ErrorAction SilentlyContinue
            } catch [System.IO.IOException] {
                continue
            }
        } 

        # ���½�������Ϣ��չʾ��ǰ�����ļ����������ļ������Ľ������
        $currentFileIndex++
        $percentComplete = [math]::Round(($currentFileIndex / $totalFiles) * 100, 2)
        Write-Progress -Activity "΢���ļ�����" -PercentComplete $percentComplete -Status "�����ļ�" -CurrentOperation "���ڴ����ļ� $currentFileIndex/$totalFiles"
    }
}

# ����ʱ���������ȡ��ֹʱ���
$cutoffDate = ParseTimeSpan -timeParam $t

# ���ݲ�������ִ����Ӧ����
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
    # ��ԭ�ļ���ԭ��΢�Ŵ洢��Ŀ¼
    $backupDir = Join-Path -Path $desktopPath -ChildPath "WeChatBackup"
    $filesToRestore = Get-ChildItem -Path $backupDir -Recurse -File
    $totalFiles = $filesToRestore.Count
    if ($totalFiles -eq 0) {
        Write-Host "û���ҵ�Ҫ��ԭ���ļ���"
        return
    }
    $currentFileIndex = 0

    foreach ($file in $filesToRestore) {
        $relativePath = $file.FullName.Substring($backupDir.Length).TrimStart('\')
        $originalPath = Join-Path -Path $weChatBasePath -ChildPath $relativePath
        $originalDir = [System.IO.Path]::GetDirectoryName($originalPath)

        # ����Ŀ��Ŀ¼����������ڣ�
        if (-Not (Test-Path -Path $originalDir)) {
            New-Item -ItemType Directory -Path $originalDir -Force | Out-Null
        }

        # �ƶ��ļ���ԭ����΢�Ŵ洢Ŀ¼
        Move-Item -Path $file.FullName -Destination $originalPath -ErrorAction SilentlyContinue

        # ���½�������Ϣ
        $currentFileIndex++
        $percentComplete = [math]::Round(($currentFileIndex / $totalFiles) * 100, 2)
        Write-Progress -Activity "��ԭ΢���ļ�" -PercentComplete $percentComplete -Status "��ԭ�ļ�" -CurrentOperation "���ڻ�ԭ�ļ� $currentFileIndex/$totalFiles"
    }
} elseif ($o -eq "decrypt") {
    # �������汸�ݺ�� .dat �ļ�ΪͼƬ
    $backupDir = Join-Path -Path $desktopPath -ChildPath "WeChatBackup"
    $datFiles = Get-ChildItem -Path $backupDir -Recurse -File -Filter "*.dat"
    $totalFiles = $datFiles.Count
    if ($totalFiles -eq 0) {
        Write-Host "û���ҵ�Ҫ���ܵ��ļ���"
        return
    }
    $currentFileIndex = 0

    foreach ($file in $datFiles) {
        ConvertDatToImage -filePath $file.FullName -outputDir (Join-Path -Path $desktopPath -ChildPath "DecryptedImages")

        # ���½�������Ϣ
        $currentFileIndex++
        $percentComplete = [math]::Round(($currentFileIndex / $totalFiles) * 100, 2)
        Write-Progress -Activity "����΢���ļ�" -PercentComplete $percentComplete -Status "�����ļ�" -CurrentOperation "���ڽ����ļ� $currentFileIndex/$totalFiles"
    }
} else {
    Write-Host "��Ч�Ĳ�������: $o"
    Show-Help
}