# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

inherit git-2

DESCRIPTION="Backup for disk images of virtual machines managed by Libvirt."
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
        >=virtual/backup-cron-2.7
        >=app-emulation/libvirt-1.2.17"

src_unpack() {
    git-2_src_unpack
}

src_install() {
    dodir /etc/cron.weekly
    dosbin ${S}/usr/sbin/backup_libvirt.cron

	if [ ! -h /etc/cron.*/backup_libvirt.cron ]; then
		dosym /usr/sbin/backup_libvirt.cron /etc/cron.weekly/backup_libvirt.cron
	fi

}

pkg_postinst() {
    ewarn "See previous considerations at: "
    ewarn "https://proyectos.ingeniovirtual.com.ar/projects/backup-cron/wiki/Consideraciones_previas"
    einfo "This utility backs disk images of virtual machines managed by libvirt to the compressed qcow2 format."
    einfo "The backup files have .qcow2 file extension."
    einfo "More information about qcow2 in: https://people.gnome.org/~markmc/qcow-image-format.html"
}
