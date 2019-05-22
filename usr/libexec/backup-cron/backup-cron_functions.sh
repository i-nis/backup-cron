#!/bin/bash
#
# backup-cron_functions.sh: funciones comunes para los script de copias de
# seguridad.
#
# (C) 2012 - 2019 Ingenio Virtual
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

  /usr/bin/logger --id=$$ "${NAME}: ${MESSAGE}" --stderr &>> /tmp/${NAME}-${HOST}.txt
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

  if [ ! -e ${DIRECTORY} ]; then
    mkdir --parents --mode=755 ${DIRECTORY}
    chown admin:admin ${DIRECTORY}
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

  chown admin:admin ${FILE}
  chmod 640 ${FILE}
  message_syslog "${NAME}" "Modificado dueño y permisos para ${FILE}."
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
  local MYSQL_PATH="/var/lib/mysql"

  if [ -d ${MYSQL_PATH} ]; then
    cd ${MYSQL_PATH}

    for database in $(/usr/bin/find * -maxdepth 0 -type d | egrep -v 'lost\+found|performance_schema' ); do
      /usr/bin/mysqldump ${OPTIONS} ${database} > ${BACKUP_PATH}/${database}.sql \
      2>${BACKUP_PATH}/${database}_error.txt

      # Comprueba si el respaldo fue correctamente realizado
      if [ "$?" -eq 0 ]; then

          if [ "$(wc -c < ${BACKUP_PATH}/${database}.sql)" == "0" ]; then
             rm -f ${BACKUP_PATH}/${database}.sql
            else
             file_perms "${NAME}" "${BACKUP_PATH}/${database}.sql"
             message_syslog "${NAME}" "La base de datos ${database} fue extraida."
          fi

          if [ "$(wc -c < ${BACKUP_PATH}/${database}_error.txt)" == "0" ]; then
             rm -f ${BACKUP_PATH}/${database}_error.txt
          fi

        else
          message_syslog "${NAME}" "Hubo un error al extraer la base de datos ${database}."
      fi

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
  local BDB_PG_PSQL="/usr/bin/psql -t -l --username=${BDB_PG_USER} --host=${BDB_PG_HOST}"

  export PGPASSWORD=${BDB_PG_PASSWD}

  if [ "${BDB_PG_HOST}" == "" ]; then
    BDB_PG_HOST="$(hostname --long)"
  fi

  DATABASES=$(${BDB_PG_PSQL} | awk -F \| /^.*/'{print $1}' \
              | egrep -v 'template0|template1' | tr -d ' ' | sed '/^$/d' | sed '/^$/d')

  for database in ${DATABASES}; do
    /usr/bin/pg_dump --username=${BDB_PG_USER} --host=${BDB_PG_HOST} --create ${database} \
    > ${BDB_PG_BACKUP_PATH}/${database}.sql 2>${BDB_PG_BACKUP_PATH}/${database}_error.txt

      # Comprueba si el respaldo fue correctamente realizado
      if [ "$?" -eq 0 ]; then

          if [ "$(wc -c < ${BDB_PG_BACKUP_PATH}/${database}.sql)" == "0" ]; then
             rm -f ${BDB_PG_BACKUP_PATH}/${database}.sql
            else
             file_perms "${NAME}" "${BDB_PG_BACKUP_PATH}/${database}.sql"
             message_syslog "${NAME}" "La base de datos ${database} fue extraida."
          fi

          if [ "$(wc -c < ${BDB_PG_BACKUP_PATH}/${database}_error.txt)" == "0" ]; then
             rm -f ${BDB_PG_BACKUP_PATH}/${database}_error.txt
          fi

        else
          message_syslog "${NAME}" "Hubo un error al extraer la base de datos ${database}."
      fi

  done

}



# Función para devolver la ruta a la imagen de disco de una maquina virtual.
# DOMAIN: nombre de la maquina virtual.
# DISK: disco utilizado por la maquina virtual.
#
image_path() {
  local DOMAIN="${1}"
  local DISK="${2}"

  echo "$(/usr/bin/virsh domblklist ${DOMAIN} | awk -F \  /${DISK}/'{print $2}')"
}



# Función para devolver la ruta completa correspondiente a la imagen de disco
# de una maquina virtual.
# DOMAIN: nombre de la maquina virtual.
# IMAGE_NAME: nombre de la imagen de disco utilizado por la maquina virtual.
#
image_disk() {
  local DOMAIN="${1}"
  local IMAGE_PATH="${2}"

  local IMAGE_NAME=$(basename ${IMAGE_PATH})
  echo "$(/usr/bin/virsh domblklist ${DOMAIN} | awk -F \  /${IMAGE_NAME}/'{print $1}')"
}



# Función para administrar instantáneas en las imágenes de disco.
# ACTION: [create | delete]
# DOMAIN: Nombre de la maquina virtual.
# DISK: Nombre del disco correspondiente a la imagen de disco.
# SNAPSHOT: Nombre de la instantánea a crear para la imagen a respaldar. 
#
snapshot() {
  local ACTION="${1}"
  local DOMAIN="${2}"
  local DISK="${3}"
  local SNAPSHOT="${4}"
  local NAME="backup_libvirt.cron"

  case ${ACTION} in
    create )
      # Se crea la instantánea como archivo separado y este pasa a ser la imagen.
      /usr/bin/virsh snapshot-create-as ${DOMAIN} ${SNAPSHOT} --disk-only --atomic --quiesce
      message_syslog "${NAME}" "Se ha creado la instantánea ${SNAPSHOT}."
      ;;
    delete )
      IMAGE_PATH=$(image_path "${DOMAIN}" "${DISK}")
      # Se envían los cambios desde la instantánea a la imagen principal y luego
      # se realiza el cambio a esta última.
      /usr/bin/virsh blockcommit ${DOMAIN} ${DISK} --active --pivot

      # Se elimina el archivo creado por la instantánea.
      SNAPSHOT_FILE=$(echo "${IMAGE_PATH}" | grep ${SNAPSHOT})
      rm -f ${SNAPSHOT_FILE}
      message_syslog "${NAME}" "Se ha eliminado la instantánea ${SNAPSHOT_FILE}."
      ;;
  esac

}



# Función para crear un respaldo en formato qcow2 comprimido de una imágen de 
# disco en cualquiera de los siguientes formatos: raw,bochs,qcow,qcow2,qed,vmdk.
# NAME: nombre del programa que invoca.
# DOMAIN: nombre de la maquina virtual.
# BACKUP_FILE: archivo de respaldo a crear.
#
qcow2_backup() {
  local NAME="${1}"
  local IMAGE="${2}"
  local BACKUP_FILE="${3}"

  /usr/bin/qemu-img convert --force-share -c -O qcow2 ${IMAGE} ${BACKUP_FILE}
  message_syslog "${NAME}" "El archivo de respaldo ${BACKUP_FILE} fue creado."
}



# Función para buscar y respaldar las imágenes de disco de las máquinas virtuales.
# administradas con app-emulation/libvirt.
# NAME: nombre del programa que invoca.
# BLIBVIRT_BACKUP_PATH: ruta a la ubicación de la copia de respaldo.
#
libvirt_backup() {
  local NAME="${1}"
  local BLIBVIRT_BACKUP_PATH="${2}"
  local DOMAINS=$(virsh list --name)
  local FECHA=$(/bin/date +%G%m%d)

  for domain in ${DOMAINS}; do
    # Búsqueda de imágenes de discos utilizados por cada dominio (maquina virtual).
    IMAGES=$(/usr/bin/virsh domblklist ${domain} | awk -F \  /^[sv]d*/'{print $2}')
    message_syslog "${NAME}" "Comenzando el respaldo para el dominio ${domain}."

    # Creación de instantáneas para los discos del dominio.
    SNAPSHOT_TIME=$(/bin/date +%G%m%d%H%M%S)
    SNAPSHOT="snapshot-${SNAPSHOT_TIME}"
    snapshot "create" "${domain}" "null" "${SNAPSHOT}"

    for image in ${IMAGES}; do
      # Busca la extensión de imagen: .img, .qcow, .qcow2, .raw, etc. Para devolver
      # el nombre sin extensión en IMAGE_NAME.
      local EXT=$(echo "${image}" | awk -F \. //'{print $(NF)}')
      IMAGE_NAME=$(basename ${image} .${EXT})

      DISK=$(image_disk "${domain}" "${IMAGE_NAME}.${SNAPSHOT}")
      BACKUP_FILE="${BLIBVIRT_BACKUP_PATH}/${IMAGE_NAME}-${FECHA}.qcow2"

      # Creación del respaldo de la imagen de disco.
      qcow2_backup "${NAME}" "${image}" "${BACKUP_FILE}"

      # Borrado de la instantánea correspondiente al disco actual.
      snapshot "delete" "${domain}" "${DISK}" "${SNAPSHOT}"

      # Cambio de permisos para el respaldo.
      file_perms "${NAME}" "${BACKUP_FILE}"

      # Generación de sumas MD5, SHA1, SHA256, etc.
      gensum "${NAME}" "${BACKUP_FILE}"
    done

    # Se eliminan los metadatos de la instantánea.
    /usr/bin/virsh snapshot-delete ${domain} ${SNAPSHOT} --metadata

  done
}



# Función para respaldar otros directorios.
# NAME: nombre del programa que invoca.
# BACKUP: archivo de respaldo a crear.
# DIRS: directorios o archivos a respaldar.
# MODE: modo de respaldo: [disk | tape]
#
file_backup() {
  local NAME="${1}"
  local BACKUP="${2}"
  local DIRS="${3}"
  local MODE="${4}"
  local TAR_OPTS=""
  local EXCLUDE="/etc/backup-cron/exclude.txt"
  local MBUFFER_OPTS="-t -m 128M -p 90 -s 65536 -f -o"

  case ${MODE} in
    disk )
      TAR_OPTS="--create --bzip2 --preserve-permissions --file"
      tar ${TAR_OPTS} ${BACKUP} --exclude-from=${EXCLUDE} ${DIRS} &>/dev/null
      file_perms "${NAME}" "${BACKUP}"
      gensum "${NAME}" "${BACKUP}"
      message_syslog "${NAME}" "El archivo de respaldo ${BACKUP} fue creado."
      ;;
    tape )
      TAR_OPTS="--create --blocking-factor=64 --preserve-permissions"
      tar ${TAR_OPTS} --exclude-from=${EXCLUDE} ${DIRS} | mbuffer ${MBUFFER_OPTS} ${BACKUP} &>/dev/null
      message_syslog "${NAME}" "El directorio ${DIRS} fue respaldado en ${BACKUP}."
      ;;
    esac

}



# Función para generar sumas MD5, SHA1, SHA256, etc.
# NAME: nombre del programa que invoca.
# FILE: archivo desde el cual se creará la suma.
# DIRECTORY: directorio en el que se encuentran los respaldos.
# HASHES: algoritmos para verificar sumas.
#
gensum() {
  local NAME="${1}"
  local FILE=$(echo "${2}" | awk -F \/ //'{print $(NF)}')
  local DIRECTORY=$(echo "${2}" | awk -F \/${FILE} //'{print $1}')
  local HASHES="md5 sha1 sha256"

  cd ${DIRECTORY}

  for hash in ${HASHES}; do
    PROGRAM="${hash}sum"
    CHECKSUM=$(${PROGRAM} ${FILE})
    echo "${CHECKSUM}" > ${FILE}.${hash}
    file_perms "${NAME}" "${FILE}.${hash}"
    message_syslog "${NAME}" "La suma ${hash} fue creada: ${CHECKSUM}."
  done

}



# Función para borrar copias de respaldo antigüas.
# NAME: nombre del programa que invoca.
# TIME: tiempo de modificación utilizado para borrar archivos.
# TMPCLEAN: variable definida por TMPWATCH en el archivo de configuración.
# PATH: ruta al direcotorio donde se encuentran los archivos antigüos a borrar.
#
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
#
remote_backup() {
  local NAME="${1}"
  local REMOTE_IP="${2}"
  local USER="${3}"
  local PATH="${4}"
  local FECHA="$(/bin/date +%G%m%d)"

  if [ "${REMOTE_IP}" != "" ]; then

    for ip in ${REMOTE_IP}; do

      for file in $(/usr/bin/find ${PATH}/*-${FECHA}.* -maxdepth 0 -type f); do
        /usr/bin/scp ${file} ${USER}@${ip}:${PATH} &>/dev/null

        if [  ${?} -eq 0 ]; then
            message_syslog "${NAME}" "El archivo ${file} fue copiado al servidor ${ip}."
          else
            message_syslog "${NAME}" "El archivo ${file} no pudo ser copiado al servidor ${ip}."
        fi

      done

    done
  fi

}

