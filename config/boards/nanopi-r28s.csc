# Rockchip RK3528A quad core 1GB RAM SoC 2x GBe eMMC WiFi6/BT USB-C
BOARD_NAME="NanoPi R28S"
BOARD_VENDOR="friendlyelec"
BOARDFAMILY="rk35xx"
BOOTCONFIG="hinlink_rk3528_defconfig"
BOARD_MAINTAINER=""
INTRODUCED="2026"
KERNEL_TARGET="current,edge,bleedingedge"
KERNEL_TEST_TARGET="current"
FULL_DESKTOP="no"
HAS_VIDEO_OUTPUT="no"
BOOT_FDT_FILE="rockchip/rk3528-nanopi-r28s.dtb"
BOOT_SCENARIO="spl-blobs"
IMAGE_PARTITION_TABLE="gpt"
BOOTFS_TYPE="ext4"
BOOTSIZE="512"

# The board has no U-Boot defconfig of its own. U-Boot only has to bring up DRAM
# (done by the rkbin ddrbin blob here) and the SD/eMMC controller, and the R28S
# shares that part of the design with the other FriendlyElec RK3528 boards, which
# all reuse hinlink_rk3528_defconfig.

# The AIC8800D80 WiFi/BT module needs an out-of-tree driver. It is built through
# DKMS inside the chroot, which is a real chance of breaking an otherwise good
# image on a kernel this recent, so it is off unless asked for:
#   ./compile.sh build BOARD=nanopi-r28s ... ENABLE_AIC8800=yes
if [[ "${ENABLE_AIC8800:-no}" == "yes" ]]; then
	AIC8800_TYPE="sdio"
	enable_extension "radxa-aic8800"
fi

# Armbian builds 7.3 from v7.3-rc1, which wedges the SD host on this board:
# dw_mmc times out on a bare SDMMC_CMD_UPD_CLK, the card is rescanned in a loop,
# and boots take minutes or hang before the rootfs appears. v7.3-rc2 does not,
# with the same device tree - verified on the board under iozone, zero mmc
# errors. So stay on rc2 until 7.3 is released, at which point this whole hook
# goes away with the release-candidate handling it overrides.
#
# It runs at 800, after that handling at 750, so it overrides rather than races
# it, and sets KERNELSOURCE itself because the hook that points rc kernels at
# Linus' tree only matches the tag it pinned.
function mainline_kernel_decide_version__800_nanopi_r28s_pin_rc() {
	if [[ "${KERNEL_MAJOR_MINOR}" != "7.3" ]]; then
		return 0
	fi
	declare -g KERNELBRANCH="tag:v7.3-rc2"
	declare -g KERNELSOURCE="https://github.com/torvalds/linux.git"
	display_alert "$BOARD" "Pinning ${KERNEL_MAJOR_MINOR} to ${KERNELBRANCH}" "info"
}

# RK3528 debug UART is UART0 (ttyS0), not UART2 (ttyS2) like other RK35xx SoCs.
# On this board it is behind the on-board USB-UART bridge on the second Type-C
# jack, and runs at 1500000 bps.
function post_family_config__nanopi_r28s_serial_console() {
	declare -g SERIALCON="ttyS0"
	display_alert "$BOARD" "Using ${BOOT_FDT_FILE} and SERIALCON=${SERIALCON}" "info"
}

function post_family_tweaks__nanopi_r28s_serial_console() {
	display_alert "$BOARD" "Adjusting boot.cmd serial console to ttyS0" "info"
	sed -i 's/console=ttyS2,1500000/console=ttyS0,1500000/g' "${SDCARD}"/boot/boot.cmd
	mkimage -C none -A arm -T script -d "${SDCARD}"/boot/boot.cmd "${SDCARD}"/boot/boot.scr
}

# The two ports are not the same kind of device: WAN is the SoC GMAC with an
# RTL8211F, LAN is an RTL8111H behind the PCIe Gen2 x1 root port. The names
# below follow from that - end0 from the ethernet0 device tree alias, enp1s0
# from the PCI slot - so they move if either changes.
function post_family_tweaks_bsp__nanopi_r28s_leds() {
	display_alert "Creating board support LEDs config for $BOARD"
	cat <<- EOF > "${destination}"/etc/armbian-leds.conf
		[/sys/class/leds/red:heartbeat]
		trigger=heartbeat
		brightness=1
		invert=0

		[/sys/class/leds/green:wan]
		trigger=netdev
		interval=50
		brightness=1
		link=1
		tx=1
		rx=1
		device_name=end0

		[/sys/class/leds/green:lan]
		trigger=netdev
		interval=50
		brightness=1
		link=1
		tx=1
		rx=1
		device_name=enp1s0
	EOF
}
