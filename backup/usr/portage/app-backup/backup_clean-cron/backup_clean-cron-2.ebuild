# C) 2006 - 2009 Martin Andres Gomez Gimenez <mggimenez@i-nis.com.ar>
# Distributed under the terms of the GNU General Public License v3
# $Header$

inherit cvs

DESCRIPTION="Clear utility for old backups."
HOMEPAGE="https://www.i-nis.com.ar/"
SRC_URI=""
IUSE=""
LICENSE="GPL v3"
SLOT="0"
KEYWORDS="amd64 x86"
DEPEND="app-admin/tmpwatch app-admin/tmpreaper sys-process/vixie-cron virtual/backup-cron"

src_unpack() {
    ECVS_SERVER="cvs.i-nis.com.ar:/home/cvs"
    ECVS_USER="anonymous"
    ECVS_PASS="anonymous"
    ECVS_AUTH="pserver"
    ECVS_MODULE="gnu+linux/servidores/backup/etc/cron.daily"
    ECVS_TOP_DIR="${DISTDIR}/cvs-src/${ECVS_MODULE}"
    cvs_src_unpack
}

src_install() {
	dodir /etc/cron.daily
	cp -pR ${WORKDIR}/${ECVS_MODULE}/clean_backup_*.cron ${D}/etc/cron.daily
	fperms 700 /etc/cron.daily/clean_backup_*.cron
}

