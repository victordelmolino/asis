#!/bin/bash
#927838, Molino Tomé, Victor del, M, 5, B
#836304, Medina Rodriguez, Jesús Alejandro, M, 5, B

acc="$1"
fich="$2"

# Comprueba si el usuario que ejecuta el script no es root (UID distinto de 0).
if [ "$(id -u)" -ne 0 ]; then
	echo "Este script necesita privilegios de administracion"
	exit 1
fi

if [ "$#" -ne 2 ]; then
    echo "Número incorrecto de parámetros"
    exit 1
fi

if [ "$acc" != "-a" ] && [ "$acc" != "-s" ]; then
    echo "Opción invalida" >&2
    exit 1
fi

fichlog="$(date +%Y_%m_%d)_user_provisioning.log"

# MODO PARA EL BORRADO DE USUARIOS
if [ "$acc" = "-s" ]; then

    # -p: crea el directorio y los padre necesarios, sin error si ya existen. 
    mkdir -p /extra/backup

    # while es un bucle que se ejecuta linea por linea del fichero.
    # IFS=',': indica que los campos de las líneas  se separan por comas.
    # read -r: -r lee la línea sin interpretar '\' como caracter especial.
    # read usuario resto: antes del primer separador a usuario y el resto a resto.
    # IFS significa Internal Field Separator (separador de campos).
    while IFS=',' read -r usuario resto; do
	
        if [ -z "$usuario" ]; then
            continue
        fi
	
	# id "$usuario" devuelve 0 si el usuario ya existe en el sistema.
	# Todo lo que se redirige a /dev/null desaparece (no por pantalla).
	# >/dev/null: la stdout va a /dev/null; 2>&1 stderr donde stdout.
	if ! id "$usuario" >/dev/null 2>&1; then
		continue
	fi

        echo "Procesando borrado de $usuario"
	# echo "a" >> "$fich": añade en fich "a" sin dañar el resto del contenido.
	# echo "a" > "$fich": sobreescribe fich (borra todo) y escribe "a".
        echo "Procesando borrado de $usuario" >> "$fichlog"

	# tar: programa para crear archivos comprimidos o empaquetados.
	# -c: crear un archivo .tar; -f: se indica el nombre con el que se creará.
	# -C /home "$usuario": copia /home/usuario dentro del archivo tar.
	tar -cf "/extra/backup/${usuario}.tar" -C /home "$usuario"

	# $?: guarda el código de salida del último comando ejecutado.
	# Si da error, evita borrar un usuario sin haber guardado su backup.
	if [ $? -ne 0 ]; then
            continue
        fi

	# userdel: el comando userdel sirve para eliminar un usuario del sistema.
	# -r: hace que también se borre su directorio home y su correo del sistema.
	userdel -r "$usuario"

    # done < "$fich": redirige la stdin del while al fichero "$fich".
    done < "$fich"
fi

# Modo creación de usuarios
if [ "$acc" = "-a" ]; then

    # while es un bucle que se ejecuta linea por linea del fichero.
    # IFS=',' : indica que los campos de las lineas se separan por comas.
    # read -r: -r lee la linea sin interpretar '\' como caracter especial.
    # read usuario resto: antes del primer separador a usuario y el resto a resto.
    # IFS significa Internal Field Separator (separador de campos).
    while IFS=',' read -r usuario password nombre; do

        # Si algún campo está vacío, devolvemos "Campo invalido" y continuamos.
	# La opción -z sirve para comprobar si una cadena está vacía.
        if [ -z "$usuario" ] || [ -z "$password" ] || [ -z "$nombre" ]; then
            echo "Campo invalido"
            continue
        fi

	# id "$usuario" devuelve 0 si el usuario ya existe en el sistema.
	# Todo lo que se redirige a /dev/null desaparece (no por pantalla).
	# >/dev/null: la stdout va a /dev/null; 2>&1 stderr donde stdout.
        if id "$usuario" >/dev/null 2>&1; then
            echo "El usuario $usuario ya existe"
            echo "El usuario $usuario ya existe" >> "$fichlog"
            continue
        fi

  	# useradd: crea un usuario en el sistema; -m: crea /home/usuario.
	# -U: crea un grupo con el mismo nombre del usuario y se lo asigna.
	# -K: UID_MIN=1815: indica que el UID mínimo para el usuario sea 1815.
	# -c: "$nombre" "$usuario" crea el usuario de nombre "$usuario" y guarda su "$nombre".
        useradd -m -U -K UID_MIN=1815 -c "$nombre" "$usuario"

	# enviar "usuario:contraseña" a chpasswd para asignar contraseña.
        echo "$usuario:$password" | chpasswd

        # chage: configurar políticas de caducidad de una contraseña.
	# -M define el máximo password age (dias antes de caducar).
        chage -M 30 "$usuario"

        echo "$usuario ha sido creado"
        echo "$usuario ha sido creado" >> "$fichlog"

    # done < "$fich": redirige la stdin del while al fichero "$fich".
    done < "$fich"
fi
