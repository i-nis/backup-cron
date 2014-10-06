# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

inherit git-2

DESCRIPTION="Clear utility for old backups from remote hosts."
HOMEPAGE="https://proyectos.ingeniovirtual.com.ar/projects/backup-cron"
SRC_URI=""
EGIT_REPO_URI="https://proyectos.ingeniovirtual.com.ar/backup.git"
EGIT_COMMIT="v${PV}"
IUSE=""
LICENSE="GPL v3"
SLOT="0"
KEYWORDS="amd64 x86"
DEPEND="app-admin/tmpwatch sys-process/vixie-cron >=virtual/backup-cron-2.4"

src_unpack() {
    git-2_src_unpack
}

src_install() {
	dodir /etc/cron.daily
	cp -pR ${WORKDIR}/${P}/etc/cron.daily/clean_*.cron ${D}/etc/cron.daily
        fperms 700 /etc/cron.daily/clean_*.cron
}

pkg_postinst() {
  local file="${ROOT}etc/backup-cron/backup-cron.conf"
  einfo "Do not forget to set the list of remote hosts in HOSTS parameter at '${file}' script."
}

