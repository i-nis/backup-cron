#!/bin/bash
#
# download_iso.sh: script para descargar imagenes ISO.
#
# (C) 2009 Martin Andres Gomez Gimenez <mggimenez@i-nis.com.ar>
# Distributed under the terms of the GNU General Public License v3
#
# Revision : $Id$

# URL desde donde descargar la imagen ISO. Es necesario el caracter "/" al 
# final.
URL="http://mirrors.kernel.org/gentoo/releases/x86/current-iso/"

# Archivos a descargar desde $URL
ISO=`curl --silent "$URL" | awk -F \" /iso/'{print $2}' | grep iso$`
DIGESTS=`curl --silent "$URL" | awk -F \" /iso/'{print $2}' | grep DIGESTS$`
CONTENTS=`curl --silent "$URL" | awk -F \" /iso/'{print $2}' | grep CONTENTS$`


# Función para eliminar archivos
rm_files() {
  local FILES="$1"
  
  for file in $FILES; do
    echo "Borrando archivo $file"
    rm -f $file
  done

}



# Función para descarga de archivos desde $URL
DESCARGA=0

until (( $DESCARGA )); do
  wget -c $URL$ISO
  wget -c $URL$DIGESTS
  wget -c $URL$CONTENTS
  WARN=`sha1sum --check --quiet "$DIGESTS" | awk -F \: /iso/'{print $1}'`

  if [ "$WARN" == "" ]; then
      DESCARGA=1
    else
      rm_files $WARN
  fi

done






