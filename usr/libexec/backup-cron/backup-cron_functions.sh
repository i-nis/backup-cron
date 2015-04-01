#!/bin/bash
#
# backup-cron_functions.sh: funciones comunes para los script de copias de
# seguridad.
#
# (C) 2012 - 2014 Ingenio Virtual
# (C) 2006 - 2011 Martin Andres Gomez Gimenez <mggimenez@ingeniovirtual.com.ar>
# Distributed under the terms of the GNU General Public License v3
#



# Función para enviar mensajes vía syslog. Utiliza la interfaz de comando
# denominada logger. Para más detalles vea: man logger.
# NAME: nombre del programa que invoca.
# MESSAGE: mensaje a enviar vía syslog.
#
message_syslog () {
  local NAME="${1}"
  local MESSAGE="${2}"
  local HOST=$(/bin/hostname -s)
  local LOGGER="/usr/bin/logger"
  ${LOGGER} --id ${NAME} ${MESSAGE} --stderr &>> /tmp/${NAME}-${HOST}.txt
}



# Función para enviar mensajes vía correo electrónico.
# NAME: nombre del programa que invoca.
# MESSAGE: mensaje a enviar.
# RECIPIENTS: destinatarios de correo electrónico.
#
send_mail () {
  local NAME="${1}"
  local SUBJECT="${2}"
  local RECIPIENTS="${3}"
  local HOST="$(/bin/hostname -s)"
  cat /tmp/${NAME}-${HOST}.txt | mail -s "${SUBJECT}" "${RECIPIENTS}"
  rm -f /tmp/${NAME}-${HOST}.txt
}




# Función para verificar la existencia de un directorio. Si este no existe es
# creado.
# NAME: nombre del programa que invoca.
# DIRECTORY: ruta del directorio a verificar.
#
directory_mkdir() {
  local NAME="${1}"
  local DIRECTORY="${2}"
  local MKDIR="/bin/mkdir"
  local CHOWN="/bin/chown"

  if [ ! -e ${DIRECTORY} ]; then
    ${MKDIR} --parents --mode=755 ${DIRECTORY}
    ${CHOWN} admin:admin ${DIRECTORY}
    message_syslog "${NAME}" "El directorio ${DIRECTORY} fue creado."
  fi

}




# Función para cambiar los permisos de un archivo.
# NAME: nombre del programa que invoca.
# FILE: ruta al archivo al cual deben cambiarse los permisos.
#
file_perms() {
  local NAME="${1}"
  local FILE="${2}"
  local CHMOD="/bin/chmod"
  local CHOWN="/bin/chown"

  ${CHOWN} admin:admin ${FILE}
  ${CHMOD} 640 ${FILE}
}



# Función para el volcado de bases de datos en SQL en disco.
# NAME: nombre del programa que invoca.
# OPTIONS: opciones para mysqldump, para mas detalles vea "man mysqldump".
# BACKUP_PATH: ruta a la ubicación de la copia de respaldo.
#
dump_mysql() {
  local NAME="${1}"
  local OPTIONS="${2}"
  local BACKUP_PATH="${3}"
  local FIND="/usr/bin/find"
  local MYSQLDUMP="/usr/bin/mysqldump"
  local MYSQL_PATH="/var/lib/mysql"

  if [ -d ${MYSQL_PATH} ]; then
    cd ${MYSQL_PATH}

    for database in $(${FIND} * -maxdepth 0 -type d); do
      ${MYSQLDUMP} ${OPTIONS} ${database} > ${BACKUP_PATH}/${database}.sql
      file_perms "${NAME}" "${BACKUP_PATH}/${database}.sql"
      message_syslog "${NAME}" "La base de datos ${database} fue extraida."
    done

  fi

}



# Función para el volcado de bases de datos en SQL en disco o en cinta DAT.
# NAME: nombre del programa que invoca.
# OPTIONS: opciones para mysqldump, para mas detalles vea "man mysqldump".
# BACKUP_PATH: ruta a la ubicación de la copia de respaldo.
#
dump_pg() {
  local NAME="${1}"
  local BDB_PG_USER="${2}"
  local BDB_PG_PASSWD="${3}"
  local BDB_PG_BACKUP_PATH="${4}"
  local PG_DUMP="/usr/bin/pg_dump"

  export PGPASSWORD=${BDB_PG_PASSWD}

  DATABASES=$(psql -t -l --username=${BDB_PG_USER} | awk -F \| /^.*/'{print $1}')

  for database in ${DATABASES}; do
    $PG_DUMP --username=${BDB_PG_USER} --create ${database} > ${BDB_PG_BACKUP_PATH}/${database}.sql
    file_perms "${NAME}" "${BDB_PG_BACKUP_PATH}/${database}.sql"
    message_syslog "${NAME}" "La base de datos ${database} fue extraida."
  done

}



# Función para respaldar las imágenes qcow2 de las máquinas virtuales
# administradas con app-emulation/libvirt.
#
libvirt_backup() {
  local NAME="${1}"
  local BLIBVIRT_BACKUP_PATH="${2}"
  local LIBVIRT_PATH="/var/lib/libvirt/images"
  local FECHA="$(/bin/date +%G%m%d)"
  local IMAGES=$(ls -1 ${LIBVIRT_PATH} | awk -F \.img /img/'{print $1}')

  for image in ${IMAGES}; do

  SNAPSHOT="${image}-${FECHA}"
  IMAGE="${LIBVIRT_PATH}/${image}.img"
  IMAGE_BACKUP="${BLIBVIRT_BACKUP_PATH}/${image}-${FECHA}.img"

  # Creación de imagen de respaldo basada en un snapshot temporal.
  qemu-img snapshot -c ${SNAPSHOT} ${IMAGE}
  qemu-img convert -c -f qcow2 -O qcow2 -s ${SNAPSHOT} ${IMAGE} ${IMAGE_BACKUP}
  qemu-img snapshot -d ${SNAPSHOT} ${IMAGE}

  file_perms "${NAME}" "${IMAGE_BACKUP}"

  # Generación de sumas MD5, SHA1, SHA256, etc.
  gensum "${NAME}" "${IMAGE_BACKUP}"

done
}



# Función para respaldar /home.
# NAME: nombre del programa que invoca.
# HOME_PATH: ruta al directorio /home
# BACKUP_PATH: ruta al directorio donde se ubicará la copia de respaldo.
home_backup() {
  local NAME="${1}"
  local HOME_PATH="${2}"
  local BACKUP_PATH="${3}"
  local directory=""
  local FIND="/usr/bin/find"
  local HOST="$(/bin/hostname -s)"
  local FECHA="$(/bin/date +%G%m%d)"
  local FILE="backup-$HOST"

  cd ${HOME_PATH}

  for directory in $(${FIND} * -maxdepth 0 -type d); do
    DIRECTORY_BACKUP="${BHOME_BACKUP_PATH}/${FILE}-${directory}-${FECHA}.tar.bz2"

    file_backup "${NAME}" "${DIRECTORY_BACKUP}" "${directory} --exclude=backup/*/*" "disk"
  done

}



# Función para respaldar otros directorios.
# NAME: nombre del programa que invoca.
# BACKUP_FILE: archivo de respaldo a crear.
# DIRS: directorios o archivos a respaldar.
# MODE: modo de respaldo: [disk | tape]
file_backup() {
  local NAME="${1}"
  local BACKUP="${2}"
  local DIRS="${3}"
  local MODE="${4}"
  local TAR="/bin/tar"
  local TAR_OPTS=""
  local EXCLUDE="/etc/backup-cron/exclude.txt"
  local MBUFFER="/usr/bin/mbuffer -t -m 128M -p 90 -s 65536 -f -o"

  case ${MODE} in
    disk )
      TAR_OPTS="--create --bzip2 --preserve-permissions --file"
      ${TAR} ${TAR_OPTS} ${BACKUP} ${DIRS} --exclude-from=${EXCLUDE} &>/dev/null
      file_perms "${NAME}" "${BACKUP}"
      gensum "${NAME}" "${BACKUP}"
      message_syslog "${NAME}" "El archivo de respaldo ${BACKUP} fue creado."
      ;;
    tape )
      TAR_OPTS="--create --blocking-factor=64 --preserve-permissions"
      ${TAR} ${TAR_OPTS} ${DIRS} --exclude-from=${EXCLUDE} | ${MBUFFER} ${BACKUP} &>/dev/null
      message_syslog "${NAME}" "El directorio ${DIRS} fue respaldado en ${BACKUP}."
      ;;
    esac

}



# Función para generar sumas MD5, SHA1, SHA256, etc.
# NAME: nombre del programa que invoca.
# FILE: archivo desde el cual se creará la suma.
# DIRECTORY: directorio en el que se encuentran los respaldos.
# HASHES: algoritmos para verificar sumas.
gensum() {
  local NAME="${1}"
  local FILE=$(echo "${2}" | awk -F \/ //'{print $(NF)}')
  local DIRECTORY=$(echo "${2}" | awk -F \/${FILE} //'{print $1}')
  local HASHES="md5 sha1 sha256"

  cd ${DIRECTORY}

  for hash in ${HASHES}; do
    PROGRAM="${hash}sum"
    CHECKSUM=$(${PROGRAM} ${FILE})
    echo "${CHECKSUM}" >> ${FILE}.${hash}
    file_perms "${NAME}" "${FILE}.${hash}"
    message_syslog "${NAME}" "La suma ${hash} fue creada: ${CHECKSUM}."
  done

}



# Función para borrar copias de respaldo antigüas.
# NAME: nombre del programa que invoca.
# TIME: tiempo de modificación utilizado para borrar archivos.
# TMPCLEAN: variable definida por TMPWATCH en el archivo de configuración.
# PATH: ruta al direcotorio donde se encuentran los archivos antigüos a borrar.
clean_old_backups() {
  local NAME="${1}"
  local TMPCLEAN="${2}"
  local TIME="${3}"
  local PATH="${4}"

  if [[ -d ${PATH} ]]; then
    ${TMPCLEAN} --mtime ${TIME} ${PATH}
    message_syslog "${NAME}" "Las copias con antigüedad mayor a ${TIME} hs fueron borradas."
  fi

}



# Función para copiar archivos de respaldo en servidores remotos.
# NAME: nombre del programa que invoca.
# IP: URL o dirección IP del servidor remoto.
# USER: usuario para conectarse con el servidor remoto.
# PATH: ruta al directorio donde se ubican las copias de respaldo a transferir.
remote_backup() {
  local NAME="${1}"
  local IP="${2}"
  local USER="${3}"
  local PATH="${4}"
  local FECHA="$(/bin/date +%G%m%d)"
  local FIND="/usr/bin/find"
  local SCP="/usr/bin/scp"

  if [ "${REMOTE_IP}" != "" ]; then

    for file in $(${FIND} ${PATH}/*-${FECHA}.* -maxdepth 0 -type f); do
      ${SCP} ${file} ${USER}@${IP}:${PATH}

      if [  ${?} -eq 0 ]; then
          message_syslog "${NAME}" "El archivo ${file} fue copiado al servidor ${IP}."
        else
          message_syslog "${NAME}" "El archivo ${file} no pudo ser copiado al servidor ${IP}."
      fi

    done

  fi

}
