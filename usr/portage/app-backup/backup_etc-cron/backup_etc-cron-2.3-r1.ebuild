# (C) 2012 - 2014 Ingenio Virtual
# (C) 2006 - 2011 Martin Andres Gomez Gimenez <mggimenez@ingeniovirtual.com.ar>
# Distributed under the terms of the GNU General Public License v3
#

inherit git-2

DESCRIPTION="Backup for system configuration files in /etc."
HOMEPAGE="https://proyectos.i-nis.com.ar/projects/backup-cron"
SRC_URI=""
IUSE=""
LICENSE="GPL v3"
SLOT="0"
KEYWORDS="amd64 x86"
DEPEND="app-admin/tmpwatch sys-process/vixie-cron >=virtual/backup-cron-2.3"

src_unpack() {
    EGIT_REPO_URI="https://proyectos.ingeniovirtual.com.ar/backup.git"
    git-2_src_unpack
}

src_install() {
	dodir /etc/cron.daily
	cp -pR ${WORKDIR}/${P}/etc/cron.daily/backup_etc.cron ${D}/etc/cron.daily
	fperms 700 /etc/cron.daily/backup_etc.cron
}
