#!/bin/bash

# --- 检查权限[强制要求使用sudo执行脚本, 避免在脚本内部使用sudo(配合rsync script command)] ---
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ 错误：本脚本必须以 root 权限运行。"
  echo "   请使用: sudo $0"
  exit 1
fi

# 1. 锁定 VPN 接口 ( netstat 结果中得知)
VPN_IF="utun4" 
echo "--- 正在启动 VPN 路由分流脚本 (v8 - Root) ---"
echo "✅ 锁定 VPN 接口: $VPN_IF"

# 2. 开始清理
echo "--- 开始清理 'utun4' 上的劫持路由 ---"
TOTAL_ROUTES=0
DELETED_ROUTES=0

# 读取所有 IPv4 路由 (netstat -f inet)
# 筛选出所有 $4 (第4列) == $VPN_IF 接口的路由
# 然后读取它们的 目标(destination) 和 网关(gateway)
while read -r destination gateway; do
  TOTAL_ROUTES=$((TOTAL_ROUTES + 1))

  # --- 白名单 (使用正则表达式) ---
  # 保留:
  # 1. 10.x.x.x (例如 10.16.114.50)
  # 2. 172.16.x.x - 172.31.x.x (例如 172.18.28.63)
  # 3. 192.168.x.x (本地网络)
  if echo "$destination" | grep -E -q "^10(\.|/|$)" || \
     echo "$destination" | grep -E -q "^172\.(1[6-9]|2[0-9]|3[0-1])(\.|/|$)" || \
     echo "$destination" | grep -E -q "^192\.168(\.|/|$)"; then
    # echo "    [保留] $destination (内网/局域网)"
    continue
  fi

  # --- 黑名单 ---
  # 所有其他路由 (例如 1.x, 183.x, 185.x)，全部删除
  echo "    [删除] $destination (劫持路由)"
  route delete "$destination" "$gateway" > /dev/null 2>&1
  DELETED_ROUTES=$((DELETED_ROUTES + 1))

done < <(netstat -nr -f inet | awk -v vpn_if="$VPN_IF" '$4 == vpn_if {print $1, $2}')

echo "---"
echo "✅ 路由清理完毕！"
echo "   总共检查了 $TOTAL_ROUTES 条 '$VPN_IF' 路由。"
echo "   删除了 $DELETED_ROUTES 条劫持路由。"
echo "   保留了 $((TOTAL_ROUTES - DELETED_ROUTES)) 条内网路由。"
echo "---"
