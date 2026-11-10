#!/usr/bin/env bash
# PNG 후처리 (태스크 14 / png-prompts.md 11장).
#
# raw/ 에 Midjourney에서 뽑은 PNG를 넣고 이 스크립트를 한 번 실행하면
#   1. 마젠타 배경 제거 (chromakey 0xFF00FF)
#   2. 균일 축소 (캔버스 규격별로 같은 배율 — 파츠끼리 비례가 맞아야 한다)
#   3. assets/sprites/ 규칙대로 배치
# 까지 끝난다. 파일명은 png-prompts.md 4장의 표와 정확히 같아야 한다(코드가 이
# 이름으로 찾는다).
#
# 원점 규칙(png-prompts.md 2장) 때문에 잘라내지 않는다. 관절 중심 파츠는 캔버스
# 정중앙이 연결점이므로, 균일 축소하면 중심이 그대로 유지되고 원점이 깨지지 않는다.
#
# 그림은 아직 도착하지 않았을 수 있다. raw/ 가 없거나 비어 있으면 경고만 하고
# 종료 코드는 0으로 둔다 — 파츠가 하나도 없어 후처리할 일이 없는 것은 실패가 아니다.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RAW="$ROOT/raw"
OUT="$ROOT/assets/sprites"

mkdir -p "$OUT/seal" "$OUT/mom" "$OUT/enemies" "$OUT/hazards" "$OUT/env" "$OUT/ui"

# 마젠타 키 (png-prompts.md 11.1). 유사도 0.22, 블렌드 0.04.
CHROMA="chromakey=0xFF00FF:0.22:0.04"

# process <입력> <출력> <규격>
# 규격은 정사각 캔버스가 "64", 직사각형이 "512x288".
process() {
    local in="$1" out="$2" spec="$3"
    local scale
    if [[ "$spec" == *x* ]]; then
        scale="${spec%%x*}:${spec##*x}"
    else
        scale="${spec}:${spec}"
    fi
    ffmpeg -y -loglevel error -i "$in" \
        -vf "${CHROMA},scale=${scale}:flags=lanczos,format=rgba" "$out"
}

# 배치 목록: <파일명> <대상 디렉터리> <규격>
# 128 캔버스 파츠는 64로, 256 캔버스 파츠는 128로 줄인다 (png-prompts.md 11.2).
PARTS=(
    # 4.1 새끼 물범 파츠 (8종) — 관절 중심, 128 → 64
    "baby_tail           seal      64"
    "baby_body           seal      64"
    "baby_belly          seal      64"
    "baby_flipper_back   seal      64"
    "baby_flipper_front  seal      64"
    "baby_head           seal      64"
    "baby_face           seal      64"
    "baby_whiskers       seal      64"
    # 4.2 엄마 물범 파츠 (3종) — 관절 중심, 256 → 128
    "mom_body            mom       128"
    "mom_head            mom       128"
    "mom_flipper         mom       128"
    # 4.3 적 (4종) — 도형 중심, 128 → 64
    "seagull_1           enemies   64"
    "seagull_2           enemies   64"
    "crab_1              enemies   64"
    "crab_2              enemies   64"
    # 4.4 위험 요소 (3종) — 도형 중심, 128 → 64
    "thin_ice            hazards   64"
    "ice_block           hazards   64"
    "icicle              hazards   64"
    # 4.5 환경 (5종) — 타일은 128 → 64, 배경은 1024×576 → 512×288
    "ground_tile         env       64"
    "platform_tile       env       64"
    "background_far      env       512x288"
    "mom_floe            env       128"
    "fish                env       64"
    # 4.6 UI (1종) — 도형 중심, 128 → 64
    "heart               ui        64"
)

# raw/ 가 없으면 처리할 것이 없다는 뜻이므로, 여기서 끝낸다.
if [[ ! -d "$RAW" ]]; then
    echo "WARNING: $RAW 가 없다. png-prompts.md 프롬프트로 뽑은 PNG를 raw/ 에 넣고 다시 실행해라." >&2
    echo "==> 후처리된 파일 0개 (그림 미도착)"
    exit 0
fi

made=0
missing=()
for entry in "${PARTS[@]}"; do
    read -r name dir spec <<<"$entry"
    src="$RAW/${name}.png"
    if [[ ! -f "$src" ]]; then
        missing+=("$name")
        continue
    fi
    process "$src" "$OUT/${dir}/${name}.png" "$spec"
    made=$((made + 1))
done

if (( made == 0 )); then
    echo "WARNING: $RAW 에 처리할 PNG가 없다 (${#missing[@]}개 부재)." >&2
    echo "==> 후처리된 파일 0개 (그림 미도착)"
    exit 0
fi

if (( ${#missing[@]} > 0 )); then
    echo "WARNING: 아직 도착하지 않은 파츠 ${#missing[@]}개: ${missing[*]}" >&2
fi

# 결과물 목록과 규격. 파츠가 규격대로 줄었는지를 여기서 확인한다.
echo "==> 후처리된 파일 ${made}개 / 전체 ${#PARTS[@]}개"
total=0
for d in seal mom enemies hazards env ui; do
    for f in "$OUT/$d"/*.png; do
        [[ -e "$f" ]] || continue
        dims="$(ffprobe -v error -select_streams v:0 \
            -show_entries stream=width,height -of csv=p=0 "$f" | tr -d '\r')"
        printf "    %-28s %s\n" "sprites/${d}/$(basename "$f")" "$dims"
        total=$((total + 1))
    done
done
echo "==> assets/sprites/ 에 PNG ${total}개"
