#!/bin/bash
#927838, Molino Tomé, Victor del, M, 5, B
#836304, Medina Rodriguez, Jesús Alejandro, M, 5, B

acc="$1"
fich_usuarios="$2"
fich_ips="$3"

if [ "$#" -ne 3 ]; then
    echo "Número incorrecto de parámetros"
    exit 1
fi

if [ "$acc" != "-a" ] && [ "$acc" != "-s" ]; then
    echo "Opción invalida" >&2
    exit 1
fi

fichlog="$(date +%Y_%m_%d)_user_provisioning.log"

# primera_ip: guarda la primera IP del fichero para imprimir mensajes solo una vez
primera_ip=$(head -1 "$fich_ips")

while IFS= read -r ip; do

    if [ -z "$ip" ]; then
        continue
    fi

    ssh -i ~/.ssh/id_as_ed25519 -o ConnectTimeout=5 -o BatchMode=yes as@"$ip" exit 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "$ip no es accesible"
        continue
    fi

    if [ "$acc" = "-s" ]; then

        while IFS=',' read -r usuario resto; do

            if [ -z "$usuario" ]; then
                continue
            fi

            if ! ssh -i ~/.ssh/id_as_ed25519 as@"$ip" "id $usuario" >/dev/null 2>&1; then
                continue
            fi

            # Solo imprime en la primera IP
            if [ "$ip" = "$primera_ip" ]; then
                echo "Procesando borrado de $usuario"
            fi
            echo "Procesando borrado de $usuario en $ip" >> "$fichlog"

            ssh -i ~/.ssh/id_as_ed25519 as@"$ip" "sudo mkdir -p /extra/backup && sudo tar -cf /extra/backup/${usuario}.tar -C /home $usuario"

            if [ $? -ne 0 ]; then
                continue
            fi

            ssh -i ~/.ssh/id_as_ed25519 as@"$ip" "sudo userdel -r $usuario"

        done < "$fich_usuarios"
    fi

    if [ "$acc" = "-a" ]; then

        while IFS=',' read -r usuario password nombre; do

            if [ -z "$usuario" ] || [ -z "$password" ] || [ -z "$nombre" ]; then
                # Solo imprime en la primera IP
                if [ "$ip" = "$primera_ip" ]; then
                    echo "Campo invalido"
                fi
                continue
            fi

            if ssh -i ~/.ssh/id_as_ed25519 as@"$ip" "id $usuario" >/dev/null 2>&1; then
                # Solo imprime en la primera IP
                if [ "$ip" = "$primera_ip" ]; then
                    echo "El usuario $usuario ya existe"
                fi
                echo "El usuario $usuario ya existe en $ip" >> "$fichlog"
                continue
            fi

            ssh -i ~/.ssh/id_as_ed25519 as@"$ip" "sudo useradd -m -U -K UID_MIN=1815 -c $nombre $usuario"
            ssh -i ~/.ssh/id_as_ed25519 as@"$ip" "echo $usuario:$password | sudo chpasswd"
            ssh -i ~/.ssh/id_as_ed25519 as@"$ip" "sudo chage -M 30 $usuario"

            # Solo imprime en la primera IP
            if [ "$ip" = "$primera_ip" ]; then
                echo "$usuario ha sido creado"
            fi
            echo "$usuario ha sido creado en $ip" >> "$fichlog"

        done < "$fich_usuarios"
    fi

done < "$fich_ips"