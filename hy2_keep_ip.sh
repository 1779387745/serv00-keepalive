#!/bin/bash

# 定义锁文件路径
LOCK_FILE="$HOME/hy2_keep_ip.lock"

# 检查锁文件，确保脚本在 1 小时内只能运行一次.之所以要这样，是防止一个 serv00 母鸡的 ip 全都被墙以后，反反复复换 ip.
if [[ -f "$LOCK_FILE" ]]; then
    last_run_time=$(date -r "$LOCK_FILE" +%s)
    current_time=$(date +%s)
    if (( current_time - last_run_time < 3600 )); then
        echo "Script has already run in the last 1 hours. Exiting."
        exit 0
    fi
fi
touch "$LOCK_FILE"

# 读取配置文件
CONFIG_FILE="$HOME/hy2_keep_ip.config"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "配置文件不存在: $CONFIG_FILE"
    exit 1
fi

ZONE=$(grep '^ZONE=' "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '"')
DNSRECORD=$(grep '^DNSRECORD=' "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '"')
CLOUDFLARE_EMAIL=$(grep '^CLOUDFLARE_EMAIL=' "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '"')
CLOUDFLARE_API_KEY=$(grep '^CLOUDFLARE_API_KEY=' "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '"')

# 使用变量
echo "ZONE: $ZONE"
echo "DNSRECORD: $DNSRECORD"
echo "CLOUDFLARE_EMAIL: $CLOUDFLARE_EMAIL"
echo "CLOUDFLARE_API_KEY: $CLOUDFLARE_API_KEY"

# 更新 DNS 解析的 IP 地址
update_ddns() {
  local zone="$1"
  local dnsrecord="$2"
  local cloudflare_auth_email="$3"
  local cloudflare_auth_key="$4"
  local new_ip="$5"

  if [[ -z "$new_ip" ]]; then
    echo "新的 IP 地址为空，跳过 DNS 更新"
    return 1
  fi

  echo "Updating DNS record $dnsrecord to new IP: $new_ip"

  # 获取 Zone ID
  local zoneid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone&status=active" \
    -H "X-Auth-Email: $cloudflare_auth_email" \
    -H "X-Auth-Key: $cloudflare_auth_key" \
    -H "Content-Type: application/json" | jq -r '.result[0].id')

  if [[ -z "$zoneid" ]]; then
    echo "Error: Zone ID for $zone not found"
    return 1
  fi

  echo "Zone ID for $zone is $zoneid"

  # 获取当前 DNS 记录
  local dns_records=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?type=A&name=$dnsrecord" \
    -H "X-Auth-Email: $cloudflare_auth_email" \
    -H "X-Auth-Key: $cloudflare_auth_key" \
    -H "Content-Type: application/json")

  local current_ip=$(echo "$dns_records" | jq -r '.result[0].content')

  if [[ "$current_ip" != "$new_ip" ]]; then
    echo "Current IP ($current_ip) is different from new IP ($new_ip), deleting all A records for $dnsrecord"

    # 删除所有旧的 DNS 记录
    local dnsrecordids=$(echo "$dns_records" | jq -r '.result[].id')
    for record_id in $dnsrecordids; do
      local delete_response=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$record_id" \
        -H "X-Auth-Email: $cloudflare_auth_email" \
        -H "X-Auth-Key: $cloudflare_auth_key" \
        -H "Content-Type: application/json")
      if [[ $(echo "$delete_response" | jq -r '.success') == "true" ]]; then
        echo "Deleted record ID $record_id"
      else
        echo "Failed to delete record ID $record_id"
        return 1
      fi
    done
  else
    echo "$dnsrecord already points to $new_ip, no changes needed."
    return 0
  fi

  # 创建新的 DNS 记录
  local create_response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records" \
    -H "X-Auth-Email: $cloudflare_auth_email" \
    -H "X-Auth-Key: $cloudflare_auth_key" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"$dnsrecord\",\"content\":\"$new_ip\",\"ttl\":1,\"proxied\":false}")

  if [[ $(echo "$create_response" | jq -r '.success') == "true" ]]; then
    echo "Successfully created/updated A record for $dnsrecord with IP $new_ip"
  else
    echo "Failed to create/update A record for $dnsrecord"
    return 1
  fi
}

# 从配置文件之中读取 hy2ip 地址
read_hy2ip_from_json() {
    local json_file="$HOME/serv00-play/singbox/singbox.json"
    if [[ ! -f "$json_file" ]]; then
        echo "文件不存在: $json_file"
        return 1
    fi
    local hy2ip_value
    hy2ip_value=$(jq -r '.HY2IP' "$json_file" 2>/dev/null)

    if [[ $? -ne 0 ]]; then
        echo "无法解析 JSON 文件: $json_file"
        return 1
    fi

    if [[ "$hy2ip_value" == "null" || -z "$hy2ip_value" ]]; then
        echo "未找到 HY2IP 的值或值为空"
        return 1
    fi

    HY2IP_VALUE="$hy2ip_value"
}

# 检测 ip 被墙的状态
check_ip_status() {
  local target_ip=$1
  local retries=3
  local timeout=2

  for (( i=1; i<=retries; i++ )); do
    local response=$(curl -s --max-time "$timeout" --interface "$target_ip" "https://www.baidu.com")
    if [[ -n "$response" ]]; then
      echo "IP $target_ip 可以正常连接百度"
      return 0
    else
      echo "尝试 $i/$retries: IP $target_ip 无法连接百度"
    fi
  done

  echo "IP $target_ip 无法连接百度（可能被墙或网络问题）"
  return 1
}

# 改变 hy2ip 的配置
chagehy2ip() {
    cd ~/serv00-play/ || { echo "Directory not found"; return 1; }
    if [[ ! -f "start.sh" ]]; then
        echo "start.sh 不存在"
        return 1
    fi
    echo "24" | bash start.sh || { echo "执行 start.sh 失败"; return 1; }
}

# step1: 调用函数 read_hy2ip_from_json 读取当前配置的 hy2ip的状态
read_hy2ip_from_json

# step2: 调用函数 check_ip_status 来检测当前的hy2ip是否被墙
check_ip_status "$HY2IP_VALUE"

# step3: 如果当前的 ip 被墙，则调用chagehy2ip
if [[ $? -eq 1 ]]; then
    echo "IP is blocked, changing hy2ip."
    chagehy2ip
    # step4: 再次调用函数 read_hy2ip_from_json 读取当前配置的 hy2 ip的状态
    read_hy2ip_from_json
    # step5: 如果还是被墙则退出
    check_ip_status "$HY2IP_VALUE"
    if [[ $? -eq 1 ]]; then
        echo "IP still blocked, exiting."
        exit 1
    fi
fi

# step6: 如果之前被墙，之后没有被墙，则通过 ddns 更新到指定的域名之中
new_ip="$HY2IP_VALUE"
if [[ -z "$new_ip" ]]; then
    echo "新的 IP 地址为空，跳过 DNS 更新"
else
    update_ddns "$ZONE" "$DNSRECORD" "$CLOUDFLARE_EMAIL" "$CLOUDFLARE_API_KEY" "$new_ip"
fi
