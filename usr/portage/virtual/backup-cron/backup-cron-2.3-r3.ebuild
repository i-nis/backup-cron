# (C) 2012 - 2014 Ingenio Virtual
# (C) 2006 - 2011 Martin Andres Gomez Gimenez <mggimenez@ingeniovirtual.com.ar>
# Distributed under the terms of the GNU General Public License v3
#

inherit git-2 user

DESCRIPTION="Config file for backup-cron scripts."
HOMEPAGE="https://proyectos.ingeniovirtual.com.ar/projects/backup-cron"
SRC_URI=""
IUSE=""
LICENSE="GPL v3"
SLOT="0"
KEYWORDS="amd64 x86"
DEPEND="sys-block/mbuffer"

src_unpack() {
    EGIT_REPO_URI="https://proyectos.ingeniovirtual.com.ar/backup.git"
    git-2_src_unpack
}

pkg_setup() {
    # Add backup user and group, then check perms (issue #1)
    einfo "Checking for admin group..."
    enewgroup admin
    einfo "Checking for admin user..."
    enewuser admin -1 /bin/rbash /home/admin admin
    einfo "Setting permissions for /home/admin directory."
    fperms 660 /home/admin
}

src_install() {
    dodir /etc/backup-cron
    dodir /usr/libexec/backup-cron
    cp -pR ${WORKDIR}/${P}/etc/backup-cron/backup-cron.conf ${D}/etc/backup-cron
    cp -pR ${WORKDIR}/${P}/etc/backup-cron/exclude.txt ${D}/etc/backup-cron
    cp -pR ${WORKDIR}/${P}/usr/libexec/backup-cron/backup-cron_functions.sh ${D}/usr/libexec/backup-cron/
    einfo "Setting permissions for files in /etc/backup-cron."
    fperms 600 /etc/backup-cron/backup-cron.conf
    fperms 600 /etc/backup-cron/exclude.txt
}
