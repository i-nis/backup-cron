# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $


inherit git-2

DESCRIPTION="Backup for all files in the system."
HOMEPAGE="https://proyectos.ingeniovirtual.com.ar/projects/backup-cron"
SRC_URI=""
EGIT_REPO_URI="https://proyectos.ingeniovirtual.com.ar/backup.git"
EGIT_COMMIT="v${PV}"
IUSE="no-home no-system var-only"
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="amd64 x86"
DEPEND="app-admin/tmpwatch >=sys-process/vixie-cron-2 >=virtual/backup-cron-2.4"

src_unpack() {
    git-2_src_unpack
}

src_install() {
    dodir /etc/cron.weekly

    # USE conditional blocks...
    if use no-home ; then
		cp -pR ${S}/etc/cron.weekly/backup_{raiz,usr,var}.cron ${D}/etc/cron.weekly
		fperms 700 /etc/cron.weekly/backup_{raiz,usr,var}.cron
    elif use no-system ; then
    	cp -pR ${S}/etc/cron.weekly/backup_home.cron ${D}/etc/cron.weekly
		fperms 700 /etc/cron.weekly/backup_home.cron
    elif use var-only ; then
        cp -pR ${S}/etc/cron.weekly/backup_var.cron ${D}/etc/cron.weekly
        fperms 700 /etc/cron.weekly/backup_var.cron
    else
    	cp -pR ${S}/etc/cron.weekly/backup_{home,raiz,usr,var}.cron ${D}/etc/cron.weekly
		fperms 700 /etc/cron.weekly/backup_{home,raiz,usr,var}.cron
    fi

}

