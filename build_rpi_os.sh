# @author ARJUN C R (arjuncr00@acrlinux.com)
#
# web site https://www.acrlinux.com
#
#!/bin/bash

int_build_env()
{

export SCRIPT_NAME="RASPBERRY PI OS"
export SCRIPT_VERSION="1.7"
export LINUX_NAME="acr-linux"
export DISTRIBUTION_VERSION="2020.5"
export IMAGE_NAME="minimal-acrlinux-rpi-${SCRIPT_VERSION}.img"
export BUILD_OTHER_DIR="build_script_for_other"

# BASE
export KERNEL_BRANCH="4.x" 
export KERNEL_VERSION=""5.6.14
export BUSYBOX_VERSION="1.30.1"
export SYSLINUX_VERSION="6.03"
export UBOOT_VERSION="2019.10"

# EXTRAS
export NCURSES_VERSION="6.1"

# CROSS COMPILE
export ARCH="arm"
export CROSS_GCC="arm-linux-gnueabihf-"
export MCPU="cortex-a7"

export BASEDIR=`realpath --no-symlinks $PWD`
export SOURCEDIR=${BASEDIR}/light-os
export ROOTFSDIR=${BASEDIR}/rootfs
export IMGDIR=${BASEDIR}/img
export RPI_BOOT=${BASEDIR}/rpi_boot
export UBOOT_DIR=${BASEDIR}/raspberry-pi-uboot
export RPI_KERNEL_DIR=${BASEDIR}/linux
export CONFIG_ETC_DIR="${BASEDIR}/os-configs/etc"
export RPI_BASE_BIN=${BASEDIR}/rpi_base_bin
export WORKSPACE="${BASEDIR}/workspace"

#export CFLAGS=-m64
#export CXXFLAGS=-m64

#setting JFLAG
if [ -z "$2" ]
then
        export JFLAG=4
else
        export JFLAG=$2
fi

export CROSS_COMPILE=$BASEDIR/cross-gcc-arm/gcc-arm-8.2-x86_64-arm-linux-gnueabihf/bin/$CROSS_GCC

#configs
export RPI_OS_KCONFIG="$BASEDIR/configs/kernel/rpi_os_kconfig"
export RPI_OS_BUSYBOX_CONFIG="$BASEDIR/configs/busybox/rpi_os_busybox_config"
export RPI_OS_UBOOT_CONFIG="$BASEDIR/configs/uboot/rpi_os_uboot_config"

}

prepare_dirs () {

    cd ${BASEDIR}
    
    if [ ! -d ${SOURCEDIR} ];
    then
        mkdir ${SOURCEDIR}
    fi
    if [ ! -d ${ROOTFSDIR} ];
    then
        mkdir ${ROOTFSDIR}
    fi
    if [ ! -d ${IMGDIR} ];
    then
        mkdir    ${IMGDIR}
	mkdir -p ${IMGDIR}/bootloader
	mkdir -p ${IMGDIR}/boot
	mkdir -p ${IMGDIR}/boot/overlays
	mkdir -p ${IMGDIR}/kernel
    fi
    if [ ! -d ${WORKSPACE} ];
    then
	mkdir ${WORKSPACE}
    fi
}

build_kernel () {

    cd ${SOURCEDIR}

    if [ ! -d ${WORKSPACE}/linux-${KERNEL_VERSION} ];
    then
	    echo "copying kernel src to workspace"
	    cp -r linux-${KERNEL_VERSION} ${WORKSPACE}
	    echo "copying kernel patch to workspace"
	    cp -r kernel-patch ${WORKSPACE}
	    cd  ${WORKSPACE}/linux-${KERNEL_VERSION}
	    for patch in $(ls ../kernel-patch | grep '^[000-999]*_.*.patch'); do
		    echo "applying patch .... '$patch'."
		    patch -p1 < ../kernel-patch/${patch}
            done
    fi

    cd  ${WORKSPACE}/linux-${KERNEL_VERSION}

    if [ "$1" == "-c" ]
    then		    
    	make clean -j$JFLAG ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE
    elif [ "$1" == "-b" ]
    then	    
    	cp $RPI_OS_KCONFIG .config
    	make oldconfig -j$JFLAG  ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE zImage modules dtbs
    
    	make modules_install

    	cp arch/arm/boot/dts/*.dtb            $IMGDIR/boot/
    	cp arch/arm/boot/dts/overlays/*.dtb*  $IMGDIR/boot/overlays/
    	cp arch/arm/boot/dts/overlays/README  $IMGDIR/boot/overlays/
    	cp arch/arm/boot/zImage               $IMGDIR/kernel/rpi-kernel.img
    fi
}

build_busybox () {
    cd ${SOURCEDIR}

    if [ ! -d ${WORKSPACE}/busybox-${BUSYBOX_VERSION} ];
    then
            cp -r busybox-${BUSYBOX_VERSION} ${WORKSPACE}
	    echo "copying busybox patch to workspace"
            cp -r busybox-patch ${WORKSPACE}
            cd  ${WORKSPACE}/busybox-${BUSYBOX_VERSION}
            for patch in $(ls ../busybox-patch | grep '^[000-999]*_.*.patch'); do
                echo "applying patch .... '$patch'."
                patch -p1 < ../busybox-patch/${patch}
            done
    fi

    cd busybox-${BUSYBOX_VERSION}

    if [ "$1" == "-c" ]
    then	    
    	make -j$JFLAG ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE clean
    elif [ "$1" == "-b" ]
    then
	cp $RPI_OS_BUSYBOX_CONFIG .config	    
    	make -j$JFLAG ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE oldconfig
    	sed -i 's|.*CONFIG_STATIC.*|CONFIG_STATIC=y|' .config
    	make  ARCH=$arm CROSS_COMPILE=$CROSS_COMPIL busybox \
        	-j ${JFLAG}

    	make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE install \
        	-j ${JFLAG}

    	rm -rf ${ROOTFSDIR} && mkdir ${ROOTFSDIR}
    	cd _install
    	cp -R . ${ROOTFSDIR}
    	rm  ${ROOTFSDIR}/linuxrc
    fi
}

build_uboot () {
	cd $UBOOT_DIR
        
	if [ -f u-boot-2019.10.tar.bz2 ]
	then
		tar -xf u-boot-2019.10.tar.bz2
		rm u-boot-2019.10.tar.bz2
	fi	

    	if [ ! -d   ${WORKSPACE}/u-boot-${UBOOT_VERSION} ];
    	then
	   echo "copying uboot to workspace"
           cp -r  u-boot-${UBOOT_VERSION} ${WORKSPACE}
	   echo "copying uboot patch to workspace"
           cp -r uboot-patch ${WORKSPACE}
           cd   u-boot-${UBOOT_VERSION}
           for patch in $(ls ../uboot-patch | grep '^[000-999]*_.*.patch'); do
                echo "applying patch .... '$patch'."
                patch -p1 < ../uboot-patch/${patch}
            done
    	fi

	cd u-boot-${UBOOT_VERSION}
	
	if [ "$1" == "-c" ]
	then       	
		make -j$JFLAG ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE distclean
        elif [ "$1" == "-b" ]
	then	
		cp $RPI_OS_UBOOT_CONFIG .config
		make -j$JFLAG ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE oldconfig
		make -j$JFLAG ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE u-boot.bin
		cp u-boot.bin $IMGDIR/bootloader
	else
	     echo "Command Not Supported"
        fi
}

build_extras () {
    #build_ncurses
    cd ${BASEDIR}/${BUILD_OTHER_DIR}
    if [ "$1" == "-c" ]
    then
    	./build_other_main.sh --clean
    elif [ "$1" == "-b" ]
    then
    	./build_other_main.sh --build	    
    fi	    
}

generate_rootfs () {	
    cd ${ROOTFSDIR}
    rm -f linuxrc

    mkdir dev
    mkdir etc
    mkdir proc
    mkdir src
    mkdir sys
    mkdir var
    mkdir var/log
    mkdir srv
    mkdir lib
    mkdir root
    mkdir boot
    mkdir tmp && chmod 1777 tmp

    mkdir -pv usr/{,local/}{bin,include,lib{,64},sbin,src}
    mkdir -pv usr/{,local/}share/{doc,info,locale,man}
    mkdir -pv usr/{,local/}share/{misc,terminfo,zoneinfo}      
    mkdir -pv usr/{,local/}share/man/man{1,2,3,4,5,6,7,8}
    mkdir -pv etc/rc{0,1,2,3,4,5,6,S}.d
    mkdir -pv etc/init.d

    cd etc
    
    cp $CONFIG_ETC_DIR/motd .

    cp $CONFIG_ETC_DIR/hosts .
  
    cp $CONFIG_ETC_DIR/resolv.conf .

    cp $CONFIG_ETC_DIR/fstab .

    rm -r init.d/*

    install -m ${CONFMODE} ${BASEDIR}/${BOOT_SCRIPT_DIR}/rc.d/init.d/functions     init.d/functions
    install -m ${CONFMODE} ${BASEDIR}/${BOOT_SCRIPT_DIR}/rc.d/init.d/network	   init.d/network
    install -m ${MODE}     ${BASEDIR}/${BOOT_SCRIPT_DIR}/rc.d/startup              rcS.d/S01startup
    install -m ${MODE}     ${BASEDIR}/${BOOT_SCRIPT_DIR}/rc.d/shutdown             init.d/shutdown

    chmod +x init.d/*

    ln -s init.d/network   rc0.d/K01network
    ln -s init.d/network   rc1.d/K01network
    ln -s init.d/network   rc2.d/S01network
    ln -s init.d/network   rc3.d/S01network
    ln -s init.d/network   rc4.d/S01network
    ln -s init.d/network   rc5.d/S01network
    ln -s init.d/network   rc6.d/K01network
    ln -s init.d/network   rcS.d/S01network
	
    cp $CONFIG_ETC_DIR/inittab .

    cp $CONFIG_ETC_DIR/group .

    cp $CONFIG_ETC_DIR/passwd .

    cd ${ROOTFSDIR}
    
    cp $CONFIG_ETC_DIR/init .

    chmod +x init

    #creating initial device node
    mknod -m 622 dev/console c 5 1
    mknod -m 666 dev/null c 1 3
    mknod -m 666 dev/zero c 1 5
    mknod -m 666 dev/ptmx c 5 2
    mknod -m 666 dev/tty c 5 0
    mknod -m 666 dev/tty1 c 4 1
    mknod -m 666 dev/tty2 c 4 2
    mknod -m 666 dev/tty3 c 4 3
    mknod -m 666 dev/tty4 c 4 4
    mknod -m 444 dev/random c 1 8
    mknod -m 444 dev/urandom c 1 9
    mknod -m 666 dev/ram b 1 1
    mknod -m 666 dev/mem c 1 1
    mknod -m 666 dev/kmem c 1 2
    chown root:tty dev/{console,ptmx,tty,tty1,tty2,tty3,tty4}

    # sudo chown -R root:root .
    find . | cpio -R root:root -H newc -o | gzip > ${IMGDIR}/rootfs.gz
}

generate_image () {

	dd of=${IMAGE_NAME} seek=2200M bs=1 count=0

	mkdir /mnt/rpi-boot
	mkdir /mnt/rpi-rootfs
	
	parted ${IMAGE_NAME} mktable msdos
	parted ${IMAGE_NAME} mkpart primary fat32 8192s 260MB
	parted ${IMAGE_NAME} mkpart primary ext4 260MB 100%

	dd if=/dev/zero of=${IMAGE_NAME} bs=1 count=440 conv=notrunc
	
	losetup /dev/loop100 ${IMAGE_NAME} --offset $((8192*512)) --sizelimit $((499712*512))
	losetup /dev/loop101 ${IMAGE_NAME} --offset $((507904*512)) --sizelimit $((3997696*512))

	mkfs.vfat -F 32 -n BOOT /dev/loop100
	mkfs.ext4 -L rootfs /dev/loop101

	mount /dev/loop100 /mnt/rpi-boot
	mount /dev/loop101 /mnt/rpi-rootfs

        cp -r ${RPI_BASE_BIN}/* /mnt/rpi-boot
	cp ${IMGDIR}/bootloader/u-boot.bin /mnt/rpi-boot/

	echo "kernel=u-boot.bin" >> /mnt/rpi-boot/config.txt
	sed -i 's/root=PARTUUID=[a-z0-9]*-02/root=\/dev\/mmcblk0p2/' /mnt/rpi-boot/cmdline.txt
	
	#sed -i 's/^PARTUUID=[a-z0-9]*-01/\/dev\/mmcblk0p1/' /mnt/rpi-rootfs/etc/fstab
	#sed -i 's/^PARTUUID=[a-z0-9]*-02/\/dev\/mmcblk0p2/' /mnt/rpi-rootfs/etc/fstab
	
	losetup -d /dev/loop100
	losetup -d /dev/loop101

	umount /dev/loop100
	umount /dev/loop101

	rm -r /mnt/rpi-boot
	rm -r /mnt/rpi-rootfs
}

test_qemu () {
    cd ${BASEDIR}
    if [ -f ${IMAGE_NAME} ];
    then
	qemu-system-arm -kernel kernel_qemu/kernel-qemu -cpu arm1176 -m 256 -M versatilepb -no-reboot -serial stdio -append "root=/dev/sda2 panic=1 rootfstype=ext4 rw" -hda ${IMAGE_NAME}
    fi
    exit 1
}

clean_files () {
    rm -rf ${SOURCEDIR}
    rm -rf ${ROOTFSDIR}
    rm -rf ${ISODIR}
    rm -rf ${RPI_BOOT}
    rm -rf ${IMGDIR}
    rm -rf ${UBOOT_DIR}
    rm -rf ${RPI_KERNEL_DIR}
    rm -rf ${WORKSPACE}
}

init_work_dir()
{
prepare_dirs
}

clean_work_dir()
{
clean_files
}

build_all()
{
build_kernel  -b
build_busybox -b
build_uboot   -b
build_extras  -b
}

rebuild_all()
{
clean_all
build_all
}

clean_all()
{
build_kernel  -c
build_busybox -c
build_uboot   -c
build_extras  -c
}

wipe_rebuild()
{
clean_work_dir
init_work_dir
rebuild_all
}

help_msg()
{
echo -e "#################################################################################\n"

echo -e "########################$SCRIPT_VERSION Utility to Build RPI OS##############################\n"

echo -e "#################################################################################\n"

echo -e "Help message --help\n"

echo -e "Build All: --build-all\n"

echo -e "Rebuild All: --rebuild-all\n"

echo -e "Clean All: --clean-all\n"

echo -e "Wipe and rebuild --wipe-rebuild\n" 

echo -e "Building kernel: --build-kernel --rebuild-kernel --clean-kernel\n"

echo -e "Building busybx: --build-busybox --rebuild-busybox --clean-busybox\n"

echo -e "Building uboot: --build-uboot --rebuild-uboot  --clean-uboot\n"

echo -e "Building other soft: --build-other --rebuild-other --clean-other\n"

echo -e "Creating root-fs: --create-rootfs\n"

echo -e "Create ISO Image: --create-img\n"

echo -e "Cleaning work dir: --clean-work-dir\n"

echo -e "Test with Qemu --Run-qemu\n"

echo "###################################################################################"

}

option()
{

if [ -z "$1" ]
then
help_msg
exit 1
fi

if [ "$1" == "--build-all" ]
then	
build_all
fi

if [ "$1" == "--rebuild-all" ]
then
rebuild_all
fi

if [ "$1" == "--clean-all" ]
then
clean_all
fi

if [ "$1" == "--wipe-rebuild" ]
then
wipe_rebuild
fi

if [ "$1" == "--build-kernel" ]
then
build_kernel -b
elif [ "$1" == "--rebuild-kernel" ]
then
build_kernel -c
build_kernel -b
elif [ "$1" == "--clean-kernel" ]
then
build_kernel -c
fi

if [ "$1" == "--build-busybox" ]
then
build_busybox -b
elif [ "$1" == "--rebuild-busybox" ]
then
build_busybox -c
build_busybox -b
elif [ "$1" == "--clean-busybox" ]
then
build_busybox -c
fi

if [ "$1" == "--build-uboot" ]
then
build_uboot -b
elif [ "$1" == "--rebuild-uboot" ]
then
build_uboot -c
build_uboot -b
elif [ "$1" == "--clean-uboot" ]
then
build_uboot -c
fi

if [ "$1" == "--build-other" ]
then
build_extras -b
elif [ "$1" == "--rebuild-other" ]
then
build_extras -c
build_extras -b
elif [ "$1" == "--clean-other" ]
then
build_extras -c
fi

if [ "$1" == "--create-rootfs" ]
then
generate_rootfs
fi

if [ "$1" == "--create-img" ]
then
generate_image
fi

if [ "$1" == "--clean-work-dir" ]
then
clean_work_dir
fi

if [ "$1" == "--Run-qemu" ]
then
test_qemu
fi

}

main()
{
int_build_env
init_work_dir
option $1
}

#starting of script
main $1 
