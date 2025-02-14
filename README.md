# wechatClean
## 微信瘦身脚本使用说明

### 概述
此脚本用于处理微信历史聊天中的原图、视频等文件，包括移动原文件、还原文件和解密文件。用户可以根据需要指定时间范围来筛选文件。

手机微信推出了自动清理7天前的原图和视频功能，但电脑端并没有此功能。为此，开发了此脚本用于清理自定义时长前的微信聊天原图（保留缩略图）和视频文件。`move` 命令会将指定时间前的原图移动至桌面备份文件夹，用户可以浏览图片，确认无误后可删除桌面的备份文件夹。如果有需要保留的照片，可以单独保存或执行还原命令，将原图放回微信聊天记录中。由于 Windows 版微信对图片进行了加密，无法直接浏览，需执行解密命令进行解密。此脚本旨在减少微信聊天体积。

### 功能
- **移动文件**: 将指定时间范围内的微信原图和视频文件移动到备份目录。
- **还原文件**: 将备份目录中的文件还原到原微信存储目录。
- **解密文件**: 解密桌面备份中的 `.dat` 文件为图片格式（Windows 脚本特有）。

### 使用方法
- **Mac 电脑**: 首先执行 `chmod +x wechatClean.sh` 进行脚本赋权。在终端中执行'./wechatClean.sh 脚本直接运行'
- **Windows 电脑**: 在 PowerShell 中执行脚本。

### 参数说明
- `-t <时间范围>`: 指定时间范围筛选文件，格式为：
  - `Xd`：表示 X 天前（例如 `3d` 表示 3 天前）。
  - `Xm`：表示 X 个月前（例如 `2m` 表示 2 个月前）。
  - `Xy`：表示 X 年前（例如 `1y` 表示 1 年前）。
  
- `-o <操作类型>`: 指定操作类型，支持以下值：
  - `move`：移动文件。
  - `restore`：还原文件。
  - `decrypt`：解密文件。
  
- `-help`：显示帮助信息。

### 示例

#### Windows 示例
1. 移动原图、视频文件（3天前的文件）：
   ```powershell
   .\wechatClean.ps1 -t 3d -o move
   ```
![image](https://github.com/StevenQi7/wechatClean/blob/main/pic/windows/QQ20250105-210816.png)

![image](https://github.com/StevenQi7/wechatClean/blob/main/pic/windows/QQ20250105-210911.png)
1. 还原文件：
   ```powershell
   .\wechatClean.ps1 -o restore
   ```
![image](https://github.com/StevenQi7/wechatClean/blob/main/pic/windows/QQ20250105-211410.png)
2. 解密文件：
   ```powershell
   .\wechatClean.ps1 -o decrypt
   ```
![image](https://github.com/StevenQi7/wechatClean/blob/main/pic/windows/QQ20250105-210950.png)
![image](https://github.com/StevenQi7/wechatClean/blob/main/pic/windows/1736082638381.jpg)

#### Mac 示例
1. 移动原图、视频文件（3天前的文件）：
   ```bash
   chmod +x wechatClean.sh
   ./wechatClean.sh -t 3d -o move
   ```
![image](https://github.com/StevenQi7/wechatClean/blob/main/pic/mac/1736082223101.jpg)

![image](https://github.com/StevenQi7/wechatClean/blob/main/pic/mac/1736082277192.jpg)
2. 还原文件：
   ```bash
   ./wechatClean.sh -o restore
   ```
![image](https://github.com/StevenQi7/wechatClean/blob/main/pic/mac/QQ20250105-210506.png)

![image](https://github.com/StevenQi7/wechatClean/blob/main/pic/mac/QQ20250105-210520.png)

### 注意事项
- 在执行操作之前，请确保备份重要数据，以防数据丢失。

## 免责声明
使用此脚本可能导致数据丢失，作者对此不负任何责任。请在使用前确保已备份重要数据。