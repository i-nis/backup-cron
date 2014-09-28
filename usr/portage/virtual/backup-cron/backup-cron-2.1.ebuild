# C) 2006 - 2011 Martin Andres Gomez Gimenez <mggimenez@i-nis.com.ar>
# Distributed under the terms of the GNU General Public License v3
# $Header$

inherit cvs eutils

DESCRIPTION="Config file for backup-cron scripts."
HOMEPAGE="https://proyectos.i-nis.com.ar/projects/backup-cron"
SRC_URI=""
IUSE=""
LICENSE="GPL v3"
SLOT="0"
KEYWORDS="amd64 x86"
DEPEND="dev-vcs/cvs sys-block/mbuffer"

src_unpack() {
  ECVS_SERVER="cvs.i-nis.com.ar:/home/cvs"
  ECVS_USER="anonymous"
  ECVS_PASS="anonymous"
  ECVS_AUTH="pserver"
  ECVS_MODULE="gnu+linux/servidores/backup"
  ECVS_TOP_DIR="${DISTDIR}/cvs-src/${ECVS_MODULE}"
  cvs_src_unpack
}

pkg_setup() {
  # Add backup user and group, then check perms (issue #1)
  einfo "Checking for admin group..."
  enewgroup admin
  einfo "Checking for admin user..."
  enewuser admin -1 /bin/rbash /home/admin admin
  fperms 660 /home/admin
}

src_install() {
  dodir /etc/backup-cron
  dodir /usr/libexec/backup-cron
  cp -pR ${WORKDIR}/${ECVS_MODULE}/etc/backup-cron/backup-cron.conf ${D}/etc/backup-cron
  cp -pR ${WORKDIR}/${ECVS_MODULE}/etc/backup-cron/exclude.txt ${D}/etc/backup-cron
  cp -pR ${WORKDIR}/${ECVS_MODULE}/usr/libexec/backup-cron/backup-cron_functions.sh ${D}/usr/libexec/backup-cron/
  fperms 600 /etc/backup-cron/backup-cron.conf
  fperms 600 /etc/backup-cron/exclude.txt
}

