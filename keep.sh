#!/bin/bash

# 获取脚本所在目录
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# 记录上次执行时间的文件，放在脚本目录下
TIME_FILE="$SCRIPT_DIR/last_run_time"

# 当前时间戳（秒数）
current_time=$(date +%s)

# 检查时间文件是否存在
if [ -f "$TIME_FILE" ]; then
  # 读取上次的时间戳
  last_time=$(cat "$TIME_FILE")
  # 计算时间间隔（秒数）
  time_diff=$((current_time - last_time))

  # 如果时间间隔小于4分钟（240秒），直接退出
  if [ "$time_diff" -lt 240 ]; then
    echo "距离上次执行未满4分钟，退出脚本"
    exit 0
  fi
fi

# 更新执行时间
echo "$current_time" > "$TIME_FILE"

# 网站列表
urls=(
  "https://abc.serv00.net/info"
  "https://def.serv00.net/info"
  "https://123.serv00.net/info"
  "https://345.serv00.net/info"
  "https://567.serv00.net/info"
)

# 并行执行请求
for url in "${urls[@]}"; do
  curl -s "$url" -o "$(basename "$url").json" > /dev/null 2>&1 &
done

# 等待所有后台任务完成
wait

echo "所有请求完成"
