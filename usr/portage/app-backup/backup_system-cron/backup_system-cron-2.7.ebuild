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
DEPEND="app-admin/tmpwatch
	>=sys-process/vixie-cron-2
	>=virtual/backup-cron-2.7"

src_unpack() {
    git-2_src_unpack
}

src_install() {
    dodir /etc/cron.weekly

    # USE conditional blocks...
    if use no-home ; then
		dosbin ${S}/usr/sbin/backup_{raiz,usr,var}.cron

		if [ ! -h /etc/cron.*/backup_raiz.cron ]; then
			dosym /usr/sbin/backup_raiz.cron /etc/cron.weekly/backup_raiz.cron
		fi

        if [ ! -h /etc/cron.*/backup_usr.cron ]; then
            dosym /usr/sbin/backup_usr.cron /etc/cron.weekly/backup_usr.cron
        fi

        if [ ! -h /etc/cron.*/backup_var.cron ]; then
            dosym /usr/sbin/backup_var.cron /etc/cron.weekly/backup_var.cron
        fi

    elif use no-system ; then
    	dosbin ${S}/usr/sbin/backup_home.cron

        if [ ! -h /etc/cron.*/backup_home.cron ]; then
            dosym /usr/sbin/backup_home.cron /etc/cron.weekly/backup_home.cron
        fi

    elif use var-only ; then
        dosbin ${S}/usr/sbin/backup_var.cron

        if [ ! -h /etc/cron.*/backup_var.cron ]; then
            dosym /usr/sbin/backup_var.cron /etc/cron.weekly/backup_var.cron
        fi

    else
    	dosbin ${S}/usr/sbin/backup_{home,raiz,usr,var}.cron

        if [ ! -h /etc/cron.*/backup_home.cron ]; then
            dosym /usr/sbin/backup_home.cron /etc/cron.weekly/backup_home.cron
        fi

        if [ ! -h /etc/cron.*/backup_raiz.cron ]; then
            dosym /usr/sbin/backup_raiz.cron /etc/cron.weekly/backup_raiz.cron
        fi

        if [ ! -h /etc/cron.*/backup_usr.cron ]; then
            dosym /usr/sbin/backup_usr.cron /etc/cron.weekly/backup_usr.cron
        fi

        if [ ! -h /etc/cron.*/backup_var.cron ]; then
            dosym /usr/sbin/backup_var.cron /etc/cron.weekly/backup_var.cron
        fi

    fi

}

