# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

inherit git-2

DESCRIPTION="Backup for qcow2 disk images of virtual machines managed by Libvirt."
HOMEPAGE="https://proyectos.ingeniovirtual.com.ar/projects/backup-cron"
SRC_URI=""
EGIT_REPO_URI="https://proyectos.ingeniovirtual.com.ar/backup.git"
EGIT_COMMIT="v${PV}"
IUSE=""
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="amd64 x86"
DEPEND="app-admin/tmpwatch 
        sys-process/vixie-cron 
        >=virtual/backup-cron-2.4 
        app-emulation/libvirt"

src_unpack() {
    git-2_src_unpack
}

src_install() {
    dodir /etc/cron.weekly
    cp -pR ${S}/etc/cron.weekly/backup_libvirt.cron ${D}/etc/cron.weekly
    fperms 700 /etc/cron.weekly/backup_libvirt.cron
}

pkg_postinst() {
    ewarn "This utility backs only disk images on qcow2 format with .img file extension."
    einfo "More information about qcow2 in: https://people.gnome.org/~markmc/qcow-image-format.html"
}

