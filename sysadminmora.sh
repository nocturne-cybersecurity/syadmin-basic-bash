#!/usr/bin/env bash
set -euo pipefail

REPORTE="auditoria_$(date +%F).md"
CONTENEDOR="nginx"
PUERTO=8080

mkdir -p auditoria
REPORTE="auditoria/auditoria_$(date +%F).md"

if [[ ! -f "$REPORTE" ]]; then
    {
        echo "Pproyecto Linux en accion"
        echo
        echo "- fecha: $(date)"
        echo "- equipo: $(hostname)"
        echo
        echo "| comprobacion | resultado |"
        echo "|---|---|"
    } > "$REPORTE"
fi

registrar() {
    echo "| $1 | $2 |" >> "$REPORTE"
}

fallo() {
    echo "Ocurrió un error en $1"
}
trap 'fallo "$LINENO"' ERR

pausa() {
    read -r -p "Presiona Enter para volver al menú..." _
}

disco() {
    echo
    echo "espacio en disco:"
    df -h
    registrar "disco" "consulta disco"
}

memoria() {
    echo
    echo "memoria RAM:"
    free -h
    registrar "memoria" "consulta memoria"
}

servicios() {
    echo
    echo "servicios y puertos:"
    if systemctl is-active --quiet ssh; then
        echo "SSH esta activo"
        registrar "SSH" "activo"
    else
        resultado=$?
        echo "Open SSH no esta activo o no está instalado"
        registrar "SSH" "inactivo o no disponible (err: $resultado)"
    fi

    ss -tuln
    registrar "puertos" "consulta realizada"
}

seguridad() {
    echo
    echo "revision basica de SSH (solo lectura obvio)"
    for archivo in "$HOME/.ssh" /etc/ssh/sshd_config; do
        if [[ -e "$archivo" ]]; then
            stat -c '%A %a %n' "$archivo"
            registrar "permisos: $archivo" "$(stat -c '%a' "$archivo")"
        else
            echo "no se encontro: $archivo"
            registrar "permisos: $archivo" "no encontrado"
        fi
    done

    if [[ -r /etc/ssh/sshd_config ]]; then
        grep -Ei '^[[:space:]]*(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication)' \
            /etc/ssh/sshd_config || true
    fi
    echo "no se cambio ninguna configuracion"
}

nginx() {
    echo
    if ! command -v podman >/dev/null 2>&1; then
        echo "bo encontré Podman. instalalo para usar esta opcion"
        registrar "Nginx" "podman no está instalado"
        return 0
    fi

    if podman container exists "$CONTENEDOR"; then
        echo "el contenedor $CONTENEDOR ya existe"
        echo "Si ya esta detenido, puedes iniciarlo con:"
        echo "podman start $CONTENEDOR"
        registrar "Nginx" "El contenedor ya existe"
        return 0
    fi

    if podman run -d --name "$CONTENEDOR" -p "$PUERTO:80" nginx:alpine; then
        echo "nginx se inicio en http://localhost:$PUERTO"
        registrar "nginx" "contenedor iniciado en puerto $PUERTO"
    else
        resultado=$?
        echo "no se pudo iniciar Nginx (codigo $resultado)."
        registrar "Nginx" "error al iniciar (código $resultado)"
        return 0
    fi

    if curl --fail --silent --show-error --max-time 5 "http://localhost:$PUERTO/" >/dev/null; then
        echo "la pagnia respondio correctamente"
        registrar "HTTP" "Respuesta correcta"
    else
        resultado=$?
        echo "Nginx arranco chido, pero no pude confirmar la respuesta de la soclicitud HTTP"
        registrar "HTTP" "No respondio (código $resultado)"
    fi
}

while true; do
    clear
    echo "Administrador del sistema Linux Morasys xd"
    echo
    echo "1) Revisar disco"
    echo "2) Revisar memoria"
    echo "3) Revisar SSH y puertos"
    echo "4) Revisar permisos de SSH"
    echo "5) Iniciar Nginx de prueba"
    echo "6) Hacer un rm -rf /"
    echo "0) Salir"
    echo
    read -r -p "Elige una opcion o que: " opcion

    case "$opcion" in
        1) disco; pausa ;;
        2) memoria; pausa ;;
        3) servicios; pausa ;;
        4) seguridad; pausa ;;
        5) nginx; pausa ;;
        0) echo "Reporte guardado en $REPORTE"; break ;;
        *) echo "Esa opción no existe tonto (menos tu mora)"; pausa ;;
    esac
done
