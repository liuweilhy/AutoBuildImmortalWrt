#!/bin/sh
# 99-custom.sh 就是immortalwrt固件首次启动时运行的脚本 位于固件内的/etc/uci-defaults/99-custom.sh
# Log file for debugging
LOGFILE="/tmp/99-custom.sh.log"
echo "Starting 99-custom.sh at $(date)" >> $LOGFILE

# 读取用户配置文件custom 该文件由build.sh动态生成
custom_main_enabled='1'
custom_pppoe_enabled='0'
custom_pppoe_account=''
custom_pppoe_password=''
if uci -q get custom > /dev/null; then
    # 读取配置信息
    custom_main_enabled=$(uci -q get custom.main.enabled)
    custom_pppoe_enabled=$(uci -q get custom.pppoe.enabled)
    custom_pppoe_account=$(uci -q get custom.pppoe.account)
    custom_pppoe_password=$(uci -q get custom.pppoe.password)
else
    echo "custom config not found. Skipping." >> $LOGFILE
fi

# 判断是否需要重置
if [ "$custom_main_enabled" == "0" ]; then
    echo "Skip custom config" >> $LOGFILE
    exit 0
fi

# 设置默认防火墙规则，方便虚拟机首次访问 WebUI
#uci set firewall.@zone[1].input='ACCEPT'
#uci commit firewall

# 设置主机名映射，解决安卓原生 TV 无法联网的问题
uci add dhcp domain
uci set "dhcp.@domain[-1].name=time.android.com"
uci set "dhcp.@domain[-1].ip=203.107.6.88"
uci commit dhcp

# 计算网卡数量
count=0
ifnames=""
for iface in /sys/class/net/*; do
    iface_name=$(basename "$iface")
    # 检查是否为物理网卡（排除回环设备和无线设备）
    if [ -e "$iface/device" ] && echo "$iface_name" | grep -Eq '^eth|^en'; then
        count=$((count + 1))
        ifnames="$ifnames $iface_name"
    fi
done
# 删除多余空格
ifnames=$(echo "$ifnames" | awk '{$1=$1};1')

# 网络设置
if [ "$count" -eq 1 ]; then
    # 单网口设备 类似于NAS模式 动态获取ip模式 具体ip地址取决于上一级路由器给它分配的ip 也方便后续你使用web页面设置旁路由
    # 单网口设备 不支持修改ip 不要在此处修改ip 
    uci set network.lan.proto='dhcp'
elif [ "$count" -gt 1 ]; then
    # 提取第一个接口作为WAN
    wan_ifname=$(echo "$ifnames" | awk '{print $1}')
    # 剩余接口保留给LAN
    lan_ifnames=$(echo "$ifnames" | cut -d ' ' -f2-)
    # 设置WAN接口基础配置
    uci set network.wan=interface
    # 提取第一个接口作为WAN
    uci set network.wan.device="$wan_ifname"
    # WAN接口默认DHCP
    uci set network.wan.proto='dhcp'
    # 设置WAN6接口基础配置
    uci set network.wan6=interface
    uci set network.wan6.device='@wan'
    # 更新LAN接口成员
    # 查找对应设备的section名称
    section=$(uci show network | awk -F '[.=]' '/\.@?device\[\d+\]\.name=.br-lan.$/ {print $2; exit}')
    if [ -z "$section" ]; then
        echo "error：cannot find device 'br-lan'." >> $LOGFILE
    else
        # 删除所有现有的ports列表
        uci -q delete "network.$section.ports"
        # 添加新的ports列表（从数组的第二个元素开始）
        for port in $lan_ifnames; do
            uci add_list "network.$section.ports"="$port"
        done
        echo "ports of device 'br-lan' are update." >> $LOGFILE
    fi
    # LAN口设置静态IP
    uci set network.lan.proto='static'
    # 多网口设备 支持修改为别的ip地址
    uci set network.lan.ipaddr='192.168.123.1'
    uci set network.lan.netmask='255.255.255.0'
    echo "set 192.168.123.1 at $(date)" >> $LOGFILE
    # 判断是否启用 PPPoE
    echo "print custom_pppoe_enabled value == $custom_pppoe_enabled" >> $LOGFILE
    if [ "$custom_pppoe_enabled" == "1" ]; then
        echo "PPPoE is enabled at $(date)" >> $LOGFILE
        # 设置宽带拨号信息
        uci set network.wan.proto='pppoe'
        uci set network.wan.username=$custom_pppoe_account
        uci set network.wan.password=$custom_pppoe_password
        uci set network.wan.peerdns='1'
        uci set network.wan.auto='1'
        echo "PPPoE configuration completed successfully." >> $LOGFILE
    else
        echo "PPPoE is not enabled. Skipping configuration." >> $LOGFILE
    fi
fi
uci commit network

# 设置所有网口可连接 SSH
uci set dropbear.@dropbear[0].Interface=''
uci commit dropbear

# 设置所有网口可访问网页终端
if uci show ttyd | grep -q "ttyd.@ttyd\[0\]"; then
    uci set ttyd.@ttyd[0].interface=''
    uci commit ttyd
fi

# 默认不启动mwan3
if uci show mwan3 | grep -q "mwan3.wan.enabled"; then
    uci set mwan3.wan.enabled='0'
    uci commit mwan3
fi

# 默认不启用nft-qos限速
if uci show nft-qos | grep -q "nft-qos.default"; then
    uci set nft-qos.default.limit_enable='0'
    uci commit nft-qos
fi

# 设置编译作者信息
FILE_PATH="/etc/openwrt_release"
NEW_DESCRIPTION="Compiled by liuweilhy"
sed -i "s/DISTRIB_DESCRIPTION='[^']*'/DISTRIB_DESCRIPTION='$NEW_DESCRIPTION'/" "$FILE_PATH"

# 配置文件custom设为不启用，避免已修改的配置在保留配置升级时被替换
uci set custom.main.enabled='0'
uci commit custom

exit 0
