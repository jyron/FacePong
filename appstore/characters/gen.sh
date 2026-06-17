#!/bin/bash
# Generates the FacePong CPU-character lookalike portraits in parallel via Nano Banana Pro,
# then runs each through the macOS Vision cutout tool to produce the transparent head paddle.
set -u
cd "$(dirname "$0")/.."
GEN="python3 gemini_generate.py"
CUT="../ios/tools/facecutout"
RAW="characters/raw"
CUTD="characters/cut"
mkdir -p "$RAW" "$CUTD"
export AR=1:1

gen() {
  local id="$1"; shift
  local prompt="$1"; shift
  AR=1:1 $GEN "$RAW/$id.png" "$prompt" >/dev/null 2>&1 && echo "GEN OK $id" || echo "GEN FAIL $id"
}

gen singer "A photorealistic high-resolution studio portrait of a beautiful 27-year-old American blonde female pop superstar. Long sleek honey-blonde hair with side-swept bangs, smooth tanned skin, sparkling light-brown eyes, glossy lips, a bright playful flirty smile, smoky eye makeup. She wears a glittery low-cut crop top and a tiny headset microphone curving toward her cheek. Glamorous early-2000s pop princess look. Head and shoulders centered, facing the camera, plain light grey seamless backdrop, bright glamour studio lighting, ultra detailed, sharp focus." &
gen king "A photorealistic high-resolution studio portrait of a handsome 30-year-old American rock-and-roll heartthrob from the 1950s. Glossy jet-black pompadour with a loose curl over the forehead, long thick black sideburns, smooth pale skin, dreamy heavy-lidded eyes, a charming lopsided lip-curl smirk, full lips. He wears a white jacket with a popped collar and rhinestones. Iconic vintage rockabilly king-of-rock look. Head and shoulders centered, facing the camera, plain light grey seamless backdrop, dramatic warm spotlight, ultra detailed, sharp focus." &
gen tycoon "A photorealistic high-resolution studio portrait of a 72-year-old American business tycoon and politician. Distinctive elaborate swept-back blond-orange combover hairstyle, orange spray-tanned skin with notably paler skin around the eyes, small pursed downturned mouth, squinting light blue eyes, jowly heavy cheeks, a serious self-important expression. He wears a dark navy suit, a crisp white shirt, and a very long bright red satin necktie. Powerful boardroom mogul look. Head and shoulders centered, facing the camera straight on, plain light grey seamless backdrop, even studio lighting, ultra detailed, sharp focus." &
gen founder "A photorealistic high-resolution studio portrait of a 50-year-old tech-billionaire entrepreneur. Short dark-brown hair receding at the temples with a fuller styled crown, faint stubble, fair slightly ruddy skin, hooded hazel eyes, a slightly awkward tight-lipped half-smile, rounded chin. He wears a plain fitted black t-shirt. Confident eccentric-genius founder look. Head and shoulders centered, facing the camera, plain light grey seamless backdrop, even studio lighting, ultra detailed, sharp focus." &
gen interesting "A photorealistic high-resolution studio portrait of a distinguished suave 67-year-old man, the epitome of worldly sophistication, like a famous imported-beer commercial spokesman. Thick silver-grey hair swept back, a full immaculately groomed salt-and-pepper grey beard and mustache, tanned weathered ruggedly handsome face, twinkling confident eyes, a subtle knowing smile, strong brow. He wears an elegant black tuxedo with a black bow tie. Debonair charismatic gentleman-adventurer look. Head and shoulders centered, facing the camera, plain light grey seamless backdrop, warm cinematic lighting, ultra detailed, sharp focus." &
gen wrestler "A photorealistic high-resolution studio portrait of a huge muscular 55-year-old American professional wrestler. Bald on top with long bleached platinum-blond hair flowing at the sides, a thick blond horseshoe handlebar mustache, deeply tanned leathery skin, intense wild eyes, a red-and-yellow bandana headband, gold hoop earrings. He wears a torn yellow tank top revealing enormous muscular tanned arms. Iconic 1980s wrestling-legend look. Head and shoulders centered, facing the camera, plain light grey seamless backdrop, dramatic hard lighting, ultra detailed, sharp focus." &
gen champ "A photorealistic high-resolution studio portrait of a powerful 30-year-old African-American heavyweight boxing champion. Clean-shaved head, extremely muscular thick neck, intense intimidating glare, a small gap between the front teeth, a bold black tribal tattoo curving around the left side of his face near the eye, dark brown skin, a slight menacing scowl. He wears a plain black tank top. Ferocious undefeated-champion look. Head and shoulders centered, facing the camera, plain light grey seamless backdrop, hard dramatic lighting, ultra detailed, sharp focus." &
gen dictator "A photorealistic high-resolution studio portrait of a stern 67-year-old Eastern-European male head of state. Thin receding light grey-blond hair neatly combed to the side, pale cold complexion, piercing pale blue-grey eyes, a hard flat expressionless mouth, a broad forehead, clean-shaven, faintly puffy cheeks. He wears a charcoal-grey suit, a white shirt, and a muted dark tie. Cold calculating ruthless authoritarian look. Head and shoulders centered, facing the camera straight on, plain light grey seamless backdrop, flat even lighting, ultra detailed, sharp focus." &
gen player "A photorealistic high-resolution casual selfie-style studio portrait of a friendly ordinary 30-year-old man with short tidy brown hair, light stubble, brown eyes, and a relaxed warm smile, wearing a plain heather-grey crew-neck t-shirt. Head and shoulders centered, facing the camera, plain light grey seamless backdrop, soft even lighting, ultra detailed, sharp focus." &

wait
echo "=== ALL GENERATION DONE ==="
ls -la "$RAW"
