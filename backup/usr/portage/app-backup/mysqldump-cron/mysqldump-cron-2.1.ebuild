# C) 2006 - 2011 Martin Andres Gomez Gimenez <mggimenez@i-nis.com.ar>
# Distributed under the terms of the GNU General Public License v3
# $Header$

inherit cvs

DESCRIPTION="Backup for MySQL."
HOMEPAGE="https://proyectos.i-nis.com.ar/projects/backup-cron"
SRC_URI=""
IUSE=""
LICENSE="GPL v3"
SLOT="0"
KEYWORDS="amd64 x86"
DEPEND="app-admin/tmpwatch sys-process/vixie-cron >=virtual/backup-cron-2 virtual/mysql"

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
  cp -pR ${WORKDIR}/${ECVS_MODULE}/mysqldump.cron ${D}/etc/cron.daily
  fperms 700 /etc/cron.daily/mysqldump.cron
}

pkg_postinst() {
  local file="${ROOT}etc/backup-cron/backup-cron.conf"
  einfo "Don't forget set root password in BDB_PASSWD parameter at '${file}' script."
}

