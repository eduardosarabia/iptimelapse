#!/usr/bin/env bash
# timelapse.sh
# Uso:
#   ./timelapse.sh capture      # hace una captura JPG
#   ./timelapse.sh timelapse    # genera un timelapse (últimas 24h)
# Requisitos: ffmpeg, find, sort, awk, ln

set -euo pipefail

############################
# CONFIGURACIÓN
############################
# Tu cámara
RTSP_URL="rtsp://admin:admin@102.168.1.1:554/"

# Carpetas
BASE_DIR="/home/timelapse/mycam"
SNAP_DIR="$BASE_DIR/img"                      # fotos
OUT_DIR="/var/www/html/timelapse/mycam"    # vídeos

# Calidad JPG (2=alta, 31=baja)
JPG_QUALITY="${JPG_QUALITY:-2}"

# Timelapse
TL_FPS="${TL_FPS:-24}"
TL_SCALE="${TL_SCALE:-1280:-2}"   # ancho 1280, alto proporcional

# Limpieza opcional (0 = no borrar para JPG). Los MP4 se gestionan por política de 1/día, máx 7 días.
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
# RETENCIÓN DE TIMELAPSES
# - Mantener sólo el último por cada día
# - Conservar sólo los últimos 7 días (incluyendo hoy)
############################
prune_timelapses() {
  local -A keep_date_set
  local -A latest_by_date

  # Fechas a conservar: hoy y los 6 días previos
  for i in {0..6}; do
    keep_date_set["$(date -d "$i days ago" +%Y-%m-%d)"]=1
  done

  shopt -s nullglob
  local f base datepart
  local files=("$OUT_DIR"/timelapse_*.mp4)

  # Si no hay archivos, nada que hacer
  if [ ${#files[@]} -eq 0 ]; then
    shopt -u nullglob
    return 0
  fi

  # Calcular el último archivo por cada fecha ∈ keep_date_set
  for f in "${files[@]}"; do
    base="$(basename "$f")"                              # timelapse_YYYY-MM-DD_HH-00.mp4
    datepart="${base:10:10}"                             # YYYY-MM-DD (empieza tras 'timelapse_')
    # Sólo consideramos fechas a conservar
    if [[ -n "${keep_date_set[$datepart]:-}" ]]; then
      # Mantén el "mayor" lexicográficamente (el más reciente de ese día)
      if [[ -z "${latest_by_date[$datepart]:-}" || "$base" > "${latest_by_date[$datepart]}" ]]; then
        latest_by_date["$datepart"]="$base"
      fi
    fi
  done

  # Segunda pasada: eliminar lo que no toque
  for f in "${files[@]}"; do
    base="$(basename "$f")"
    datepart="${base:10:10}"

    # Si la fecha no está en el set de 7 días -> borrar
    if [[ -z "${keep_date_set[$datepart]:-}" ]]; then
      rm -f -- "$f"
      continue
    fi

    # Si hay varios del mismo día, conserva solo el último (según nombre) y borra el resto
    if [[ "${latest_by_date[$datepart]:-}" != "$base" ]]; then
      rm -f -- "$f"
    fi
  done

  shopt -u nullglob
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
    # Aun así, aplicamos la poda de MP4 para mantener la política de 7 días
    prune_timelapses
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

  # Limpiar JPG antiguos (según KEEP_DAYS)
  if [ "${KEEP_DAYS}" -gt 0 ]; then
    find "$SNAP_DIR" -type f -name '*.jpg' -mtime +"$KEEP_DAYS" -delete || true
  fi

  # Política de MP4: 1 por día, máx 7 días (incluye hoy)
  prune_timelapses

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
