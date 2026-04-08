#!/bin/bash
#927838, Molino Tomé, Victor del, M, 5, B
#836304, Medina Rodriguez, Jesús Alejandro, M, 5, B

acc="$1"
fich_usuarios="$2"
fich_ips="$3"

# Comprueba si el usuario que ejecuta el script no es root (UID distinto de 0).
if [ "$(id -u)" -ne 0 ]; then
	echo "Este script necesita privilegios de administracion"
	exit 1
fi

if [ "$#" -ne 3 ]; then
    echo "Número incorrecto de parámetros"
    exit 1
fi

if [ "$acc" != "-a" ] && [ "$acc" != "-s" ]; then
    echo "Opción invalida" >&2
    exit 1
fi

fichlog="$(date +%Y_%m_%d)_user_provisioning.log"


# while: bucle que recorre línea a línea el fichero de IPs.
# IFS= : lee la línea entera sin separadores de campo.
# read -r ip: guarda cada línea en la variable ip.
while IFS= read -r ip; do

    if [ -z "$ip" ]; then
        continue
    fi

    # Intenta conectarse a la máquina remota para comprobar si es accesible.
    # -i ~/.ssh/id_as_ed25519: usa la clave privada generada en la Parte 3.
    # -o ConnectTimeout=5: si no responde en 5 segundos, considera que no es accesible.
    # -o BatchMode=yes: no pide contraseña, falla directamente si no puede conectar.
    # exit: comando mínimo que ejecuta en la remota solo para probar la conexión.
    # 2>/dev/null: descarta mensajes de error para que no salgan por pantalla.
    ssh -i ~/.ssh/id_as_ed25519 -o ConnectTimeout=5 -o BatchMode=yes as@"$ip" exit 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "$ip no es accesible"
        continue
    fi

    # Modo borrado de usuarios
    if [ "$acc" = "-s" ]; then

        while IFS=',' read -r usuario resto; do

            if [ -z "$usuario" ]; then
                continue
            fi

            # Comprueba si el usuario existe en la máquina remota
            if ! ssh -i ~/.ssh/id_as_ed25519 as@"$ip" "id $usuario" >/dev/null 2>&1; then
                continue
            fi

            echo "Procesando borrado de $usuario"
            echo "Procesando borrado de $usuario en $ip" >> "$fichlog"

            # Crea backup del home del usuario en la máquina remota
            ssh -i ~/.ssh/id_as_ed25519 as@"$ip" "sudo mkdir -p /extra/backup && sudo tar -cf /extra/backup/${usuario}.tar -C /home $usuario"

            if [ $? -ne 0 ]; then
                continue
            fi

            # Borra el usuario en la máquina remota
            ssh -i ~/.ssh/id_as_ed25519 as@"$ip" "sudo userdel -r $usuario"

        done < "$fich_usuarios"
    fi

    # Modo creación de usuarios
    if [ "$acc" = "-a" ]; then

        while IFS=',' read -r usuario password nombre; do

            if [ -z "$usuario" ] || [ -z "$password" ] || [ -z "$nombre" ]; then
                echo "Campo invalido"
                continue
            fi

            # Comprueba si el usuario ya existe en la máquina remota
            if ssh -i ~/.ssh/id_as_ed25519 as@"$ip" "id $usuario" >/dev/null 2>&1; then
                echo "El usuario $usuario ya existe"
                echo "El usuario $usuario ya existe en $ip" >> "$fichlog"
                continue
            fi

            # Ejecuta useradd en la máquina remota via SSH con sudo
            ssh -i ~/.ssh/id_as_ed25519 as@"$ip" "sudo useradd -m -U -K UID_MIN=1815 -c '$nombre' $usuario"
            ssh -i ~/.ssh/id_as_ed25519 as@"$ip" "echo '$usuario:$password' | sudo chpasswd"
            ssh -i ~/.ssh/id_as_ed25519 as@"$ip" "sudo chage -M 30 $usuario"

            echo "$usuario ha sido creado en $ip"
            echo "$usuario ha sido creado en $ip" >> "$fichlog"

        done < "$fich_usuarios"
    fi

done < "$fich_ips"


























# Modo borrado de usuarios
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
	if ! ssh -i ~/.ssh/id_as_ed25519 as@"$ip" "id $usuario" >/dev/null 2>&1; then
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

    # done < "$fich_usuarios": redirige la stdin del while al fichero "$fich_usuarios".
    done < "$fich_usuarios"
fi


