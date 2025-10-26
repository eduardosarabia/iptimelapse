#!/usr/bin/env bash

set -euo pipefail

############################
# CONFIGURACIÓN
############################
# Tu cámara
RTSP_URL="rtsp://snap:Makarr0n-KK@172.16.10.22:554/"

# Carpetas
BASE_DIR="/home/timelapse/estanque"
SNAP_DIR="$BASE_DIR/img"                      # fotos
OUT_DIR="/var/www/html/timelapse/estanque"    # vídeos

# Calidad JPG (2=alta, 31=baja)
JPG_QUALITY="${JPG_QUALITY:-2}"

# Timelapse
TL_FPS="${TL_FPS:-24}"
TL_SCALE="${TL_SCALE:-1280:-2}"   # ancho 1280, alto proporcional

# Limpieza opcional (0 = no borrar)
KEEP_DAYS="${KEEP_DAYS:-7}"

############################
# UTILIDADES
############################
need() { command -v "$1" >/dev/null 2>&1 || { echo "Falta dependencia: $1" >&2; exit 1; }; }
prepare_dirs() { mkdir -p "$SNAP_DIR" "$OUT_DIR"; }
timestamp() { date +"%Y-%m-%d_%H-%M-%S"; }

############################
# CAPTURA
############################
capture_frame() {
  need ffmpeg
  prepare_dirs
  local ts out tmp
  ts="$(timestamp)"
  out="$SNAP_DIR/${ts}.jpg"
  tmp="/tmp/frame_${RANDOM}_$$.jpg"

  ffmpeg -y -hide_banner -loglevel error \
    -rtsp_transport tcp -stimeout 5000000 \
    -i "$RTSP_URL" -frames:v 1 -q:v "$JPG_QUALITY" "$tmp"

  if [ -s "$tmp" ]; then
    mv "$tmp" "$out"
    echo "Captura OK: $out"
  else
    echo "Descarga vacía; no se guarda archivo." >&2
    rm -f "$tmp"
    exit 1
  fi
}

############################
# TIMELAPSE
############################
build_timelapse() {
  need ffmpeg
  prepare_dirs

  mapfile -t RECENTS < <(find "$SNAP_DIR" -maxdepth 1 -type f -name '*.jpg' -newermt "24 hours ago" | sort)
  if [ "${#RECENTS[@]}" -eq 0 ]; then
    echo "Sin imágenes en las últimas 24h; no se genera timelapse." >&2
    return 1
  fi

  local ts outfile workdir i name
  ts="$(date +"%Y-%m-%d_%H-00")"
  outfile="$OUT_DIR/timelapse_${ts}.mp4"

  # Directorio temporal con enlaces numerados
  workdir="$(mktemp -d /tmp/tlimgs_XXXXXX)"
  trap '[[ -n "${workdir:-}" ]] && rm -rf "$workdir"' RETURN

  i=1
  for img in "${RECENTS[@]}"; do
    printf -v name "%06d.jpg" "$i"
    ln -s -- "$img" "$workdir/$name"
    i=$((i+1))
  done

  ffmpeg -y -hide_banner -loglevel error \
    -framerate "$TL_FPS" -pattern_type glob -i "$workdir/*.jpg" \
    -vf "scale=${TL_SCALE},format=yuv420p,fps=${TL_FPS}" \
    -r "$TL_FPS" "$outfile"

  echo "Timelapse generado: $outfile"

  # Limpieza opcional
  if [ "${KEEP_DAYS}" -gt 0 ]; then
    find "$SNAP_DIR" -type f -name '*.jpg' -mtime +"$KEEP_DAYS" -delete || true
    find "$OUT_DIR" -type f -name 'timelapse_*.mp4' -mtime +"$KEEP_DAYS" -delete || true
  fi

  trap - RETURN
  unset workdir
}

usage() { echo "Uso: $0 {capture|timelapse}"; exit 1; }

############################
# ENTRADA
############################
case "${1:-}" in
  capture)    capture_frame ;;
  timelapse)  build_timelapse ;;
  *)          usage ;;
esac
