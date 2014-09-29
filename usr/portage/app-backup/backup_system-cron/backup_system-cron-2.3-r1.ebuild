# (C) 2012 - 2014 Ingenio Virtual
# (C) 2006 - 2011 Martin Andres Gomez Gimenez <mggimenez@ingeniovirtual.com.ar>
# Distributed under the terms of the GNU General Public License v3
#

inherit git-2

DESCRIPTION="Backup for all files in the system."
HOMEPAGE="https://proyectos.ingeniovirtual.com.ar/projects/backup-cron"
SRC_URI=""
IUSE="no-home no-system"
LICENSE="GPL v3"
SLOT="0"
KEYWORDS="amd64 x86"
DEPEND="app-admin/tmpwatch >=sys-process/vixie-cron-2 >=virtual/backup-cron-2.3"

src_unpack() {
    EGIT_REPO_URI="https://proyectos.ingeniovirtual.com.ar/backup.git"
    git-2_src_unpack
}

src_install() {
	dodir /etc/cron.weekly

        # USE conditional blocks...
    	if use no-home ; then
		cp -pR ${WORKDIR}/${P}/etc/cron.weekly/backup_{raiz,usr,var}.cron ${D}/etc/cron.weekly
		fperms 700 /etc/cron.weekly/backup_{raiz,usr,var}.cron
        elif use no-system ; then
        	cp -pR ${WORKDIR}/${P}/etc/cron.weekly/backup_home.cron ${D}/etc/cron.weekly
		fperms 700 /etc/cron.weekly/backup_home.cron
	else
		cp -pR ${WORKDIR}/${P}/etc/cron.weekly/backup_{home,raiz,usr,var}.cron ${D}/etc/cron.weekly
		fperms 700 /etc/cron.weekly/backup_{home,raiz,usr,var}.cron
        fi

}

