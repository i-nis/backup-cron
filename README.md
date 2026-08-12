# backup-cron

[![License](http://img.shields.io/:license-gpl-green.svg)](https://www.gnu.org/licenses/gpl-3.0.txt)
[![pipeline status](https://gitlab.nis.com.ar/proyectos/backup-cron/badges/master/pipeline.svg)](https://gitlab.nis.com.ar/proyectos/backup-cron/-/commits/master)

[[_TOC_]]

Backup-cron es un sistema minimalista de generación de copias de resguardo basado en herramientas GNU y en la utilización del 
planificador Cron.

Backup-cron es software libre publicado bajo la [Licencia Pública General de GNU](http://www.gnu.org/licenses/gpl.txt)

## Características

El conjunto de scripts se ha desarrollado con las siguientes características:

* Empaquetado mediante GNU tar.
* Compresión utilizando [Zstandard](https://facebook.github.io/zstd/), [XZ Utils](https://tukaani.org/xz/) o [Bzip2](https://sourceware.org/bzip2/).
* Encriptación de respaldos mediange [GnuPG](https://www.gnupg.org/related_software/gpgme/).
* Planificación diaria, semanal o mensual vía Cron.
* Soporte para gestionar la planificación mediante [eselect](https://wiki.gentoo.org/wiki/Eselect).
* Posibilidad de respaldo de todo el sistema o parte de él.
* Generación de sumas por MD5, SHA1 y SHA256.
* Envío de mensajes vía syslog.
* Respaldo en sistemas de archivo locales o servidores remotos.
* Respaldo en cintas con soporte para compresión por hardware.
* Respaldo en línea de imágenes de discos virtuales administrados con libvirt.

## Documentación de Backup-Cron

Se encuentra accesible en la [wiki de Backup-cron](https://gitlab.nis.com.ar/proyectos/backup-cron/-/wikis/home)


## Instalación

### Debian

Para instalar backup-cron en Debian (y distribuciones basadas en esta), es necesario 
realizar los siguientes pasos:
 
1. Instalar el soporte para repositorios vía HTTPS:

```sh
sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates
```

2. Descargar la clave de distribución:

```sh
sudo curl --fail --silent --show-error --output /etc/apt/keyrings/backup-cron.asc \
     --url "https://gitlab.nis.com.ar/api/v4/projects/6/debian_distributions/stable/key.asc"
```

3. Agregar el repositorio:

```sh
echo "deb [arch=all signed-by=/etc/apt/keyrings/backup-cron.asc] https://gitlab.nis.com.ar/api/v4/projects/6/packages/debian stable main" \
      | sudo tee /etc/apt/sources.list.d/backup-cron.list
```

4. Instalar backup-cron:

```sh
apt install backup-cron
```


### Gentoo Linux

Para extender el portage es necesario agregar el siguiente 
[overlay del portage](https://gitlab.nis.com.ar/proyectos/gentoo-portage-backup-cron) 
que contiene los ebuilds desarrollados para este proyecto. Para ello es necesario 
crear el archivo _/etc/portage/repos.conf/backup-cron.conf_ con el siguiente 
contenido:

```sh
[backup-cron]
location = /var/db/repos/backup-cron
sync-type = git
sync-uri = https://gitlab.nis.com.ar/proyectos/gentoo-portage-backup-cron.git
auto-sync = yes
```

Por último queda actualizar la lista de paquetes e instalar las utilidades 
estándar de backup-cron:

```sh
emaint sync --all
emerge --ask --verbose backup-cron app-backup/backup_etc-cron app-backup/backup_system-cron
```

Para instalar el soporte para respaldos en cinta:

```sh
emerge --ask --verbose backup-cron app-backup/backup_tape-cron
```

Para instalar el soporte para respaldos en maquinas virtuales basadas en KVM:

```sh
emerge --ask --verbose backup-cron app-backup/backup_libvirt-cron
```

