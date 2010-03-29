# C) 2006 - 2010 Martin Andres Gomez Gimenez <mggimenez@i-nis.com.ar>
# Distributed under the terms of the GNU General Public License v3
# $Header$

inherit cvs

DESCRIPTION="Config file for backup-cron scripts."
HOMEPAGE="https://www.i-nis.com.ar/"
SRC_URI=""
IUSE=""
LICENSE="GPL v3"
SLOT="0"
KEYWORDS="amd64 x86"
DEPEND=""

src_unpack() {
  ECVS_SERVER="cvs.i-nis.com.ar:/home/cvs"
  ECVS_USER="anonymous"
  ECVS_PASS="anonymous"
  ECVS_AUTH="pserver"
  ECVS_MODULE="gnu+linux/servidores/backup/etc/backup-cron"
  ECVS_TOP_DIR="${DISTDIR}/cvs-src/${ECVS_MODULE}"
  cvs_src_unpack
}

src_install() {
  dodir /etc/backup-cron
  cp -pR ${WORKDIR}/${ECVS_MODULE}/backup-cron.conf ${D}/etc/backup-cron
  fperms 700 /etc/backup-cron/backup-cron.conf
}

pkg_postinst() {
}

