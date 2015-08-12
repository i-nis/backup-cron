# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

inherit git-2

DESCRIPTION="Backup for system configuration files in /etc."
HOMEPAGE="https://proyectos.ingeniovirtual.com.ar/projects/backup-cron"
SRC_URI=""
EGIT_REPO_URI="https://proyectos.ingeniovirtual.com.ar/backup.git"
EGIT_COMMIT="v${PV}"
IUSE=""
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="amd64 x86"
DEPEND="app-admin/tmpwatch sys-process/vixie-cron >=virtual/backup-cron-2.7"

src_unpack() {
    git-2_src_unpack
}

src_install() {
    dodir /etc/cron.daily
    dosbin ${S}/usr/sbin/backup_etc.cron

	if [ ! -h /etc/cron.*/backup_etc.cron ]; then
		dosym /usr/sbin/backup_etc.cron /etc/cron.daily/backup_etc.cron
	fi

}

