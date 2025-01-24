#!/bin/bash

# 网站列表
# 改成你自己的 serv00 页面地址,可以如示添加多个
# 如果结合该项目 https://github.com/ymyuuu/Cloudflare-Workers-Proxy, 且你自己拥有多个母鸡的 serv00 可以不同母鸡的 serv00 互相保活，一劳永逸。
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
