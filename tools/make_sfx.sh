#!/usr/bin/env bash
# 사운드 5종을 ffmpeg 로 합성한다 (설계 11장). 외부 에셋이 필요 없다.
#
#   tone <출력이름> <주파수> <길이>
#     - 10ms 페이드 인, 20ms 페이드 아웃으로 클릭 노이즈를 없앤다.
#     - 볼륨 0.5. 5종이 겹쳐 들려도 찢어지지 않는 여유를 둔다.
#   arrive 는 4음 상승 아르페지오(C5·E5·G5·C6)를 이어 붙인다.
set -euo pipefail

FFMPEG="${FFMPEG:-/Users/nixos/.nix-profile/bin/ffmpeg}"

mkdir -p assets/sfx
tone() {  # tone <이름> <주파수> <길이>
    "$FFMPEG" -y -loglevel error -f lavfi -i "sine=frequency=$2:duration=$3" \
        -af "afade=t=in:st=0:d=0.01,afade=t=out:st=$(python3 -c "print(max(0.01,$3-0.03))"):d=0.02,volume=0.5" \
        "assets/sfx/$1.wav"
}
tone jump        520 0.12
tone swat        300 0.15
tone enemy_down  700 0.10
tone hurt        180 0.20
"$FFMPEG" -y -loglevel error \
    -f lavfi -i "sine=frequency=523:duration=0.15" \
    -f lavfi -i "sine=frequency=659:duration=0.15" \
    -f lavfi -i "sine=frequency=784:duration=0.15" \
    -f lavfi -i "sine=frequency=1046:duration=0.15" \
    -filter_complex "[0][1][2][3]concat=n=4:v=0:a=1,volume=0.5" \
    assets/sfx/arrive.wav
