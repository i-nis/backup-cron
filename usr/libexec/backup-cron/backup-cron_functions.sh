#!/bin/bash
#
# backup-cron_functions.sh: funciones comunes para los scripts de copias de
# seguridad.
#
# (C) 2006 - 2026 NIS
# Autor: Martin Andres Gomez Gimenez <mggimenez@nis.com.ar>
# Distributed under the terms of the GNU General Public License v3
#



source /etc/backup-cron/backup-cron.conf



# Función para enviar mensajes vía syslog. Utiliza la interfaz de comando
# denominada logger. Para más detalles vea: man logger.
# NAME: nombre del programa que invoca.
# MESSAGE: mensaje a enviar vía syslog.
#
message_syslog() {
  local MESSAGE
  local NAME

  MESSAGE="${1}"
  NAME=$(basename "$0" 2>/dev/null)

  logger --id=$$ --stderr "${NAME}: ${MESSAGE}" &>> /tmp/"${NAME}"-"${HOST}".txt
}



# Función para enviar mensajes vía correo electrónico.
# NAME: nombre del programa que invoca.
# MESSAGE: mensaje a enviar.
# RECIPIENTS: destinatarios de correo electrónico.
#
send_mail() {
  local SUBJECT
  local NAME

  SUBJECT="${1}"
  NAME=$(basename "$0" 2>/dev/null)

  cut --delimiter='>' --fields=2 /tmp/"${NAME}"-"${HOST}".txt | \
  mail -s "${SUBJECT} ${NAME}" "${RECIPIENTS}"

  rm -f /tmp/"${NAME}"-"${HOST}".txt
}



# Función para verificar la existencia de un directorio. Si este no existe es
# creado.
# DIRECTORY: ruta del directorio a verificar.
#
directory_mkdir() {
  local DIRECTORY

  DIRECTORY="${1}"

  if [ ! -e "${DIRECTORY}" ]; then
    mkdir --parents "${DIRECTORY}"
    chmod u=rwx,go=rx  "${DIRECTORY}"
    chown admin:admin "${DIRECTORY}" &>/dev/null
    message_syslog "El directorio ${DIRECTORY} fue creado."
  fi

}



# Función para cambiar los permisos de un archivo.
# FILE: ruta al archivo al cual deben cambiarse los permisos.
#
file_perms() {
  local FILE

  FILE="${1}"

  chown admin:admin "${FILE}" &>/dev/null
  chmod u=rw,g=r,o= "${FILE}" &>/dev/null
  message_syslog "Modificado dueño y permisos para ${FILE}."
}



# Configura el ejecutable MySQL a utilizar.
set_mysql() {
  local MYSQL

  MYSQL=""

  if command -v mariadb >/dev/null 2>&1; then
      MYSQL="mariadb"
    else
      MYSQL="mysql"
  fi

  echo "${MYSQL}"
}



# Configura el ejecutable de mysqldump a utilizar.
set_mysqldump() {
  local MYSQLDUMP

  if  command -v mariadb-dump >/dev/null 2>&1; then
      MYSQLDUMP="mariadb-dump"
    else
      MYSQLDUMP="mysqldump"
  fi

  echo "${MYSQLDUMP}"
}



# Función para listar las bases de datos MySQL a respaldar.
# USER: usuario con privilegios de administrador para el motor MySQL.
# PASSWD: contraseña del usuario administrador.
# HOST: servidor o dirección de IP del motor de bases de datos.
show_databases_mysql() {
  local USER
  local PASSWD
  local HOST
  local EXCLUDE
  local MYSQL
  local DATABASES

  USER="${1}"
  PASSWD="${2}"
  HOST="${3}"
  EXCLUDE="lost\+found|performance_schema|information_schema"
  MYSQL=$(set_mysql)
  DATABASES=""

  DATABASES=$(${MYSQL} --batch --skip-pager --skip-column-names --raw \
              --execute='SHOW DATABASES;' --user="${USER}" --password="${PASSWD}" \
              --host="${HOST}" | grep -v -E ${EXCLUDE})

  echo "${DATABASES}"
}



# Función para listar las bases de datos PostgreSQL a respaldar.
# USER: usuario con privilegios de administrador para el motor PosgreSQL.
# PASSWD: contraseña del usuario administrador.
# HOST: servidor o dirección de IP del motor de bases de datos.
show_databases_pg() {
  local USER
  local PASSWD
  local HOST
  local EXCLUDE
  local DATABASES

  USER="${1}"
  PASSWD="${2}"
  HOST="${3}"
  EXCLUDE="template0|template1"
  DATABASES=""

  export PGPASSWORD=${PASSWD}

  DATABASES=$(psql --tuples-only --list --username="${USER}" --host="${HOST}" \
            | awk -F \| /^.*/'{print $1}' \
            | grep -v -E ${EXCLUDE} | tr -d ' ' \
            | sed '/^$/d' | sed '/^$/d')

  echo "${DATABASES}"
}



# Función para verificar la realización de respaldos de bases de datos.
# DATABASE: ruta completa a la base de datos a verificar.
#
database_verify() {
  local DATABASE

  DATABASE="${1}"

  if [ "$(wc -c < "${DATABASE}")" == "0" ]; then
      rm -f "${DATABASE}"
      message_syslog "El archivo ${DATABASE} estaba vacío."
    else
      file_perms "${DATABASE}"
      message_syslog "Se ha creado correctamente ${DATABASE}."
  fi

  if [ "$(wc -c < "${DATABASE}".error)" == "0" ]; then
    rm -f "${DATABASE}".error
    message_syslog "No se detectaron errores en ${DATABASE}."
  fi

}



# Función para devolver la ruta a la imagen de disco de una maquina virtual.
# DOMAIN: nombre de la maquina virtual.
# DISK: disco utilizado por la maquina virtual.
#
image_path() {
  local DOMAIN
  local DISK

  DOMAIN="${1}"
  DISK="${2}"

  virsh domblklist "${DOMAIN}" | awk -F \  /"${DISK}"/'{print $2}'
}



# Función para devolver la ruta completa correspondiente a la imagen de disco
# de una maquina virtual.
# DOMAIN: nombre de la maquina virtual.
# IMAGE_NAME: nombre de la imagen de disco utilizado por la maquina virtual.
#
image_disk() {
  local DOMAIN
  local IMAGE_PATH
  local IMAGE_NAME

  DOMAIN="${1}"
  IMAGE_PATH="${2}"
  IMAGE_NAME=$(basename "${IMAGE_PATH}")
  virsh domblklist "${DOMAIN}" | awk -F \  /"${IMAGE_NAME}"/'{print $1}'
}



# Función para administrar instantáneas en las imágenes de disco.
# ACTION: [create | delete]
# DOMAIN: Nombre de la maquina virtual.
# DISK: Nombre del disco correspondiente a la imagen de disco.
# SNAPSHOT: Nombre de la instantánea a crear para la imagen a respaldar.
#
snapshot() {
  local ACTION
  local DOMAIN
  local DISK
  local SNAPSHOT

  ACTION="${1}"
  DOMAIN="${2}"
  DISK="${3}"
  SNAPSHOT="${4}"

  case ${ACTION} in
    create )
      # Se crea la instantánea como archivo separado y este pasa a ser la imagen.
      virsh snapshot-create-as "${DOMAIN}" "${SNAPSHOT}" --disk-only --atomic --quiesce
      message_syslog "Se ha creado la instantánea ${SNAPSHOT}."
      ;;
    delete )
      IMAGE_PATH=$(image_path "${DOMAIN}" "${DISK}")
      # Se envían los cambios desde la instantánea a la imagen principal y luego
      # se realiza el cambio a esta última.
      virsh blockcommit "${DOMAIN}" "${DISK}" --active --pivot

      # Se elimina el archivo creado por la instantánea.
      SNAPSHOT_FILE=$(echo "${IMAGE_PATH}" | grep "${SNAPSHOT}")
      rm -f "${SNAPSHOT_FILE}"
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
  local IMAGE
  local BACKUP_FILE

  IMAGE="${1}"
  BACKUP_FILE="${2}"

  qemu-img convert --force-share -c -O qcow2 "${IMAGE}" "${BACKUP_FILE}"
  message_syslog "El archivo de respaldo ${BACKUP_FILE} fue creado."
}



# Función para buscar y respaldar las imágenes de disco de las máquinas virtuales.
# administradas con app-emulation/libvirt.
# BLIBVIRT_BACKUP_PATH: ruta a la ubicación de la copia de respaldo.
#
libvirt_backup() {
  local BLIBVIRT_BACKUP_PATH
  local DOMAINS
  local EXT

  BLIBVIRT_BACKUP_PATH="${1}"
  DOMAINS=$(virsh list --name | sed '/^ *$/d')

  for domain in ${DOMAINS}; do
    # Búsqueda de imágenes de discos utilizados por cada dominio (maquina virtual).
    IMAGES=$(virsh domblklist "${domain}" | \
           awk -F \  /^\ [sv]d*/'{print $2}'| sed '/- *$/d')
    message_syslog "Comenzando el respaldo para el dominio ${domain}."

    # Creación de instantáneas para los discos del dominio.
    SNAPSHOT_TIME=$(/bin/date +%Y%m%d%H%M%S)
    SNAPSHOT="snapshot-${SNAPSHOT_TIME}"
    snapshot "create" "${domain}" "null" "${SNAPSHOT}"

    for image in ${IMAGES}; do
      # Busca la extensión de imagen: .img, .qcow, .qcow2, .raw, etc. Para devolver
      # el nombre sin extensión en IMAGE_NAME.
      EXT=$(echo "${image}" | awk -F \. //'{print $(NF)}')
      IMAGE_NAME=$(basename "${image}" ."${EXT}")

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
    virsh snapshot-delete "${domain}" "${SNAPSHOT}" --metadata

  done
}



# Función para detectar la extensión del archivo de respaldo. 
# en base a las características del sistema o las decisiones del usuario.
# Devuelve la extensión a utilizar por GNU tar para generar el archivo de respaldo.
#
file_extension(){
  local FORCE_BZIP2

  FORCE_BZIP2="${FORCE_LEGACY_BZIP2:-false}"

  # Si el usuario desea utilizar bzip2 debe configurar FORCE_LEGACY_BZIP2=true
  # en el archivo de configuración /etc/backup-cron/backup-cron.conf. 
  if [ "${FORCE_BZIP2}" != "true" ]; then

    if command -v zstd >/dev/null 2>&1; then
        # El sistema cuenta con zstd
        echo "tar.zst"
      elif command -v xz >/dev/null 2>&1; then
        # El sistema no tiene zstd, pero cuenta con xz.
        echo "tar.xz"
      else
        # El sistema no cuenta ni con zstd ni xz, se utiliza bzip2.
        echo "tar.bz2"
    fi

    else
      # El usuario configuró FORCE_LEGACY_BZIP2=true.
      echo "tar.bz2"
  fi

}



# Función para obtener la memoria RAM disponible.
# Devuelve la memoria RAM disponible en MiB.
#
get_available_memory(){
  local RAM_KB
  local RAM_MB
  
  # Extrae la memoria RAM disponible.
  if grep -q "MemAvailable" /proc/meminfo; then
    # En sistemas modernos.
    RAM_KB=$(awk '/MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null || echo 512000)
  else
    # En sistemas antiguos.
    RAM_KB=$(awk '/MemFree/ {free=$2} /Buffers/ {buf=$2} /^Cached/ {cached=$2} \
      END {print free+buf+cached}' /proc/meminfo 2>/dev/null || echo 512000)
  fi

  RAM_MB=$((RAM_KB / 1024))
  echo "${RAM_MB}"
}



# Función para detectar la utilidad de compresión disponible y ajustar los parámetros 
# en base a las características del sistema o las decisiones del usuario.
# Devuelve el comando de compresión a utilizar por GNU tar.
#
get_compress_program() {
  local CPUS
  local FORCE_BZIP2
  local RAM_AVAIL
  local RAM_HALF_AVAIL

  # Auto-detección de Hardware para Zstandard o XZ Utils.
  CPUS=$(nproc 2>/dev/null || echo 1)
  RAM_AVAIL=$(get_available_memory)

  FORCE_BZIP2="${FORCE_LEGACY_BZIP2:-false}"

  # Si el usuario desea utilizar bzip2 debe configurar FORCE_LEGACY_BZIP2=true
  # en el archivo de configuración /etc/backup-cron/backup-cron.conf. 
  if [ "${FORCE_BZIP2}" != "true" ]; then

    if command -v zstd >/dev/null 2>&1; then
        # El sistema cuenta con zstd

        if [ "${RAM_AVAIL}" -lt 512 ]; then
            # Sistemas con 1 CPU y menos de 512MiB de RAM libre.
            # Compresión con un solo hilo (~75MiB de RAM).
            echo "zstd -15 --threads=1"
          elif [ "${RAM_AVAIL}" -ge 512 ] && [ "${RAM_AVAIL}" -lt 1536 ]; then
            # Entornos con RAM libre entre 512MiB y 1536MiB.

            if [ "${CPUS}" -gt 1 ]; then
              # El sistema cuenta con mas de 1 CPU.
              # Compresión con dos hilos (~150MiB de RAM).
              echo "zstd -15 --threads=2"
            else
              # El sistema cuenta solo con 1 CPU.
              # Compresión con un solo hilo (~75MiB de RAM).
              echo "zstd -15 --threads=1"
            fi

          else
            # Sistemas con mas de 1536MiB de RAM disponible y múltiples CPUs.
            # Compresión estándar, multi-hilo.
            echo "zstd -15 --threads=0"
        fi

      elif command -v xz >/dev/null 2>&1; then
        # El sistema no tiene zstd, pero cuenta con xz.

        if [ "${RAM_AVAIL}" -lt 512 ]; then
            # Sistemas con 1 CPU y menos de 512MiB de RAM libre.
            # Compresión con un solo hilo (~95MiB de RAM).
            echo "xz -6 --threads=1 -M ${RAM_AVAIL}MiB"
          elif [ "${CPUS}" -gt 1 ] && [ "${RAM_AVAIL}" -gt 4096 ]; then
            # Sistemas con múltiples CPUs y mas de 4096MiB de RAM.
            # Compresión estándar, multi-hilo.
            echo "xz -6 --threads=0"
          else
            # Sistemas entre con RAM disponible entre 512MiB y 4096MiB.
            # Compresión estándar, multi-hilo verificando que no exceda la RAM
            # disponible.
            RAM_HALF_AVAIL=$((RAM_AVAIL / 2))
            echo "xz -6 --threads=0 -M ${RAM_HALF_AVAIL}MiB"
        fi

      else
        # El sistema no cuenta ni con zstd ni xz, se utiliza bzip2.
        echo "bzip2"
    fi

    else
      # El usuario configuró FORCE_LEGACY_BZIP2=true.
      echo "bzip2"
  fi

}



# Función para realizar respaldos en disco mediante GNU Tar.
# BACKUP: archivo de respaldo a crear.
# DIRS: directorios o archivos a respaldar.
# EXCLUDE: ruta al archivo que especifica los patrones a excluir por GNU Tar.
#
file_backup() {
  local BACKUP
  local COMPRESS
  local EXCLUDE
  local FILES
  local FILE_EXTENSION

  BACKUP="${1}"
  FILES="${2}"
  COMPRESS=$(get_compress_program)
  EXCLUDE="/etc/backup-cron/exclude.txt"
  FILE_EXTENSION=$(file_extension)
  BACKUP="${BACKUP}.${FILE_EXTENSION}"

  tar --create \
    --use-compress-program="${COMPRESS}" \
    --preserve-permissions \
    --file "${BACKUP}" \
    --files-from "${FILES}" &>/dev/null

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
  local BACKUP
  local COMPRESS
  local DIRS
  local DAYOFMONTH
  local EXCLUDE
  local FILE_EXTENSION
  local LEVEL
  local SNAR

  BACKUP="${1}"
  DIRS="${2}"
  COMPRESS=$(get_compress_program)
  DAYOFMONTH=$(date +%d)
  EXCLUDE="/etc/backup-cron/exclude.txt"
  LEVEL=""
  SNAR="${BACKUP}.snar"
  FILE_EXTENSION=$(file_extension)

  if [ "${DAYOFMONTH}" -eq 01 ] || [ ! -e "${SNAR}" ]; then
      LEVEL="0"
      BACKUP="${BACKUP}-full-${FECHA}.${FILE_EXTENSION}"
    else
      LEVEL="1"
      BACKUP="${BACKUP}-incremental-${FECHA}.${FILE_EXTENSION}"
  fi

  tar --create \
    --use-compress-program="${COMPRESS}" \
    --preserve-permissions \
    --xattrs --xattrs-include=*.* \
    --ignore-failed-read \
    --file "${BACKUP}" \
    --listed-incremental="${SNAR}" \
    --level="${LEVEL}" \
    --exclude-backups \
    --exclude-caches \
    --exclude-from="${EXCLUDE}" ${DIRS} &>/dev/null

  tar_not_empty "${BACKUP}"
  file_encrypt "${BACKUP}"
}



# Función para realizar respaldos en cinta.
# DIRS: directorios o archivos a respaldar.
# TAPE: dispositivo de cintas a utilizar definido en /etc/backup-cron/backup-cron.conf.
#
tape_backup() {
  local DIRS
  local EXCLUDE

  DIRS="${1}"
  EXCLUDE="/etc/backup-cron/exclude.txt"

  tar --create --blocking-factor=64 --preserve-permissions --xattrs \
               --xattrs-include=*.* --exclude-backups --exclude-caches \
               --exclude-from="${EXCLUDE}" "${DIRS}" | \
               mbuffer -t -m 128M -p 90 -s 65536 -f -o "${TAPE}" &>/dev/null

  message_syslog "El directorio ${DIRS} fue respaldado en ${TAPE}."
}



# Función para determinar si un archivo de respaldo contiene archivos.
# En caso de estar vacío, es eliminado y aborta la ejecución del programa.
#
tar_not_empty() {
  local FILE
  local TEST

  FILE="${1}"
  TEST=$(tar --list --file "${FILE}" | head -n 1 | wc -l)

  if [ "${TEST}" == "0" ]; then
      message_syslog "Archivo de respaldo ${FILE} sin datos, se procede a eliminarlo."
      rm -f "${FILE}"
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
  local FILE
  local DIRECTORY
  local HASHES

  FILE=$(echo "${1}" | awk -F / //'{print $(NF)}')
  DIRECTORY=$(echo "${1}" | awk -F /"${FILE}" //'{print $1}')
  HASHES="md5 sha1 sha256"

  cd "${DIRECTORY}" || exit

  for hash in ${HASHES}; do
    PROGRAM="${hash}sum"
    CHECKSUM=$(${PROGRAM} "${FILE}")
    echo "${CHECKSUM}" > "${FILE}"."${hash}"
    file_perms "${FILE}.${hash}"
    message_syslog "La suma ${hash} fue creada: ${CHECKSUM}."
  done

}



# Función para encriptar archivos mediante GNUPG.
# FILE: archivo a encriptar mediante GNUPG.
#
file_encrypt() {
  local FILE

  FILE="${1}"

  if [ "${PGP_ID}" != "" ]; then
      gpg --encrypt --recipient "${PGP_ID}" --compress-algo none --output "${FILE}".gpg "${FILE}"

      # Se verifica que GNUPG haya encriptado correctamente.
      if [ $? -eq 0 ]; then
          rm -f "${FILE}"
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
  local DIRECTORY
  local ERASE_DATE
  local ERASE_FILES

  DIRECTORY="${1}"
  ERASE_DATE=$(date --date="${KEEP_INCREMENTAL} month ago" +%Y%m)
  ERASE_FILES=""

  cd "${DIRECTORY}" || exit
  ERASE_FILES=$(find ./*"${ERASE_DATE}"*.tar.* -maxdepth 0 -type f -printf "%f\n" 2>/dev/null)

  for file in ${ERASE_FILES}; do
    rm -f "${file}" &>/dev/null
    message_syslog "Se eliminó el archivo obsoleto ${file}."
  done

}



# Función para borrar copias de respaldo antiguas.
# TIME: tiempo de modificación utilizado para borrar archivos.
# TMPCLEAN: variable definida por TMPWATCH en el archivo de configuración.
# PATH: ruta al directorio donde se encuentran los archivos antiguos a borrar.
#
# TODO: find . -name "" -mtime + | xargs echo
#
clean_old_backups() {
  local TMPCLEAN
  local TIME
  local PATH

  TMPCLEAN="${1}"
  TIME="${2}"
  PATH="${3}"

  if [[ -d ${PATH} ]]; then
    ${TMPCLEAN} --mtime "${TIME}" "${PATH}"
    message_syslog "Las copias con antigüedad mayor a ${TIME} hs en ${PATH} fueron borradas."
  fi

}



# Función para copiar archivos de respaldo en servidores remotos.
# IP: URL o dirección IP del servidor remoto.
# USER: usuario para conectarse con el servidor remoto.
# PATH: ruta al directorio donde se ubican las copias de respaldo a transferir.
#
remote_backup() {
  local REMOTE_IP
  local USER
  local PATH

  REMOTE_IP="${1}"
  USER="${2}"
  PATH="${3}"

  if [ "${REMOTE_IP}" != "" ]; then

    for ip in ${REMOTE_IP}; do

      find "${PATH}"/*-"${FECHA}".* -maxdepth 0 -type f -printf "%f\0" 2>/dev/null \
        | while IFS= read -r -d '' file; do
        rsync --archive "${file}" --rsh="ssh -l ${USER}" "${ip}":"${PATH}" &>/dev/null

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



# Función para alertar al usuario que el archivo pasado como parámetro no existe.
# Ejemplo al invocar el scrit /usr/sbin/mysql_restore.
# FILE: archivo evaluado
#
file_no_exist() {
  local FILE

  FILE="${1}"

  warning "ERROR" "El archivo ${FILE} no existe."
  echo ""
  exit 1
}



# Función para alertar en el pasaje de parámetro la ruta al archivo de respaldo.
# Ejemplo al invocar el scrit /usr/sbin/mysql_restore.
#
no_file() {
  warning "ERROR" "No se especificó ningun archivo de respaldo. Vea:."
  echo " $(basename "${0}") --help"
  echo ""
  exit 1
}



# Función para seleccionar al azar un algoritmo de suma para comprobación.
#
ramdom_select_sum() {
  local NUM

  NUM="$((1 + RANDOM % 3))"

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

  export SUM
  export DIGEST
  export EXT
}



# Verifica que exista el conjunto completo de respaldo, incluyendo todos los
# archivos de suma
#
verify_set() {
  local FILE
  local BACKUP_SET
  local set

  FILE="${1}"
  BACKUP_SET="md5 sha1 sha256"
  set=""

  for set in ${BACKUP_SET}; do

    if [ ! -e "${FILE}.${set}" ]; then
      file_no_exist "${FILE}.${set}."
    fi

  done
}



# Función para verificar que existen las herramientas para descomprimir el respaldo.
#
verify_compressor_restore() {
  local FILE
  local EXT

  FILE="$1"

  # Extrae la extensión del archivo (.zst, .xz, .bz2)
  EXT="${FILE##*.}"

  case "${EXT}" in
    zst)
      if ! command -v zstd >/dev/null 2>&1; then
        warning "ERROR" "El respaldo requiere 'zstd' para ser restaurado."
        exit 1
      fi
      ;;
    xz)
      if ! command -v xz >/dev/null 2>&1; then
        warning "ERROR" "El respaldo requiere 'xz' para ser restaurado."
        exit 1
      fi
      ;;
  esac
}



# Función para desencriptar archivos mediante GNUPG. Devuelve la ruta al archivo
# desencriptado.
# FILE: archivo a desencritpar.
# DECRIPT_FILE: archivo desencriptado.
#
file_decrypt() {
  local FILE
  local DECRIPT_FILE

  FILE="${1}"
  DECRIPT_FILE="$(echo "${FILE}" | awk -F .gpg '{print $(1)}')"

  gpg --decrypt --output "${DECRIPT_FILE}" "${FILE}"

  if [ $? -eq 0 ]; then
      echo "${DECRIPT_FILE}"
    else
      warning "ERROR:" "No se pudo desencriptar el archivo ${FILE}."
      exit 1
  fi
}



# Función para mostrar secuencia 1..9
#
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
#
function unpack() {
  local FILE
  local DIRECTORY
  local DECRIPT_FILE

  FILE="${1}"
  DIRECTORY="${2}"
  DECRIPT_FILE=""

  if [ "${PGP_ID}" != "" ]; then
      DECRIPT_FILE=$(file_decrypt "${FILE}")
    else
      DECRIPT_FILE="${FILE}"
  fi

  tar --extract \
    --verbose \
    --preserve-permissions \
    --listed-incremental=/dev/null \
    --xattrs \
    --xattrs-include=*.* \
    --file "${DECRIPT_FILE}" \
    --directory="${DIRECTORY}"

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

