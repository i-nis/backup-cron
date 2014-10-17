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
DEPEND="app-admin/tmpwatch sys-process/vixie-cron >=virtual/backup-cron-2.4"

src_unpack() {
    git-2_src_unpack
}

src_install() {
    dodir /etc/cron.daily
    cp -pR ${WORKDIR}/${P}/etc/cron.daily/backup_etc.cron ${D}/etc/cron.daily
    fperms 700 /etc/cron.daily/backup_etc.cron
}

