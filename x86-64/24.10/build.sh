#!/bin/bash
# Log file for debugging
LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting 99-custom.sh at $(date)" >> $LOGFILE
echo "编译固件大小为: $PROFILE MB"
echo "Include Docker: $INCLUDE_DOCKER"

echo "Create pppoe-settings"
mkdir -p  /home/build/immortalwrt/files/etc/config

# 创建pppoe配置文件 yml传入环境变量ENABLE_PPPOE等 写入配置文件 供99-custom.sh读取
cat << EOF > /home/build/immortalwrt/files/etc/config/pppoe-settings
enable_pppoe=${ENABLE_PPPOE}
pppoe_account=${PPPOE_ACCOUNT}
pppoe_password=${PPPOE_PASSWORD}
EOF

echo "cat pppoe-settings"
cat /home/build/immortalwrt/files/etc/config/pppoe-settings
# 输出调试信息
echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始编译..."



# 定义所需安装的包列表 下列插件你都可以自行删减
PACKAGES=""
PACKAGES="$PACKAGES curl"
PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"
# 服务——FileBrowser 用户名admin 密码admin
# PACKAGES="$PACKAGES luci-i18n-filebrowser-go-zh-cn"
PACKAGES="$PACKAGES luci-app-argon-config"
PACKAGES="$PACKAGES luci-i18n-argon-config-zh-cn"
#24.10
PACKAGES="$PACKAGES luci-i18n-package-manager-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn"
PACKAGES="$PACKAGES luci-i18n-passwall-zh-cn"
PACKAGES="$PACKAGES luci-app-openclash"
PACKAGES="$PACKAGES luci-i18n-homeproxy-zh-cn"
PACKAGES="$PACKAGES openssh-sftp-server"
# 添加nftables对iptables的兼容层
PACKAGES="$PACKAGES iptables-nft"
PACKAGES="$PACKAGES ip6tables-nft"
# 增加几个必备组件 方便用户安装iStore
PACKAGES="$PACKAGES fdisk"
PACKAGES="$PACKAGES script-utils"
PACKAGES="$PACKAGES luci-i18n-samba4-zh-cn"
# 增加一些常用组件
PACKAGES="$PACKAGES luci-i18n-vlmcsd-zh-cn"
PACKAGES="$PACKAGES luci-i18n-nlbwmon-zh-cn"
PACKAGES="$PACKAGES luci-i18n-zerotier-zh-cn"
PACKAGES="$PACKAGES luci-i18n-smartdns-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ddns-go-zh-cn"
PACKAGES="$PACKAGES luci-i18n-nfs-zh-cn"
# 多线多拨mwan3插件，暂未支持nftables
PACKAGES="$PACKAGES luci-i18n-mwan3-zh-cn"
# 单线多拨syncdial插件，大部分运营商已不支持
# PACKAGES="$PACKAGES luci-app-syncdial"
PACKAGES="$PACKAGES luci-i18n-frps-zh-cn"
PACKAGES="$PACKAGES luci-i18n-frpc-zh-cn"
PACKAGES="$PACKAGES luci-i18n-timewol-zh-cn"
PACKAGES="$PACKAGES luci-i18n-filemanager-zh-cn"
PACKAGES="$PACKAGES luci-i18n-wechatpush-zh-cn"
PACKAGES="$PACKAGES luci-i18n-upnp-zh-cn"
PACKAGES="$PACKAGES luci-i18n-uhttpd-zh-cn"
# PACKAGES="$PACKAGES luci-i18n-openvpn-server-zh-cn"
PACKAGES="$PACKAGES luci-i18n-cloudflared-zh-cn"
PACKAGES="$PACKAGES luci-i18n-appfilter-zh-cn"
PACKAGES="$PACKAGES luci-i18n-attendedsysupgrade-zh-cn"

# 判断是否需要编译 Docker 插件
if [ "$INCLUDE_DOCKER" = "yes" ]; then
    PACKAGES="$PACKAGES luci-i18n-dockerman-zh-cn"
    echo "Adding package: luci-i18n-dockerman-zh-cn"
    # docker默认仅支持iptables规则，未支持nftables规则。所以再次添加防火墙规则支持nftables
    uci add firewall forwarding
    uci set firewall.@forwarding[-1].src='lan'
    uci set firewall.@forwarding[-1].dest='docker'
    uci add firewall forwarding
    uci set firewall.@forwarding[-1].src='docker'
    uci set firewall.@forwarding[-1].dest='lan'
    uci add firewall forwarding
    uci set firewall.@forwarding[-1].src='docker'
    uci set firewall.@forwarding[-1].dest='wan'
    uci commit firewall
    /etc/init.d/firewall reload
    echo "Adding dockerd firewall rules"
fi

# 构建镜像
echo "$(date '+%Y-%m-%d %H:%M:%S') - Building image with the following packages:"
echo "$PACKAGES"

make image PROFILE="generic" PACKAGES="$PACKAGES" FILES="/home/build/immortalwrt/files" ROOTFS_PARTSIZE=$PROFILE

if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Build completed successfully."
