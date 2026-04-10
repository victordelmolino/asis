#!/bin/bash
#927838, Molino Tomé, Victor del, M, 5, B
#836304, Medina Rodriguez, Jesús Alejandro, M, 5, B

acc="$1"
fich_usuarios="$2"
fich_ips="$3"

# Comprueba si el número de parámetros es distinto de 3.
if [ "$#" -ne 3 ]; then
    echo "Número incorrecto de parámetros"
    exit 1
fi

# Comprueba que la opción es -a o -s, si no es ninguna, es inválida.
if [ "$acc" != "-a" ] && [ "$acc" != "-s" ]; then
    echo "Opción invalida" >&2
    exit 1
fi

# date +%Y_%m_%d: genera la fecha actual en formato año_mes_día.
# El fichero de log tendrá la fecha en el nombre para identificarlo.
fichlog="$(date +%Y_%m_%d)_user_provisioning.log"

# Modo creación de usuarios
if [ "$acc" = "-a" ]; then

    # while es un bucle que se ejecuta linea por linea del fichero.
    # IFS=',' : indica que los campos de las lineas se separan por comas.
    # read -r: -r lee la linea sin interpretar '\' como caracter especial.
    # IFS significa Internal Field Separator (separador de campos).
    while IFS=',' read -r usuario password nombre; do

        # Si algún campo está vacío, devolvemos "Campo invalido" y continuamos.
        # La opción -z sirve para comprobar si una cadena está vacía.
        if [ -z "$usuario" ] || [ -z "$password" ] || [ -z "$nombre" ]; then
            echo "Campo invalido"
            continue
        fi

        # primera: controla que los mensajes se impriman solo una vez,
        # ya que el usuario se procesa en múltiples máquinas.
        primera=true

        # while es un bucle que se ejecuta linea por linea del fichero de IPs.
        # IFS= : lee la línea entera sin separadores de campo.
        # read -r ip: guarda cada línea en la variable ip.
        while IFS= read -r ip; do

            if [ -z "$ip" ]; then
                continue
            fi

            # ssh: intenta conectarse a la máquina remota para comprobar si es accesible.
            # -n: evita que ssh lea stdin, necesario cuando ssh está dentro de un bucle while.
            # -i ~/.ssh/id_as_ed25519: usa la clave privada generada en la Parte 3.
            # -o ConnectTimeout=5: si no responde en 5 segundos, considera que no es accesible.
            # -o BatchMode=yes: no pide contraseña, falla directamente si no puede conectar.
            # exit: comando mínimo que ejecuta en la remota solo para probar la conexión.
            # 2>/dev/null: descarta mensajes de error para que no salgan por pantalla.
            ssh -n -i ~/.ssh/id_as_ed25519 -o ConnectTimeout=5 -o BatchMode=yes as@"$ip" exit 2>/dev/null

            # $?: código de salida del ssh. Si es distinto de 0 la máquina no es accesible.
            if [ $? -ne 0 ]; then
                echo "$ip no es accesible"
                continue
            fi

            # id "$usuario" devuelve 0 si el usuario ya existe en el sistema remoto.
            # >/dev/null: la stdout va a /dev/null; 2>&1 stderr donde stdout.
            if ssh -n -i ~/.ssh/id_as_ed25519 as@"$ip" "id $usuario" >/dev/null 2>&1; then
                if [ "$primera" = true ]; then
                    echo "El usuario $usuario ya existe"
                fi
                echo "El usuario $usuario ya existe en $ip" >> "$fichlog"
                primera=false
                continue
            fi

            # useradd: crea un usuario en el sistema remoto via SSH con sudo.
            # -m: crea /home/usuario; -U: crea un grupo con el mismo nombre del usuario.
            # -K UID_MIN=1815: indica que el UID mínimo para el usuario sea 1815.
            # -c: guarda el nombre completo del usuario.
            ssh -n -i ~/.ssh/id_as_ed25519 as@"$ip" "sudo useradd -m -U -K UID_MIN=1815 -c $nombre $usuario"

            # enviar "usuario:contraseña" a chpasswd para asignar contraseña en remoto.
            ssh -n -i ~/.ssh/id_as_ed25519 as@"$ip" "echo $usuario:$password | sudo chpasswd"

            # chage: configurar políticas de caducidad de una contraseña.
            # -M define el máximo password age (dias antes de caducar).
            ssh -n -i ~/.ssh/id_as_ed25519 as@"$ip" "sudo chage -M 30 $usuario"

            if [ "$primera" = true ]; then
                echo "$usuario ha sido creado"
            fi
            # echo "a" >> "$fich": añade en fich "a" sin dañar el resto del contenido.
            echo "$usuario ha sido creado en $ip" >> "$fichlog"
            primera=false

        # done < "$fich_ips": redirige la stdin del while al fichero de IPs.
        done < "$fich_ips"

    # done < "$fich_usuarios": redirige la stdin del while al fichero de usuarios.
    done < "$fich_usuarios"
fi

# Modo borrado de usuarios
if [ "$acc" = "-s" ]; then

    # while es un bucle que se ejecuta linea por linea del fichero.
    # IFS=',': indica que los campos de las líneas se separan por comas.
    # read usuario resto: antes del primer separador a usuario y el resto a resto.
    while IFS=',' read -r usuario resto; do

        if [ -z "$usuario" ]; then
            continue
        fi

        # while es un bucle que se ejecuta linea por linea del fichero de IPs.
        while IFS= read -r ip; do

            if [ -z "$ip" ]; then
                continue
            fi

            # Comprueba si la máquina es accesible antes de operar en ella.
            ssh -n -i ~/.ssh/id_as_ed25519 -o ConnectTimeout=5 -o BatchMode=yes as@"$ip" exit 2>/dev/null
            if [ $? -ne 0 ]; then
                echo "$ip no es accesible"
                continue
            fi

            # id "$usuario" devuelve 0 si el usuario existe en el sistema remoto.
            # Si no existe, continuamos con la siguiente máquina.
            if ! ssh -n -i ~/.ssh/id_as_ed25519 as@"$ip" "id $usuario" >/dev/null 2>&1; then
                continue
            fi

            echo "Procesando borrado de $usuario"
            echo "Procesando borrado de $usuario en $ip" >> "$fichlog"

            # tar: crea un backup del home del usuario en la máquina remota.
            # -c: crear un archivo .tar; -f: nombre del archivo.
            # -C /home "$usuario": copia /home/usuario dentro del archivo tar.
            ssh -n -i ~/.ssh/id_as_ed25519 as@"$ip" "sudo mkdir -p /extra/backup && sudo tar -cf /extra/backup/${usuario}.tar -C /home $usuario"

            # $?: si tar da error, evita borrar un usuario sin haber guardado su backup.
            if [ $? -ne 0 ]; then
                continue
            fi

            # userdel: elimina el usuario del sistema remoto.
            # -r: también borra su directorio home y su correo del sistema.
            ssh -n -i ~/.ssh/id_as_ed25519 as@"$ip" "sudo userdel -r $usuario"

        # done < "$fich_ips": redirige la stdin del while al fichero de IPs.
        done < "$fich_ips"

    # done < "$fich_usuarios": redirige la stdin del while al fichero de usuarios.
    done < "$fich_usuarios"
fi