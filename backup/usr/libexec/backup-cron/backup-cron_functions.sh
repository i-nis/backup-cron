#!/bin/bash
#
# backup-cron_functions.sh: funciones comunes para los script de copias de 
# seguridad.
#
# (C) 2006 - 2010 Martin Andres Gomez Gimenez <mggimenez@i-nis.com.ar>
# Distributed under the terms of the GNU General Public License v3
#
# Revision : $Id$



# Función para enviar mensajes vía syslog. Utiliza la interfaz de comando
# denominada logger. Para más detalles vea: man logger
message_syslog () {
  local NAME="$1"
  local MESSAGE="$2"
  logger -i -t $NAME $MESSAGE
}



# Función para verificar la existencia de un directorio. Si este no existe es
# creado. Recibe como argumento el nombre del directorio a verificar. 
directory_mkdir() {
  local NAME="$1"
  local DIRECTORY="$2"

  if [ ! -e $DIRECTORY ]; then
    mkdir --parents --mode=755 $DIRECTORY
    message_syslog "$NAME" "El directorio $DIRECTORY fue creado"
  fi

}



# Función para el volcado de bases de datos en SQL en disco o en cinta DAT.
# 
dump_mysql() {
  local NAME="$1"
  local OPTIONS="$2"
  local BACKUP_PATH="$3"
  local TAPE="$4"
  local MODE="$5"
  local MYSQL_PATH="/var/lib/mysql"
  local TAR_OPTS="--create --bzip2 --preserve-permissions --file"

  if [ -d $MYSQL_PATH ]; then
    cd $MYSQL_PATH
    
    for database in $(find * -maxdepth 0 -type d); do

        case $MODE in
          disk )
            mysqldump $OPTIONS $database > $BACKUP_PATH/$database.sql
            message_syslog $NAME "La base de datos $database fue extraida."
            ;;
          tape )
            mysqldump $OPTIONS $database | tar $TAR_OPTS $TAPE
            message_syslog $NAME "La base de datos $database fue respaldada en $TAPE."
            ;;
        esac

      done
      
  fi

}



# Función para respaldar /home
home_backup() {
  local NAME="$1"
  local HOME_PATH="$2"
  local BACKUP_PATH="$3"
  local TAPE="$4"
  local MODE="$5"
  local directory=""
  local HOST=`hostname`
  local FECHA=$(date +%G%m%d)
  local FILE="backup-$HOST"
  local EXT="tar.bz2"
  local TAR_OPTS="--create --bzip2 --preserve-permissions --file"
  
  cd $BACKUP_PATH
    
  for directory in $(find * -maxdepth 0 -type d); do

      case $MODE in
        disk )
          tar --exclude=backup/*/* --exclude=lost+found $TAR_OPTS \
          $BHOME_BACKUP_PATH/$FILE-$directory-$FECHA.$EXT $directory
          message_syslog "$NAME" "El archivo de respaldo $FILE-$directory-$FECHA.$EXT fue creado"
          ;;
        tape )
          tar --exclude=backup/*/* --exclude=lost+found $TAR_OPTS $TAPE $directory
          message_syslog "$NAME" "El directorio $directory fue respaldado en $TAPE"
          ;;
      esac

    done

}



# Función para respaldar otros directorios
other_backup() {
  local NAME="$1"
  local TAPE="$2"
  local DIRS="$3"
  local TAR_OPTS="--create --bzip2 --preserve-permissions --file"
  
  for directory in $DIRS; do
  
    if [ -d $directory ]; then  
      tar $TAR_OPTS $TAPE $directory
      message_syslog "$NAME" "El directorio $directory fue respaldado en $TAPE"
    fi
  
  done
}



# Función para generar sumas MD5, SHA1, SHA256, etc
gensum() {
  local NAME="$1"
  local SUM_HASHES="$2"
  local FILE="$3"
  
  for hash in $SUM_HASHES; do
    SUM=`$hash $FILE`
    echo "$SUM" >> $FILE.DIGEST
    message_syslog "$NAME" "La suma $hash fue creada: $SUM"
  done
  
}



# Función para copiar archivos de respaldo en servidores remotos
remote_backup() {
  local NAME="$1"
  local FILE="$2"
  local USER="$3"
  local IP="$4"
  local PATH="$5"

  if [  ! `scp $FILE $USER@$IP:$PATH` ]; then
    message_syslog "$NAME" "El archivo $file fue copiado al servidor $IP"
  else
    message_syslog "$NAME" "El archivo $file no pudo ser copiado al servidor $IP"
  fi
}

