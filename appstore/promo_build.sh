#!/bin/bash
# Builder for the FacePong talking-head UGC promo. Assembles, for a given KEY,
# from assets following this naming convention:
#   promo_video/clips/<KEY>_c1.mp4        Veo: girl hook ("...so I made him play THIS")
#   promo_video/clips/<KEY>_c3.mp4        Veo: girl payoff
#   promo_video/work/<KEY>_photo.png      connection card (face -> paddle, on a phone)
#   promo_video/gameplay/<KEY>_capture.mov  REAL gameplay screen-recording (1206x2622, silent)
#   promo_video/work/<KEY>_cap{1..5}.png  transparent TikTok caption overlays
#   promo_video/work/endcard.png          branded outro (shared)
# Audio is fully diegetic: Veo speech on hook/payoff, a FacePong paddle-bounce bed
# on the (silent) gameplay, a fanfare sting on the endcard. No external music.
# Output: promo_video/final/facepong-<KEY>.mp4
# Usage:  bash appstore/promo_build.sh <KEY>
set -e
cd "$(dirname "$0")"
KEY="${1:?usage: promo_build.sh <KEY>}"
W=1080; H=1920; FPS=30
CL=promo_video/clips; WK=promo_video/work; GP=promo_video/gameplay; OUT=promo_video/final
SFX=/Users/jyron/src/facepong/ios/FacePong/Resources/sfx
VENC=(-c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p)
AENC=(-c:a aac -b:a 192k -ar 48000 -ac 2)
LOUD="loudnorm=I=-14:TP=-1.5:LRA=11"

# Gameplay crop: scale capture to 1080 wide, take a 1920-tall window at GP_TOP px
# down (keeps the top HUD + both face paddles, drops the empty bottom). Tunable.
GP_TOP="${GP_TOP:-80}"
GPCROP="scale=$W:-2,crop=$W:$H:0:$GP_TOP,setsar=1"
GP_SS="${GP_SS:-3.0}"        # seconds into the capture to start the 5.5s gameplay window
# Veo trims (land on the clean spoken line; openers clip easily -> start a touch early)
C1_SS="${C1_SS:-0.6}"; C1_DUR="${C1_DUR:-4.8}"
C3_SS="${C3_SS:-0.8}"; C3_DUR="${C3_DUR:-4.0}"

# --- seg1: hook (Veo speech) + cap1, fade in ---
ffmpeg -y -loglevel error -ss "$C1_SS" -t "$C1_DUR" -i $CL/${KEY}_c1.mp4 -i $WK/${KEY}_cap1.png \
  -filter_complex "[0:v]scale=$W:$H,fps=$FPS,setsar=1,fade=t=in:st=0:d=0.4[s];[s][1:v]overlay=0:0[vo]" \
  -map "[vo]" -map 0:a -af "$LOUD,aresample=48000" "${VENC[@]}" "${AENC[@]}" $WK/${KEY}_seg1.mp4
echo "built seg1 (hook)"

# (no static connection card — the hook cuts STRAIGHT into live gameplay; the
#  face->paddle connection is carried by a caption over the moving gameplay.)

# --- pong-bounce bed for the (silent) 5.5s gameplay window ---
# Real FacePong paddle/wall sounds placed on a rally rhythm; a milestone ding near
# the end. Tune TIMES to the chosen window if a bounce looks out of sync.
PT="${PONG_TIMES:-300 760 1180 1640 2080 2520 2980 3420 3880 4360 4880}"
PF="${PONG_FILES:-paddle wall paddle paddle wall paddle paddle wall paddle paddle paddle}"
read -ra TIMES <<< "$PT"; read -ra FILES <<< "$PF"
INS=(); FC=""; MIX=""
for i in "${!TIMES[@]}"; do
  INS+=(-i "$SFX/${FILES[$i]}.wav")
  FC+="[$i:a]adelay=${TIMES[$i]}|${TIMES[$i]},volume=1.7[s$i];"; MIX+="[s$i]"
done
# milestone ding
mi=${#TIMES[@]}; INS+=(-i "$SFX/milestone.wav")
FC+="[$mi:a]adelay=4300|4300,volume=1.3[s$mi];"; MIX+="[s$mi]"
ffmpeg -y -loglevel error "${INS[@]}" -filter_complex \
  "${FC}${MIX}amix=inputs=$((mi+1)):normalize=0,apad,atrim=0:5.5,$LOUD,aresample=48000[a]" \
  -map "[a]" -t 5.5 "${AENC[@]}" $WK/${KEY}_pongbed.m4a
echo "built pong bed"

# --- seg3: REAL gameplay + cap3 (early) + cap4 (late) + pong bed ---
ffmpeg -y -loglevel error -ss $GP_SS -t 5.5 -i $GP/${KEY}_capture.mov -i $WK/${KEY}_pongbed.m4a \
  -i $WK/${KEY}_cap3.png -i $WK/${KEY}_cap4.png -filter_complex \
  "[0:v]$GPCROP,fps=$FPS[s];\
   [s][2:v]overlay=0:0:enable='between(t,0,2.6)'[t1];\
   [t1][3:v]overlay=0:0:enable='between(t,2.6,5.5)',format=yuv420p[vo]" \
  -map "[vo]" -map 1:a "${VENC[@]}" "${AENC[@]}" -shortest $WK/${KEY}_seg3.mp4
echo "built seg3 (gameplay)"

# --- seg4: payoff (Veo speech) + cap5 ---
ffmpeg -y -loglevel error -ss "$C3_SS" -t "$C3_DUR" -i $CL/${KEY}_c3.mp4 -i $WK/${KEY}_cap5.png \
  -filter_complex "[0:v]scale=$W:$H,fps=$FPS,setsar=1[s];[s][1:v]overlay=0:0[vo]" \
  -map "[vo]" -map 0:a -af "$LOUD,aresample=48000" "${VENC[@]}" "${AENC[@]}" $WK/${KEY}_seg4.mp4
echo "built seg4 (payoff)"

# --- segE: endcard + fanfare sting ---
ENDCARD=$WK/endcard.png; [ -f "$WK/${KEY}_endcard.png" ] && ENDCARD=$WK/${KEY}_endcard.png
ffmpeg -y -loglevel error -loop 1 -t 3 -i $ENDCARD -i $SFX/fanfare.wav \
  -filter_complex "[0:v]scale=$W:$H,fps=$FPS,setsar=1,fade=t=in:st=0:d=0.3,fade=t=out:st=2.5:d=0.5[vo];\
   [1:a]volume=0.8,$LOUD,aresample=48000,apad[a]" \
  -map "[vo]" -map "[a]" "${VENC[@]}" "${AENC[@]}" -t 3 $WK/${KEY}_segE.mp4
echo "built segE (endcard)"

mkdir -p $OUT
ffmpeg -y -loglevel error \
  -i $WK/${KEY}_seg1.mp4 -i $WK/${KEY}_seg3.mp4 -i $WK/${KEY}_seg4.mp4 -i $WK/${KEY}_segE.mp4 \
  -filter_complex "[0:v][0:a][1:v][1:a][2:v][2:a][3:v][3:a]concat=n=4:v=1:a=1[v][a]" \
  -map "[v]" -map "[a]" "${VENC[@]}" "${AENC[@]}" -movflags +faststart $OUT/facepong-${KEY}.mp4
echo "DONE -> $OUT/facepong-${KEY}.mp4"
ffprobe -v error -show_entries format=duration:stream=width,height,codec_type $OUT/facepong-${KEY}.mp4 2>/dev/null | grep -E "width|height|duration" | head -5
