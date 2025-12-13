# backup-cron

[![License](http://img.shields.io/:license-gpl-green.svg)](https://www.gnu.org/licenses/gpl-3.0.txt)
[![pipeline status](https://gitlab.nis.com.ar/proyectos/backup-cron/badges/master/pipeline.svg)](https://gitlab.nis.com.ar/proyectos/backup-cron/-/commits/master)

Backup-cron es un sistema minimalista de generación de copias de resguardo basado en herramientas GNU y en la utilización del 
planificador Cron.

Backup-cron es software libre publicado bajo la [Licencia Pública General de GNU](http://www.gnu.org/licenses/gpl.txt)

## Características

El conjunto de scripts se ha desarrollado con las siguientes características:

* Empaquetado mediante GNU tar.
* Compresión utilizando Bzip2.
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


## Portage

Portage es el gestor de paquetes oficial de la distribución de Linux [Gentoo](https://es.wikipedia.org/wiki/Gentoo_Linux) y también el de [Funtoo Linux](https://en.wikipedia.org/wiki/Funtoo_Linux), [Sabayon](https://en.wikipedia.org/wiki/Sabayon_Linux) y [Google Chrome OS](https://es.wikipedia.org/wiki/Chrome_OS) entre otras.

Implementa gestión de dependencias, afinamiento preciso de los paquetes a gusto del administrador, instalaciones falsas (al estilo OpenBSD), entornos de prueba durante la compilación, desinstalación segura, perfiles de sistema, paquetes virtuales, gestión de los ficheros de configuración y múltiples ranuras para distintas versiones de un mismo paquete.

El portage dispone de un árbol local que contiene las descripciones de los paquetes de software y las funcionalidades necesarias para instalarlos en archivos llamados ebuilds. Este árbol se puede sincronizar con un servidor remoto mediante una orden:

<pre>
emerge --sync
</pre> 


### Extender el portage con los ebuilds de este proyecto

Para extender su portage con los ebuilds desarrollados por este proyecto, debe crear el archivo _/etc/portage/repos.conf/backup-cron.conf_ con el siguiente contenido:

<pre>
[backup-cron]
location = /var/db/repos/backup-cron
clone-depth = 1
sync-type = git
sync-uri = https://github.com/i-nis/gentoo-portage-backup-cron.git
auto-sync = yes
</pre>

