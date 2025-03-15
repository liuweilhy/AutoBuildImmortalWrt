#!/bin/bash
# Log file for debugging
LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting 99-custom.sh at $(date)" >> $LOGFILE
echo "Image name:     $IMAGENAME"
echo "Image size:     $PARTSIZE MB"
echo "Include docker: $INCLUDE_DOCKER"
echo "Include others: $INCLUDE_OTHERS"
echo "Enable PPPOE:   $ENABLE_PPPOE"
echo "PPPOE account:  $PPPOE_ACCOUNT"
echo "PPPOE password: $PPPOE_PASSWORD"


# 创建pppoe配置文件 yml传入环境变量ENABLE_PPPOE等 写入配置文件 供99-custom.sh读取
echo "Create pppoe-settings"
mkdir -p  /home/build/immortalwrt/files/etc/config
cat << EOF > /home/build/immortalwrt/files/etc/config/pppoe-settings
enable_pppoe=${ENABLE_PPPOE}
pppoe_account=${PPPOE_ACCOUNT}
pppoe_password=${PPPOE_PASSWORD}
EOF
echo "cat pppoe-settings"
cat /home/build/immortalwrt/files/etc/config/pppoe-settings


# 输出调试信息
echo "$(date '+%Y-%m-%d %H:%M:%S') - Build start..."


# 定义所需安装的包列表 下列插件你都可以自行删减
PACKAGES=""
PACKAGES="$PACKAGES curl"
PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"
# 服务——FileBrowser 用户名admin 密码admin
# PACKAGES="$PACKAGES luci-i18n-filebrowser-go-zh-cn"
PACKAGES="$PACKAGES luci-i18n-argon-config-zh-cn"
#24.10
PACKAGES="$PACKAGES luci-i18n-package-manager-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn"
PACKAGES="$PACKAGES openssh-sftp-server"
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
PACKAGES="$PACKAGES luci-i18n-frps-zh-cn"
PACKAGES="$PACKAGES luci-i18n-frpc-zh-cn"
PACKAGES="$PACKAGES luci-i18n-wol-zh-cn"
PACKAGES="$PACKAGES luci-i18n-filemanager-zh-cn"
PACKAGES="$PACKAGES luci-i18n-wechatpush-zh-cn"
PACKAGES="$PACKAGES luci-i18n-upnp-zh-cn"
PACKAGES="$PACKAGES luci-i18n-uhttpd-zh-cn"
# PACKAGES="$PACKAGES luci-i18n-openvpn-server-zh-cn"
PACKAGES="$PACKAGES luci-i18n-cloudflared-zh-cn"
# PACKAGES="$PACKAGES luci-i18n-appfilter-zh-cn"
PACKAGES="$PACKAGES luci-i18n-attendedsysupgrade-zh-cn"
PACKAGES="$PACKAGES luci-i18n-nft-qos-zh-cn"
PACKAGES="$PACKAGES v2ray-geoip v2ray-geosite geoview chinadns-ng"

# 添加nftables对iptables的兼容层
PACKAGES="$PACKAGES iptables-nft"
PACKAGES="$PACKAGES ip6tables-nft"


# 判断是否需要编译Docker插件
if [ "$INCLUDE_DOCKER" == "yes" ]; then
  echo "Adding package: luci-i18n-dockerman-zh-cn"
  PACKAGES="$PACKAGES docker"
  PACKAGES="$PACKAGES dockerd"
  PACKAGES="$PACKAGES luci-i18n-dockerman-zh-cn"
fi


# 判断是否需要编译其它插件
if [ "$INCLUDE_OTHERS" == "yes" ]; then
  echo "Adding other packages:"
  # 多线多拨mwan3插件，暂未支持nftables
  PACKAGES="$PACKAGES luci-i18n-mwan3-zh-cn"
  # 单线多拨syncdial插件，大部分运营商已不支持
  # PACKAGES="$PACKAGES luci-app-syncdial"
  # 添加非官方插件
  PACKAGES="$PACKAGES v2dat ipt2socks xray-core sing-box"
  PACKAGES="$PACKAGES shadowsocks-libev-config shadowsocks-libev-ss-local shadowsocks-libev-ss-redir shadowsocks-libev-ss-server shadowsocksr-libev-ssr-local shadowsocksr-libev-ssr-redir"
  PACKAGES="$PACKAGES luci-app-autotimeset"
  PACKAGES="$PACKAGES luci-app-poweroffdevice luci-i18n-poweroffdevice-zh-cn"
  PACKAGES="$PACKAGES luci-app-adguardhome"
  PACKAGES="$PACKAGES nikki luci-app-nikki luci-i18n-nikki-zh-cn"
  PACKAGES="$PACKAGES mosdns luci-app-mosdns luci-i18n-mosdns-zh-cn"
fi

# 一些VPN相关包
PACKAGES="$PACKAGES luci-app-openclash"
PACKAGES="$PACKAGES luci-i18n-passwall-zh-cn"
PACKAGES="$PACKAGES luci-i18n-homeproxy-zh-cn"

# 构建镜像
echo "$(date '+%Y-%m-%d %H:%M:%S') - Building image with the following packages:"
echo "$PACKAGES"
make image PROFILE="generic" EXTRA_IMAGE_NAME="$IMAGENAME" PACKAGES="$PACKAGES" FILES="/home/build/immortalwrt/files" ROOTFS_PARTSIZE=$PARTSIZE
if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi
echo "$(date '+%Y-%m-%d %H:%M:%S') - Build completed successfully."
