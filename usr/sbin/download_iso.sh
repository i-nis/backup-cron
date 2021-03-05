#!/bin/bash
#
# download_iso.sh: script para descargar imagenes ISO de Gentoo.
#
# (C) 2006 - 2021 NIS
# Autor: Martin Andres Gomez Gimenez <mggimenez@nis.com.ar>
# Distributed under the terms of the GNU General Public License v3
#



# URL desde donde descargar la imagen ISO.
URL="http://distfiles.gentoo.org/releases"



# Función de ayuda.
usage() {
  local PROG_NAME=$(basename $0)
  local PROG_PATH=$(echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,')
  echo ""
  echo "${PROG_NAME}:"
  echo "Descarga en /var/tmp la imagen ISO de Gentoo para la arquitectura seleccionada."
  echo
  echo "  Uso: "
  echo "    ${PROG_PATH}/${PROG_NAME} [-h|--help] [amd64|x86]"
  echo ""
  echo "    --help, -h"
  echo "        Muestra esta ayuda."
  echo ""
}



# Verifica el correcto pasaje de parámetros
if [ "${1}" == "amd64" ] || [ "${1}" == "x86" ] && [ "${#}" == "1" ]; then
    ARCH="${1}"
    URL_ARCH="${URL}/${ARCH}/autobuilds/current-admincd-${ARCH}"
  else
    usage
    exit
fi



# Archivos a descargar desde $URL
ISO=$(curl --silent "${URL_ARCH}/" | awk -F \" /iso/'{print $8}' | grep iso$)
CONTENTS=$(curl --silent "${URL_ARCH}/" | awk -F \" /iso/'{print $8}' | grep CONTENTS$)
DIGESTS=$(curl --silent "${URL_ARCH}/" | awk -F \" /iso/'{print $8}' | grep DIGESTS$)



# Función para eliminar archivos
rm_files() {
  local FILES="$1"

  for file in ${FILES}; do
    echo "Borrando archivo ${file}"
    rm -f ${file}
  done

}



# Función para descarga de archivos desde $URL
DESCARGA=0

cd /var/tmp

until (( ${DESCARGA} )); do
  wget -c ${URL_ARCH}/${ISO}
  wget -c ${URL_ARCH}/${CONTENTS}
  wget -c ${URL_ARCH}/${DIGESTS}
  wget -c ${URL_ARCH}/${DIGESTS}.asc
  WARN=$(sha512sum --check "${DIGESTS}" | head -1)

  if [ "${WARN}" == "${ISO}: La suma coincide" ]; then
      DESCARGA=1
      echo "Descarga finalizada."
    else
      echo "Falló la descarga."
      rm_files ${WARN}
  fi

done

