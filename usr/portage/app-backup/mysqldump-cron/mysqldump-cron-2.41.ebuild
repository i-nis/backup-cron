# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

inherit git-2

DESCRIPTION="Backup for MySQL."
HOMEPAGE="https://proyectos.ingeniovirtual.com.ar/projects/backup-cron"
SRC_URI=""
EGIT_REPO_URI="https://proyectos.ingeniovirtual.com.ar/backup.git"
EGIT_COMMIT="v${PV}"
IUSE=""
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="amd64 x86"
DEPEND="app-admin/tmpwatch sys-process/vixie-cron >=virtual/backup-cron-2.4 virtual/mysql"

src_unpack() {
    git-2_src_unpack
}

src_install() {
    dodir /etc/cron.daily
    cp -pR ${S}/etc/cron.daily/mysqldump.cron ${D}/etc/cron.daily
    fperms 700 /etc/cron.daily/mysqldump.cron
}

pkg_postinst() {
    local file="${ROOT}etc/backup-cron/backup-cron.conf"
    einfo "Don't forget set root password in BDB_PASSWD parameter at '${file}' script."
}

