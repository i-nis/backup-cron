# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

inherit git-2 user

DESCRIPTION="Config file and utilities for backup-cron scripts."
HOMEPAGE="https://proyectos.ingeniovirtual.com.ar/projects/backup-cron"
SRC_URI=""
EGIT_REPO_URI="https://proyectos.ingeniovirtual.com.ar/backup.git"
EGIT_COMMIT="v${PV}"
IUSE="logcheck"
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="amd64 x86"
DEPEND="sys-apps/findutils
        sys-block/mbuffer
        logcheck? ( app-admin/logcheck )"

src_unpack() {
    git-2_src_unpack
}

pkg_setup() {
    # Add backup user and group, then check perms (issue #1)
    einfo "Checking for admin group..."
    enewgroup admin
    einfo "Checking for admin user..."
    enewuser admin -1 /bin/rbash /home/admin admin
    einfo "Setting permissions for /home/admin directory."
    fperms 0770 /home/admin
}

src_install() {
    dodir /etc/backup-cron
    dodir /usr/libexec/backup-cron
    cp -pR ${WORKDIR}/${P}/etc/backup-cron/backup-cron.conf ${D}/etc/backup-cron
    cp -pR ${WORKDIR}/${P}/etc/backup-cron/exclude.txt ${D}/etc/backup-cron
    cp -pR ${WORKDIR}/${P}/usr/libexec/backup-cron/backup-cron_functions.sh ${D}/usr/libexec/backup-cron/

    if use logcheck ; then
      dodir /etc/logcheck/ignore.d.server
      cp -pR ${WORKDIR}/${P}/etc/logcheck/ignore.d.server/backup-cron ${D}/etc/logcheck/ignore.d.server
    fi

    einfo "Setting permissions for files in /etc/backup-cron."
    fperms 600 /etc/backup-cron/backup-cron.conf
    fperms 600 /etc/backup-cron/exclude.txt
}

