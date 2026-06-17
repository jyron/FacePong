#!/bin/bash
# Builds V1 "WORLD WAR PONG" (visual). faceoff card -> live Obama-vs-Putin rally
# with timed captions -> slow-mo money shot -> VICTORY stamp -> endcard.
set -e
cd "$(dirname "$0")/promo_video/tiktok"
CAP=gameplay/war_capture.mov; CARDS=cards; WK=work; OUT=final; mkdir -p "$WK" "$OUT"
W=1080; H=1920; FPS=30
VENC=(-c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -r $FPS)
GPCROP="scale=$W:-2,crop=$W:$H:0:213,setsar=1,fps=$FPS"
FF=(ffmpeg -y -loglevel error -nostdin)

"${FF[@]}" -loop 1 -t 2.4 -i "$CARDS/war_faceoff.png" \
 -vf "scale=1188:2112,zoompan=z='min(1+0.0013*on,1.10)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=${W}x${H}:fps=$FPS,fade=t=in:st=0:d=0.3,setsar=1" "${VENC[@]}" -an "$WK/war_s1.mp4"

"${FF[@]}" -ss 7.0 -t 2.2 -i "$CAP" -i "$CARDS/war_cap_reveal.png" \
 -filter_complex "[0:v]$GPCROP[g];[g][1:v]overlay=0:0,format=yuv420p[v]" -map "[v]" "${VENC[@]}" -an "$WK/war_s2.mp4"

"${FF[@]}" -ss 9.4 -t 1.0 -i "$CAP" -i "$CARDS/war_cap_money.png" \
 -filter_complex "[0:v]$GPCROP,setpts=2.0*PTS[g];[g][1:v]overlay=0:0,format=yuv420p[v]" -map "[v]" "${VENC[@]}" -an "$WK/war_s3.mp4"

"${FF[@]}" -ss 11.0 -t 2.0 -i "$CAP" -i "$CARDS/war_cap_final.png" \
 -filter_complex "[0:v]$GPCROP[g];[g][1:v]overlay=0:0,format=yuv420p[v]" -map "[v]" "${VENC[@]}" -an "$WK/war_s4.mp4"

"${FF[@]}" -ss 13.0 -i "$CAP" -frames:v 1 "$WK/war_freeze.png"
"${FF[@]}" -loop 1 -t 1.7 -i "$WK/war_freeze.png" -i "$CARDS/war_winner.png" \
 -filter_complex "[0:v]$GPCROP[g];[g][1:v]overlay=0:0,fade=t=in:st=0:d=0.15,format=yuv420p[v]" -map "[v]" "${VENC[@]}" -an "$WK/war_s5.mp4"

"${FF[@]}" -loop 1 -t 2.3 -i "$CARDS/endcard.png" \
 -vf "scale=$W:$H,fade=t=in:st=0:d=0.3,fade=t=out:st=2.0:d=0.3,setsar=1,fps=$FPS" "${VENC[@]}" -an "$WK/war_s6.mp4"

printf "file '%s'\n" war_s1.mp4 war_s2.mp4 war_s3.mp4 war_s4.mp4 war_s5.mp4 war_s6.mp4 > "$WK/war_list.txt"
"${FF[@]}" -f concat -safe 0 -i "$WK/war_list.txt" -c copy "$OUT/facepong-tiktok-war-mute.mp4"
echo "=== built ==="; ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT/facepong-tiktok-war-mute.mp4"
ffmpeg -v error -i "$OUT/facepong-tiktok-war-mute.mp4" -f null - && echo "integrity OK"
for t in 1.0 3.2 5.2 7.2 9.6; do "${FF[@]}" -ss $t -i "$OUT/facepong-tiktok-war-mute.mp4" -frames:v 1 "/tmp/v1_$t.png"; done
echo DONE
