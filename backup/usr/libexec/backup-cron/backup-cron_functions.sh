#!/bin/bash
#
# backup-cron_functions.sh: funciones comunes para los script de copias de 
# seguridad.
#
# (C) 2006 - 2010 Martin Andres Gomez Gimenez <mggimenez@i-nis.com.ar>
# Distributed under the terms of the GNU General Public License v3
#
# Revision : $Id$



source /etc/backup-cron/backup-cron.conf



# Función para enviar mensajes vía syslog. Utiliza la interfaz de comando
# denominada logger. Para más detalles vea: man logger
message_syslog () {
  local NAME="$1"
  local MESSAGE="$2"
  local LOGGER="/usr/bin/logger"
  $LOGGER -i -t $NAME $MESSAGE
}



# Función para verificar la existencia de un directorio. Si este no existe es
# creado. Recibe como argumento el nombre del directorio a verificar. 
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



# Función para respaldar /home
home_backup() {
  local NAME="$1"
  local HOME_PATH="$2"
  local BACKUP_PATH="$3"
  local directory=""
  local FIND="/usr/bin/find"
  local HOST=`hostname`
  local FECHA=$(date +%G%m%d)
  local FILE="backup-$HOST"
  local EXT="tar.bz2"

  cd $HOME_PATH

  for directory in $($FIND * -maxdepth 0 -type d); do
    file_backup "$NAME" "$BHOME_BACKUP_PATH/$FILE-$directory-$FECHA.$EXT" \
    "$directory --exclude=backup/*/*" "disk"
  done

}



# Función para respaldar otros directorios
file_backup() {
  local NAME="$1"
  local BACKUP_FILE="$2"
  local DIRS="$3"
  local MODE="$4"
  local TAR="/bin/tar"
  local TAR_OPTS="--create --bzip2 --preserve-permissions --file"
  local EXCLUDE="/etc/backup-cron/exclude.txt"
  
  case $MODE in
    disk )
      $TAR $TAR_OPTS $BACKUP_FILE $DIRS --exclude-from=$EXCLUDE
      message_syslog "$NAME" "El archivo de respaldo $BACKUP_FILE fue creado"
      ;;
    tape )
      $TAR $TAR_OPTS $BACKUP_FILE $DIRS --exclude-from=$EXCLUDE
      message_syslog "$NAME" "El directorio $DIRS fue respaldado en $TAPE"
      ;;
    esac

}



# Función para generar sumas MD5, SHA1, SHA256, etc
gensum() {
  local NAME="$1"
  local FILE="$2"
  
  for hash in $HASHES; do
    SUM=`$hash $FILE`
    echo "$SUM" >> $FILE.DIGEST
    message_syslog "$NAME" "La suma $hash fue creada: $SUM"
  done
  
}



# Función para copiar archivos de respaldo en servidores remotos
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

