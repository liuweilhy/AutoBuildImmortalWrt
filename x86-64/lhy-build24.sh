#!/bin/bash
# 镜像信息
echo "Image name:     $IMAGENAME"
echo "luci version:   $LUCI_VERSION"
echo "Image size:     $PROFILE MB"
echo "router ip:      $CUSTOM_ROUTER_IP"
echo "enable istore:  $ENABLE_STORE"
echo "enable docker:  $ENABLE_DOCKER"
echo "Include others: $INCLUDE_OTHERS"
echo "Enable PPPOE:   $ENABLE_PPPOE"
echo "PPPOE account:  $PPPOE_ACCOUNT"
echo "PPPOE password: $PPPOE_PASSWORD"

# 软件包信息
source shell/lhy-custom-packages.sh
source shell/switch_repository.sh
echo "custom packages: $CUSTOM_PACKAGES"

# PPPOE相关
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

# 第三方插件，以及我自己的插件
if [ -z "$CUSTOM_PACKAGES" ]; then
  echo "⚪️ 未选择 任何第三方软件包"
else
  # ============= 同步第三方插件库==============
  # 定义插件下载位置（写死别动）
  DOWNLOADTAG=/home/build/immortalwrt/extra-packages/
  mkdir -p $DOWNLOADTAG

  # 下载我的插件
  REPO="liuweilhy/OpenwrtPackages"
  API_URL="https://api.github.com/repos/${REPO}/releases/latest"
  echo "下载 $REPO 最新软件仓库"
  wget -qO- "$API_URL" \
    | grep -o '"browser_download_url": *"[^"]*"' \
    | sed 's/"browser_download_url": *"//;s/"$//' \
    | while read -r url; do
        filename="${url##*/}"
        echo "下载: $filename -> ${DOWNLOADTAG}${filename}"
        wget -q -O "${DOWNLOADTAG}${filename}" "$url"
      done
  echo "下载 $REPO 最新软件仓库完成，文件保存于 $DOWNLOADTAG"

  # 同步第三方软件仓库run/ipk
  echo "🔄 正在同步第三方软件仓库 Cloning run file repo..."
  git clone --depth=1 https://github.com/wukongdaily/store.git /tmp/store-run-repo

  # 拷贝 run/x86 下所有 run 文件和ipk文件 到 extra-packages 目录
  cp -r /tmp/store-run-repo/run/x86/* $DOWNLOADTAG

  echo "✅ Run files copied to extra-packages:"
  ls -lh /home/build/immortalwrt/extra-packages/*.run
  # 解压并拷贝ipk到packages目录
  sh shell/prepare-packages.sh
  ls -lah /home/build/immortalwrt/packages/
fi

# 输出调试信息
echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始构建固件..."

# ============= imm仓库内的插件==============
# 定义所需安装的包列表 下列插件你都可以自行删减
PACKAGES=""
PACKAGES="$PACKAGES curl"
PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"
PACKAGES="$PACKAGES luci-theme-argon"
PACKAGES="$PACKAGES luci-app-argon-config"
PACKAGES="$PACKAGES luci-i18n-argon-config-zh-cn"
#24.10
PACKAGES="$PACKAGES luci-i18n-package-manager-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn"
PACKAGES="$PACKAGES xray-core hysteria luci-i18n-passwall-zh-cn"
PACKAGES="$PACKAGES luci-app-openclash"
PACKAGES="$PACKAGES luci-i18n-homeproxy-zh-cn"
PACKAGES="$PACKAGES openssh-sftp-server"

# 增加一些常用组件（此处与第三方有可能存在兼容性问题的不开启）
PACKAGES="$PACKAGES luci-i18n-vlmcsd-zh-cn"
#PACKAGES="$PACKAGES luci-i18n-nlbwmon-zh-cn"
PACKAGES="$PACKAGES luci-i18n-zerotier-zh-cn"
PACKAGES="$PACKAGES luci-i18n-smartdns-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ddns-go-zh-cn"
PACKAGES="$PACKAGES luci-i18n-frps-zh-cn"
PACKAGES="$PACKAGES luci-i18n-frpc-zh-cn"
PACKAGES="$PACKAGES luci-i18n-wol-zh-cn"
PACKAGES="$PACKAGES luci-i18n-filemanager-zh-cn"
PACKAGES="$PACKAGES luci-i18n-wechatpush-zh-cn"
PACKAGES="$PACKAGES luci-i18n-upnp-zh-cn"
#PACKAGES="$PACKAGES luci-i18n-uhttpd-zh-cn"
PACKAGES="$PACKAGES luci-i18n-cloudflared-zh-cn"
#PACKAGES="$PACKAGES luci-i18n-nft-qos-zh-cn"
#PACKAGES="$PACKAGES luci-i18n-banip-zh-cn"

# ======== shell/custom-packages.sh =======
# 合并imm仓库以外的第三方插件
PACKAGES="$PACKAGES $CUSTOM_PACKAGES"

# 判断是否需要编译 iStore 插件
if [ "$ENABLE_STORE" = "true" ]; then
    PACKAGES="$PACKAGES luci-app-store"
    echo "Adding package: luci-app-store"
fi

# 判断是否需要编译 Docker 插件
if [ "$ENABLE_DOCKER" = "true" ]; then
    PACKAGES="$PACKAGES luci-i18n-dockerman-zh-cn"
    echo "Adding package: luci-i18n-dockerman-zh-cn"
fi

# 判断是否需要编译我自定义的插件
if [ "$INCLUDE_OTHERS" = "yes" ]; then
    PACKAGES="$PACKAGES luci-app-poweroffdevice luci-i18n-poweroffdevice-zh-cn"
    echo "Adding package: luci-app-poweroffdevice luci-i18n-poweroffdevice-zh-cn"
fi

# 若构建openclash 则添加内核
if echo "$PACKAGES" | grep -q "luci-app-openclash"; then
    echo "✅ 已选择 luci-app-openclash，添加 openclash core"
    mkdir -p files/etc/openclash/core
    # Download clash_meta
    META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-amd64.tar.gz"
    wget -qO- $META_URL | tar xOvz > files/etc/openclash/core/clash_meta
    chmod +x files/etc/openclash/core/clash_meta
    # Download GeoIP and GeoSite
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat -O files/etc/openclash/GeoIP.dat
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat -O files/etc/openclash/GeoSite.dat
else
    echo "⚪️ 未选择 luci-app-openclash"
fi

# 若构建 AdGuardHome 则添加内核
if echo "$PACKAGES" | grep -q "luci-app-adguardhome"; then
    echo "✅ 已选择 luci-app-adguardhome，添加 AdGuardHome 内核"
    mkdir -p files/usr/bin
    # Download AdGuardHome
    META_URL="https://github.com/AdguardTeam/AdGuardHome/releases/latest/download/AdGuardHome_linux_amd64.tar.gz"
    wget -qO- $META_URL | tar xOvz > files/usr/bin/AdGuardHome
    chmod +x files/usr/bin/AdGuardHome
else
    echo "⚪️ 未选择 luci-app-adguardhome"
fi


# 构建镜像
echo "$(date '+%Y-%m-%d %H:%M:%S') - Building image with the following packages:"
echo "$PACKAGES"
make image PROFILE="generic" EXTRA_IMAGE_NAME="$IMAGENAME" PACKAGES="$PACKAGES" FILES="/home/build/immortalwrt/files" ROOTFS_PARTSIZE=$PROFILE
if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi
echo "$(date '+%Y-%m-%d %H:%M:%S') - Build completed successfully."
