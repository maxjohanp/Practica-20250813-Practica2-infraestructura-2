#!/usr/bin/env bash
# =============================================================================
#  Pruebas de la Infraestructura 2 · Cisco ⇄ FortiGate (se ejecuta en PC-USER)
#  Seguridad de Redes · Maxyohan Montas (2025-0813)
#
#  Uso:
#    bash pruebas-infra2.sh activa   # túnel VPN arriba: el servidor DEBE responder
#    bash pruebas-infra2.sh caida    # túnel VPN abajo:  el servidor NO debe responder
#
#  El túnel se tira desde la GUI de FGT-B: Bring Down + VPN-B-A en Disabled.
#
#  En los dos casos la salida a «Internet» (20.25.8.8, con NAT) debe funcionar.
# =============================================================================
MODO="${1:-activa}"
IFACE="${IFACE:-ens4}"
SRV="10.8.13.10"     # SRV-WEB (sede del servidor, detrás de FGT-B)
INET="20.25.8.8"     # Loopback0 del ISP = «Internet» simulado

if [[ "$MODO" != "activa" && "$MODO" != "caida" ]]; then
  echo "Uso: $0 activa|caida"; exit 1
fi

verde=$'\e[32m'; rojo=$'\e[31m'; neg=$'\e[1m'; fin=$'\e[0m'
pasa=0; falla=0
resultado() {   # $1 = descripción, $2 = obtenido (si|no), $3 = esperado (si|no)
  if [[ "$2" == "$3" ]]; then
    printf '  [%sOK%s]    %s\n' "$verde" "$fin" "$1"; pasa=$((pasa+1))
  else
    printf '  [%sFALLA%s] %s\n' "$rojo" "$fin" "$1"; falla=$((falla+1))
  fi
}

[[ "$MODO" == "activa" ]] && ESPERADO="si" || ESPERADO="no"

echo "${neg}== Infraestructura 2 · pruebas desde $(hostname) · túnel: $MODO ==${fin}"
date
ip -br a show "$IFACE"
echo

echo "${neg}1. NAT (PAT del Cisco) hacia «Internet» ($INET)${fin} — debe responder siempre"
ping -c 3 -W 2 "$INET" >/dev/null 2>&1 && r=si || r=no
resultado "ping $INET responde" "$r" "si"

echo "${neg}2. Conectividad con el servidor ($SRV)${fin}"
ping -c 3 -W 2 "$SRV" >/dev/null 2>&1 && r=si || r=no
resultado "ping $SRV $( [[ $ESPERADO == si ]] && echo responde || echo 'NO responde')" "$r" "$ESPERADO"

echo "${neg}3. HTTPS al servidor${fin}"
codigo=$(curl -k -s -o /dev/null -m 6 -w '%{http_code}' "https://$SRV")
[[ "$codigo" == "200" ]] && r=si || r=no
resultado "curl https://$SRV -> código $codigo (esperado: $( [[ $ESPERADO == si ]] && echo 200 || echo 'sin respuesta'))" "$r" "$ESPERADO"

echo "${neg}4. Camino hacia el servidor (traceroute)${fin}"
traceroute -n -q 1 -w 2 -m 5 "$SRV"
echo "   Túnel activo: 10.20.25.1 (R-USERS) -> 10.25.8.13 (FGT-B por el túnel) -> $SRV"
echo "   Túnel caído : 10.20.25.1 y luego * * * (R-USERS descarta con la ruta a Null0)"

echo
echo "${neg}Resumen: $pasa OK · $falla FALLA${fin}"
date
