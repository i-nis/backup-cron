# backup-cron
Backup-cron es un sistema minimalista de generación de copias de resguardo basado en herramientas GNU y en la utilización del 
planificador Cron.

Backup-cron es software libre publicado bajo la (Licencia Pública General de GNU](http://www.gnu.org/licenses/gpl.txt)

## Características

El conjunto de scripts se ha desarrollado con las siguientes características:

* Empaquetado mediante GNU tar.
* Compresión utilizando Bzip2.
* Planificación diaria o semanal vía Cron.
* Posibilidad de respaldo de todo el sistema o parte de él.
* Generación de sumas por MD5, SHA1 y SHA256.
* Envío de mensajes vía syslog.
* Respaldo en sistemas de archivo locales o servidores remotos.
* Respaldo en cintas con soporte para compresión por hardware.
* Respaldo en línea de imágenes de discos virtuales administrados con libvirt.

## Documentación de Backup-Cron

Se encuentra accesible en la [wiki de Backup-cron](https://proyectos.ingeniovirtual.com.ar/projects/backup-cron/wiki)
