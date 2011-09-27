#!/bin/bash
#
# backup-cron_functions.sh: funciones comunes para los script de copias de 
# seguridad.
#
# (C) 2006 - 2011 Martin Andres Gomez Gimenez <mggimenez@i-nis.com.ar>
# Distributed under the terms of the GNU General Public License v3
#
# Revision : $Id$



# Función para enviar mensajes vía syslog. Utiliza la interfaz de comando
# denominada logger. Para más detalles vea: man logger. 
# NAME: nombre del programa que invoca.
# MESSAGE: mensaje a enviar vía syslog.
#
message_syslog () {
  local NAME="$1"
  local MESSAGE="$2"
  local LOGGER="/usr/bin/logger"
  $LOGGER -i -t $NAME $MESSAGE
}



# Función para verificar la existencia de un directorio. Si este no existe es
# creado. 
# NAME: nombre del programa que invoca.
# DIRECTORY: ruta del directorio a verificar.
#
directory_mkdir() {
  local NAME="$1"
  local DIRECTORY="$2"
  local MKDIR="/bin/mkdir"

  if [ ! -e $DIRECTORY ]; then
    $MKDIR --parents --mode=755 $DIRECTORY
    message_syslog "$NAME" "El directorio $DIRECTORY fue creado"
  fi

}



# Función para el volcado de bases de datos en SQL en disco o en cinta DAT. 
# NAME: nombre del programa que invoca.
# OPTIONS: opciones para mysqldump, para mas detalles vea "man mysqldump".
# BACKUP_PATH: ruta a la ubicación de la copia de respaldo.
# 
dump_mysql() {
  local NAME="$1"
  local OPTIONS="$2"
  local BACKUP_PATH="$3"
  local FIND="/usr/bin/find"
  local MYSQLDUMP="/usr/bin/mysqldump"
  local MYSQL_PATH="/var/lib/mysql"

  if [ -d $MYSQL_PATH ]; then
    cd $MYSQL_PATH

    for database in $($FIND * -maxdepth 0 -type d); do
      $MYSQLDUMP $OPTIONS $database > $BACKUP_PATH/$database.sql
      message_syslog "$NAME" "La base de datos $database fue extraida."
    done

  fi

}



# Función para respaldar /home. 
# NAME: nombre del programa que invoca.
# HOME_PATH: ruta al directorio /home
# BACKUP_PATH: ruta al directorio donde se ubicará la copia de respaldo.
home_backup() {
  local NAME="$1"
  local TAR_OPTS="$2"
  local HOME_PATH="$3"
  local BACKUP_PATH="$4"
  local directory=""
  local FIND="/usr/bin/find"
  local HOST=`hostname`
  local FECHA=$(date +%G%m%d)
  local FILE="backup-$HOST"
  local EXT="tar.bz2"

  cd $HOME_PATH

  for directory in $($FIND * -maxdepth 0 -type d); do
    file_backup "$NAME" "$TAR_OPTS" "$BHOME_BACKUP_PATH/$FILE-$directory-$FECHA.$EXT" \
    "$directory --exclude=backup/*/*" "disk"
  done

}



# Función para respaldar otros directorios. 
# NAME: nombre del programa que invoca.
# BACKUP_FILE: archivo de respaldo a crear.
# DIRS: directorios o archivos a respaldar.
# MODE: modo de respaldo: [disk | tape]
file_backup() {
  local NAME="$1"
  local TAR_OPT="$2"
  local BACKUP="$3"
  local DIRS="$4"
  local MODE="$5"
  local TAR="/bin/tar"
  local EXCLUDE="/etc/backup-cron/exclude.txt"
  local MBUFFER="/usr/bin/mbuffer -t -m 128M -p 90 -s 65536 -f -o"

  case $MODE in
    disk )
      $TAR $TAR_OPTS $BACKUP $DIRS --exclude-from=$EXCLUDE &>/dev/null
      message_syslog "$NAME" "El archivo de respaldo $BACKUP fue creado"
      ;;
    tape )
      $TAR $TAR_OPTS $DIRS --exclude-from=$EXCLUDE | $MBUFFER $BACKUP &>/dev/null
      message_syslog "$NAME" "El directorio $DIRS fue respaldado en $BACKUP"
      ;;
    esac

}



# Función para generar sumas MD5, SHA1, SHA256, etc. 
# NAME: nombre del programa que invoca.
# HASHES: algoritmos para verificar sumas.
# FILE: archivo desde el cual se creará la suma. 
gensum() {
  local NAME="$1"
  local HASHES="$2"
  local FILE="$3"

  for hash in $HASHES; do
    SUM=`$hash $FILE`
    echo "$SUM" >> $FILE.DIGEST
    message_syslog "$NAME" "La suma $hash fue creada: $SUM"
  done

}



# Función para borrar copias de respaldo antigüas. 
# NAME: nombre del programa que invoca.
# TIME: tiempo de modificación utilizado para borrar archivos.
# TMPCLEAN: variable definida por TMPWATCH en el archivo de configuración.
# PATH: ruta al direcotorio donde se encuentran los archivos antigüos a borrar.
clean_old_backups() {
  local NAME="$1"
  local TMPCLEAN="$2"
  local TIME="$3"
  local PATH="$4"

  if [[ -d $PATH ]]; then
    ${TMPCLEAN} --mtime $TIME $PATH
    message_syslog "$NAME" "Las copias con antigüedad mayor a $TIME hs fueron borradas."
  fi

}



# Función para copiar archivos de respaldo en servidores remotos. 
# NAME: nombre del programa que invoca.
# FILE: archivo a copiar al servidor remoto.
# IP: dirección IP del servidor remoto.
# USER: usuario para conectarse con el servidor remoto.
# PATH: ruta al directorio donde se ubicará la copia de respaldo.
remote_backup() {
  local NAME="$1"
  local FILE="$2"
  local IP="$3"
  local USER="$4"
  local PATH="$5"
  local SCP="/usr/bin/scp"

  if [  ! $($SCP $FILE $USER@$IP:$PATH) ]; then
    message_syslog "$NAME" "El archivo $FILE fue copiado al servidor $IP"
  else
    message_syslog "$NAME" "El archivo $FILE no pudo ser copiado al servidor $IP"
  fi

}

