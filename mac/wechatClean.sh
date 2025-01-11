#!/bin/bash

# 定义微信图片存储基础路径和桌面路径
BASE_WECHAT_PATH="$HOME/Library/Containers/com.tencent.xinWeChat/Data/Library/Application Support/com.tencent.xinWeChat/2.0b4.0.9"
DESKTOP_PATH="$HOME/Desktop/WeChatBackup"

# 创建桌面备份文件夹
mkdir -p "$DESKTOP_PATH"

# 帮助信息
show_help() {
    echo "使用方法: $0 [-t 时间参数] [-o 操作]"
    echo
    echo "选项:"
    echo "  -t [数字][d|m|y]  - 时间参数，例如 20d 表示 20 天前，3m 表示 3 个月前，1y 表示 1 年前"
    echo "                      不输入时间参数则默认处理所有文件"
    echo "  -o [move|restore] - 操作，move 表示移动原图和视频到桌面备份文件夹，restore 表示还原到微信存储路径"
    echo
    echo "示例:"
    echo "  $0 -t 20d -o move    - 移动 20 天前的原图和视频"
    echo "  $0 -o restore        - 还原所有备份的原图和视频"
}

# 默认值
TIME_PARAM="0"
OPERATION=""

# 解析命令行参数
while getopts ":t:o:h" opt; do
    case $opt in
        t) TIME_PARAM="$OPTARG" ;;
        o) OPERATION="$OPTARG" ;;
        h) show_help; exit 0 ;;
        \?) echo "无效的选项: -$OPTARG" >&2; show_help; exit 1 ;;
        :) echo "选项 -$OPTARG 需要一个参数" >&2; show_help; exit 1 ;;
    esac
done

# 解析时间参数
if [[ $TIME_PARAM =~ ^([0-9]+)([dmy])$ ]]; then
    NUMBER=${BASH_REMATCH[1]}
    UNIT=${BASH_REMATCH[2]}
    case $UNIT in
        d) TIME_MOD="-mtime +$NUMBER" ;;
        m) TIME_MOD="-mtime +$((NUMBER * 30))" ;;
        y) TIME_MOD="-mtime +$((NUMBER * 365))" ;;
        *) echo "无效的时间单位"; exit 1 ;;
    esac
elif [[ $TIME_PARAM == "0" ]]; then
    TIME_MOD=""
else
    echo "无效的时间格式"
    show_help
    exit 1
fi

# 显示进度条
show_progress() {
    local current=$1
    local total=$2
    local percent=$((current * 100 / total))
    local progress=$((percent / 2))
    printf "\r[%-50s] %d%% (%d/%d)" $(printf "#%.0s" $(seq 1 $progress)) $percent $current $total
}

# 移动原图和视频到桌面备份文件夹
move_files() {
    local files=()
    # 遍历所有账号文件夹
    for account_dir in "$BASE_WECHAT_PATH"/*; do
        if [ -d "$account_dir" ]; then
            account_name=$(basename "$account_dir")
            if [ ${#account_name} -eq 32 ]; then
                message_temp_path="$account_dir/Message/MessageTemp"
                if [ -d "$message_temp_path" ]; then
                    # 查找符合条件的原图和视频文件
                    while IFS= read -r thumb_file; do
                        original_file="${thumb_file%_thumb.jpg}.jpg"
                        if [ -f "$original_file" ]; then
                            files+=("$original_file")
                        fi
                        hd_file="${thumb_file%_thumb.jpg}_hd.jpg"  # 新增这一行，获取对应的高清图文件名
                        if [ -f "$hd_file" ]; then
                            files+=("$hd_file")  # 将高清图文件名添加到待移动列表中
                        fi
                    done < <(find "$message_temp_path" -type f -name "*pic_thumb.jpg" $TIME_MOD)

                    # 查找符合条件的 mp4 文件
                    while IFS= read -r mp4_file; do
                        files+=("$mp4_file")
                    done < <(find "$message_temp_path" -type f -name "*.mp4" $TIME_MOD)
                fi
            fi
        fi
    done

    local total=${#files[@]}
    if [ $total -eq 0 ]; then
        echo "没有找到符合条件的文件。"
        return
    fi

    local count=0
    local update_interval=$((total / 1000))
    update_interval=$((update_interval < 1 ? 1 : update_interval))  # 确保 update_interval 至少为 1

    for file in "${files[@]}"; do
        relative_path="${file#$BASE_WECHAT_PATH/}"
        mkdir -p "$DESKTOP_PATH/$(dirname "$relative_path")"
        mv "$file" "$DESKTOP_PATH/$relative_path"
        ((count++))
        if ((count % update_interval == 0 || count == total)); then
            show_progress $count $total
        fi
    done
    echo -e "\n文件已移动到桌面备份文件夹。"
}

# 还原文件到微信存储路径
restore_files() {
    local files=()
    while IFS= read -r file; do
        files+=("$file")
    done < <(find "$DESKTOP_PATH" -type f \( -name "*pic.jpg" -o -name "*.mp4" -o -name "*pic_hd.jpg" \))

    local total=${#files[@]}
    if [ $total -eq 0 ]; then
        echo "没有找到需要还原的文件。"
        return
    fi

    local count=0
    local update_interval=$((total / 1000))
    update_interval=$((update_interval < 1 ? 1 : update_interval))  # 确保 update_interval 至少为 1

    for file in "${files[@]}"; do
        relative_path="${file#$DESKTOP_PATH/}"
        mkdir -p "$BASE_WECHAT_PATH/$(dirname "$relative_path")"
        mv "$file" "$BASE_WECHAT_PATH/$relative_path"
        ((count++))
        if ((count % update_interval == 0 || count == total)); then
            show_progress $count $total
        fi
    done
    echo -e "\n文件已还原到微信存储路径。"
}

# 检查操作参数
if [[ -z "$OPERATION" ]]; then
    echo "操作参数是必需的"
    show_help
    exit 1
fi

# 根据用户选择执行操作
case $OPERATION in
    move) move_files ;;
    restore) restore_files ;;
    *) echo "无效的操作"; show_help; exit 1 ;;
esac
