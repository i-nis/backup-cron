#!/bin/bash
#
# backup-cron_functions.sh: funciones comunes para los script de copias de
# seguridad.
#
# (C) 2006 - 2021 NIS
# Autor: Martin Andres Gomez Gimenez <mggimenez@nis.com.ar>
# Distributed under the terms of the GNU General Public License v3
#



source /etc/backup-cron/backup-cron.conf



# Función para enviar mensajes vía syslog. Utiliza la interfaz de comando
# denominada logger. Para más detalles vea: man logger.
# NAME: nombre del programa que invoca.
# MESSAGE: mensaje a enviar vía syslog.
#
message_syslog () {
  local MESSAGE="${1}"
  local NAME=$(basename $0)

  /usr/bin/logger --id=$$ --stderr "${NAME}: ${MESSAGE}" &>> /tmp/${NAME}-${HOST}.txt
}



# Función para enviar mensajes vía correo electrónico.
# NAME: nombre del programa que invoca.
# MESSAGE: mensaje a enviar.
# RECIPIENTS: destinatarios de correo electrónico.
#
send_mail () {
  local SUBJECT="${1}"
  local NAME=$(basename $0)

  cut --delimiter='>' --fields=2 /tmp/${NAME}-${HOST}.txt | \
  mail --subject="${SUBJECT} ${NAME}" "${RECIPIENTS}"

  rm -f /tmp/${NAME}-${HOST}.txt
}



# Función para verificar la existencia de un directorio. Si este no existe es
# creado.
# DIRECTORY: ruta del directorio a verificar.
#
directory_mkdir() {
  local DIRECTORY="${1}"

  if [ ! -e ${DIRECTORY} ]; then
    mkdir --parents --mode=755 ${DIRECTORY}
    chown admin:admin ${DIRECTORY}
    message_syslog "El directorio ${DIRECTORY} fue creado."
  fi

}



# Función para cambiar los permisos de un archivo.
# FILE: ruta al archivo al cual deben cambiarse los permisos.
#
file_perms() {
  local FILE="${1}"

  chown admin:admin ${FILE}
  chmod 640 ${FILE}
  message_syslog "Modificado dueño y permisos para ${FILE}."
}



# Función para listar las bases de datos MySQL a respaldar.
# USER: usuario con privilegios de administrador para el motor MySQL.
# PASSWD: contraseña del usuario administrador.
# HOST: servidor o dirección de IP del motor de bases de datos.
show_databases_mysql() {
  local USER="${1}"
  local PASSWD="${2}"
  local HOST="${3}"
  local EXCLUDE="lost\+found|performance_schema|information_schema"
  local OPTIONS="--batch --skip-pager --skip-column-names --raw"
  local DATABASES=""

  DATABASES=$(mysql ${OPTIONS} --execute='SHOW DATABASES;' --user=${USER} \
  --password=${PASSWD} --host=${HOST} | egrep -v ${EXCLUDE})

  echo "${DATABASES}"
}



# Función para listar las bases de datos PostgreSQL a respaldar.
# USER: usuario con privilegios de administrador para el motor PosgreSQL.
# PASSWD: contraseña del usuario administrador.
# HOST: servidor o dirección de IP del motor de bases de datos.
show_databases_pg() {
  local USER="${1}"
  local PASSWD="${2}"
  local HOST="${3}"
  local EXCLUDE="template0|template1"
  local OPTIONS="--tuples-only --list"
  local DATABASES=""

  export PGPASSWORD=${PASSWD}

  DATABASES=$(psql ${OPTIONS} --username=${USER} --host=${HOST} \
  | awk -F \| /^.*/'{print $1}' | egrep -v ${EXCLUDE} | tr -d ' ' \
  | sed '/^$/d' | sed '/^$/d')

  echo "${DATABASES}"
}



# Función para verificar la realización de respaldos de bases de datos.
# DATABASE: ruta completa a la base de datos a verificar.
#
database_verify() {
  local DATABASE="${1}"

  if [ "$(wc -c < ${DATABASE})" == "0" ]; then
      rm -f ${DATABASE}
      message_syslog "El archivo ${DATABASE} estaba vacío."
    else
      file_perms "${DATABASE}"
      message_syslog "Se ha creado correctamente ${DATABASE}."
  fi

  if [ "$(wc -c < ${DATABASE}.error)" == "0" ]; then
    rm -f ${DATABASE}.error
    message_syslog "No se detectaron errores en ${DATABASE}."
  fi

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

  case ${ACTION} in
    create )
      # Se crea la instantánea como archivo separado y este pasa a ser la imagen.
      /usr/bin/virsh snapshot-create-as ${DOMAIN} ${SNAPSHOT} --disk-only --atomic --quiesce
      message_syslog "Se ha creado la instantánea ${SNAPSHOT}."
      ;;
    delete )
      IMAGE_PATH=$(image_path "${DOMAIN}" "${DISK}")
      # Se envían los cambios desde la instantánea a la imagen principal y luego
      # se realiza el cambio a esta última.
      /usr/bin/virsh blockcommit ${DOMAIN} ${DISK} --active --pivot

      # Se elimina el archivo creado por la instantánea.
      SNAPSHOT_FILE=$(echo "${IMAGE_PATH}" | grep ${SNAPSHOT})
      rm -f ${SNAPSHOT_FILE}
      message_syslog "Se ha eliminado la instantánea ${SNAPSHOT_FILE}."
      ;;
  esac

}



# Función para crear un respaldo en formato qcow2 comprimido de una imágen de 
# disco en cualquiera de los siguientes formatos: raw,bochs,qcow,qcow2,qed,vmdk.
# DOMAIN: nombre de la maquina virtual.
# BACKUP_FILE: archivo de respaldo a crear.
#
qcow2_backup() {
  local IMAGE="${1}"
  local BACKUP_FILE="${2}"

  /usr/bin/qemu-img convert --force-share -c -O qcow2 ${IMAGE} ${BACKUP_FILE}
  message_syslog "El archivo de respaldo ${BACKUP_FILE} fue creado."
}



# Función para buscar y respaldar las imágenes de disco de las máquinas virtuales.
# administradas con app-emulation/libvirt.
# BLIBVIRT_BACKUP_PATH: ruta a la ubicación de la copia de respaldo.
#
libvirt_backup() {
  local BLIBVIRT_BACKUP_PATH="${1}"
  local DOMAINS=$(virsh list --name)

  for domain in ${DOMAINS}; do
    # Búsqueda de imágenes de discos utilizados por cada dominio (maquina virtual).
    IMAGES=$(/usr/bin/virsh domblklist ${domain} | awk -F \  /^[sv]d*/'{print $2}')
    message_syslog "Comenzando el respaldo para el dominio ${domain}."

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
      qcow2_backup "${image}" "${BACKUP_FILE}"

      # Borrado de la instantánea correspondiente al disco actual.
      snapshot "delete" "${domain}" "${DISK}" "${SNAPSHOT}"

      # Cambio de permisos para el respaldo.
      file_perms "${BACKUP_FILE}"

      # Generación de sumas MD5, SHA1, SHA256, etc.
      gensum "${BACKUP_FILE}"
    done

    # Se eliminan los metadatos de la instantánea.
    /usr/bin/virsh snapshot-delete ${domain} ${SNAPSHOT} --metadata

  done
}


# Función para realizar respaldos en disco mediante GNU Tar.
# BACKUP: archivo de respaldo a crear.
# DIRS: directorios o archivos a respaldar.
# EXCLUDE: ruta al archivo que especifica los patrones a excluir por GNU Tar.
#
file_backup() {
  local BACKUP="${1}"
  local FILES="${2}"
  local EXCLUDE="/etc/backup-cron/exclude.txt"

  tar --create --bzip2 --preserve-permissions --file ${BACKUP} \
  --exclude-from=${EXCLUDE} ${FILES} &>/dev/null

  # Se verifica que GNU Tar se haya ejecutado correctamente.
  if [ $? -eq 0 ]; then
      tar_not_empty "${BACKUP}"
      file_encrypt "${BACKUP}"
    else
      message_syslog "Error al crear el respaldo ${BACKUP}."
      exit 1
  fi

}



# Función para realizar respaldos incrementales en disco mediante GNU Tar.
# BACKUP: archivo de respaldo a crear.
# DIRS: directorios a respaldar.
# EXCLUDE: ruta al archivo que especifica los patrones a excluir por GNU Tar.
# SNAR: archivo de control para cambios incrementales.
#
file_backup_incremental() {
  local BACKUP="${1}"
  local DIRS="${2}"
  local DAYOFMONTH=$(date +%d)
  local EXCLUDE="/etc/backup-cron/exclude.txt"
  local LEVEL=""
  local SNAR="${BACKUP}.snar"

  if [ "${DAYOFMONTH}" -eq 01 ] || [ ! -e "${SNAR}" ]; then
      LEVEL="0"
      BACKUP="${BACKUP}-full-${FECHA}.tar.bz2"
    else
      LEVEL="1"
      BACKUP="${BACKUP}-incremental-${FECHA}.tar.bz2"
  fi

  tar --create --bzip2 --preserve-permissions --file ${BACKUP} \
  --listed-incremental=${SNAR} --level=${LEVEL} \
  --exclude-from=${EXCLUDE} ${DIRS} &>/dev/null

  # Se verifica que GNU Tar se haya ejecutado correctamente.
  if [ $? -eq 0 ] ; then
      tar_not_empty "${BACKUP}"
      file_encrypt "${BACKUP}"
    else
      message_syslog "Error al crear el respaldo ${BACKUP}."
      exit 1
  fi

}



# Función para rerealizar respaldos en cinta.
# DIRS: directorios o archivos a respaldar.
# TAPE: dispositivo de cintas a utilizar definido en /etc/backup-cron/backup-cron.conf.
#
tape_backup() {
  local DIRS="${1}"
  local TAR_OPTS="--create --blocking-factor=64 --preserve-permissions"
  local EXCLUDE="/etc/backup-cron/exclude.txt"
  local MBUFFER_OPTS="-t -m 128M -p 90 -s 65536 -f -o"

  tar ${TAR_OPTS} --exclude-from=${EXCLUDE} ${DIRS} | mbuffer ${MBUFFER_OPTS} ${TAPE} &>/dev/null
  message_syslog "El directorio ${DIRS} fue respaldado en ${TAPE}."
}



# Función para determinar si un archivo de respaldo contiene archivos.
# En caso de estar vacío, es eliminado y aborta la ejecución del programa.
#
tar_not_empty() {
  local FILE="${1}"
  local TEST=$(tar --list --file ${FILE} | head -n 1 | wc -l)

  if [ "${TEST}" == "0" ]; then
      message_syslog "Archivo de respaldo ${FILE} sin datos, se procede a eliminarlo."
      rm -f ${FILE}
      exit 1
    else
      message_syslog "Se ha creado el archivo de respaldo ${FILE}."
  fi

}



# Función para generar sumas MD5, SHA1, SHA256, etc.
# FILE: archivo desde el cual se creará la suma.
# DIRECTORY: directorio en el que se encuentran los respaldos.
# HASHES: algoritmos para verificar sumas.
#
gensum() {
  local FILE=$(echo "${1}" | awk -F \/ //'{print $(NF)}')
  local DIRECTORY=$(echo "${1}" | awk -F \/${FILE} //'{print $1}')
  local HASHES="md5 sha1 sha256"

  cd ${DIRECTORY}

  for hash in ${HASHES}; do
    PROGRAM="${hash}sum"
    CHECKSUM=$(${PROGRAM} ${FILE})
    echo "${CHECKSUM}" > ${FILE}.${hash}
    file_perms "${FILE}.${hash}"
    message_syslog "La suma ${hash} fue creada: ${CHECKSUM}."
  done

}



# Función para encriptar archivos mediante GNUPG.
# FILE: archivo a encriptar mediante GNUPG.
#
file_encrypt() {
  local FILE="${1}"

  if [ "${PGP_ID}" != "" ]; then
      gpg --encrypt --recipient ${PGP_ID} --compress-algo none --output ${FILE}.gpg ${FILE}

      # Se verifica que GNUPG haya encriptado correctamente.
      if [ $? -eq 0 ]; then
          rm -f ${FILE}
          message_syslog "Se ha encriptado el archivo de respaldo ${BACKUP} como ${BACKUP}.gpg."
          file_perms "${BACKUP}.gpg"
          gensum "${BACKUP}.gpg"
        else
          message_syslog "Error al encriptar mediante GNUPG el respaldo ${BACKUP}."
          exit 1
      fi

    else
      message_syslog "Se ha creado archivo de respaldo ${BACKUP}."
      file_perms "${BACKUP}"
      gensum "${BACKUP}"
  fi

}



# Función para remover respaldos incrementales obsoletos.
# DIRECTORY: ruta al directorio donde deben removerse los respaldos obsoletos.
# ERASE_DATE: cálculo del año y mes de los archivos que deben ser eliminados
# basados en la constante KEEP_INCREMENTAL definida en /etc/backup/backup-cron.conf.
# ERASE_FILES: listado obtenido de archivos a eliminar
#
remove_incremental_backup() {
  local DIRECTORY="${1}"
  local ERASE_DATE=$(date --date="${KEEP_INCREMENTAL} month ago" +%Y%m)
  local ERASE_FILES=""

  cd ${DIRECTORY}
  ERASE_FILES=$(ls -1 *${ERASE_DATE}*.tar.bz2* 2>/dev/null)

  for file in ${ERASE_FILES}; do
    rm -f ${file} &>/dev/null
    message_syslog "Se eliminó el archivo obsoleto ${file}."
  done

}



# Función para borrar copias de respaldo antigüas.
# TIME: tiempo de modificación utilizado para borrar archivos.
# TMPCLEAN: variable definida por TMPWATCH en el archivo de configuración.
# PATH: ruta al directorio donde se encuentran los archivos antigüos a borrar.
#
# TODO: find . -name "" -mtime + | xargs echo
#
clean_old_backups() {
  local TMPCLEAN="${1}"
  local TIME="${2}"
  local PATH="${3}"

  if [[ -d ${PATH} ]]; then
    ${TMPCLEAN} --mtime ${TIME} ${PATH}
    message_syslog "Las copias con antigüedad mayor a ${TIME} hs en ${PATH} fueron borradas."
  fi

}



# Función para copiar archivos de respaldo en servidores remotos.
# IP: URL o dirección IP del servidor remoto.
# USER: usuario para conectarse con el servidor remoto.
# PATH: ruta al directorio donde se ubican las copias de respaldo a transferir.
#
remote_backup() {
  local REMOTE_IP="${1}"
  local USER="${2}"
  local PATH="${3}"

  if [ "${REMOTE_IP}" != "" ]; then

    for ip in ${REMOTE_IP}; do

      for file in $(/usr/bin/find ${PATH}/*-${FECHA}.* -maxdepth 0 -type f); do
        /usr/bin/scp ${file} ${USER}@${ip}:${PATH} &>/dev/null

        if [  ${?} -eq 0 ]; then
            message_syslog "El archivo ${file} fue copiado al servidor ${ip}."
          else
            message_syslog "El archivo ${file} no pudo ser copiado al servidor ${ip}."
        fi

      done

    done
  fi

}



#-------------------------------------------------------------------------------
# Funciones para restaurar datos
#-------------------------------------------------------------------------------



# Dada una ruta a un respaldo, verifica que exista en el sistema de archivo.
# Devuelve verdadero en caso de existir
# FILE: nombre del archivo a verificar.
#
backup_file_exists() {
  local FILE="${1}"

  if [ -e "${FILE}" ]; then
      true
    else
      false
  fi

}



# Función para alertar al usuario que el archivo pasado como parámetro no existe.
# Ejemplo al invocar el scrit /usr/sbin/mysql_restore.
# FILE: archivo evaluado
#
file_no_exist() {
  local FILE="${1}"

  warning "ERROR" "El archivo ${FILE} no existe."
  echo ""
  exit 1
}



# Función para alertar en el pasaje de parámetro la ruta al archivo de respaldo.
# Ejemplo al invocar el scrit /usr/sbin/mysql_restore.
#
no_file() {
  warning "ERROR" "No se especificó ningun archivo .tar.bz2 o .tar.bz2.gpg. Vea:."
  echo " $(basename ${0}) --help"
  echo ""
  exit 1
}



# Función para seleccionar al azar un algoritmo de suma para comprobación.
#
ramdom_select_sum() {
  local NUM="$((1 + RANDOM % 3))"

  case ${NUM} in
    1 )
      SUM="md5sum"
      DIGEST="MD5"
      EXT="md5"
      ;;
    2 )
      SUM="sha1sum"
      DIGEST="SHA1"
      EXT="sha1"
      ;;
    3 )
      SUM="sha256sum"
      DIGEST="SHA256"
      EXT="sha256"
      ;;
  esac

}



# Verifica que exista el conjunto completo de respaldo, incluyendo todos los 
# archivos de suma
#
verify_set() {
  local FILE="${1}"
  local BACKUP_SET="md5 sha1 sha256"
  local set=""

  for set in ${BACKUP_SET}; do

    if [ ! -e "${FILE}.${set}" ]; then
      file_no_exist "${FILE}.${set}."
    fi

  done
}



# Función para desencriptar archivos mediante GNUPG. Devuelve la ruta al archivo
# desencriptado.
# FILE: archivo a desencritpar.
# DECRIPT_FILE: archivo desencriptado.
#
file_decrypt() {
  local FILE="${1}"
  local DECRIPT_FILE="$(echo "${FILE}" | awk -F .gpg '{print $(1)}')"

  gpg --decrypt --output ${DECRIPT_FILE} ${FILE}

  if [ $? -eq 0 ]; then
      echo "${DECRIPT_FILE}"
    else
      warning "ERROR:" "No se pudo desencriptar el archivo ${FILE}."
      exit 1
  fi
}



# Función para mostrar secuencia 1..9
nine_seconds ()
{
   for i in 1 2 3 4 5 6 7 8 9; do
     echo -en "\a${i} "
     sleep 1s
   done

   echo
}



# Función para desencriptar y desempaquetar respaldos.
# FILE: archivo a desencritpar.
# DECRIPT_FILE: archivo desencriptado.
function unpack() {
  local FILE="${1}"
  local DIRECTORY="${2}"
  local DECRIPT_FILE=""

  if [ "${PGP_ID}" != "" ]; then
      DECRIPT_FILE=$(file_decrypt "${FILE}")
    else
      DECRIPT_FILE="${FILE}"
  fi

  tar --bzip2 --extract --verbose --preserve-permissions --listed-incremental=/dev/null \
  --file ${DECRIPT_FILE} --directory=${DIRECTORY}

  if [ ! $? -eq 0 ]; then
    warning "ERROR:" "Error al descomprimir y desempaquetar el archivo ${DECRIPT_FILE}."
    exit 1
  fi

}



# Funcion para mostrar advertencias
warning ()
{
  WARNING="\033[40m\033[1;33m${1}\033[0m"
  ADVERTENCE="\033[1;37m${2}\033[0m"
  echo
  echo -e "\a" "${WARNING}"
  echo -e " ${ADVERTENCE}"
  echo
}

