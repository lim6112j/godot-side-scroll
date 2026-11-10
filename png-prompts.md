# PNG 프롬프트 — 새끼 물범 파츠 (Midjourney)

횡스크롤 게임 **《엄마에게》**의 모든 그림을 수동으로 뽑기 위한 프롬프트 모음입니다.
한 번에 전부 뽑지 말고 **Step 1 → Step 2 → Step 3** 순서로 가야 그림이 서로 맞습니다.

- Step 1: 마스터 캐릭터 시트 1장을 뽑는다 (이후 모든 파츠의 기준)
- Step 2: 파츠별 프롬프트를 `--cref`로 마스터에 고정해서 뽑는다
- Step 3: 후처리(배경 제거 → 리사이즈 → 파일명 정리)로 게임에 넣을 상태로 만든다

---

## 0. Midjourney의 두 가지 한계와 대응

뽑기 전에 알아둘 것. 이걸 모르면 파츠가 서로 안 맞아서 다시 뽑게 됩니다.

**한계 1 — 투명 배경을 직접 못 만든다.**
Midjourney는 PNG를 주지만 알파 채널(투명)이 없는 단색 배경으로 나옵니다.
대응: 모든 프롬프트에 **마젠타 단색 배경(`#FF00FF`)** 을 명시합니다. 게임 씬에 마젠타가 등장하지 않으므로 안전하고, 후처리에서 `ffmpeg chromakey`로 정확히 잘려나갑니다(3장 참고).

**한계 2 — 파츠를 따로 뽑으면 생김체가 흔들린다.**
한 프롬프트에서 꼬리만, 다른 프롬프트에서 머리만 뽑으면 전혀 다른 물범이 됩니다.
대응: Step 1에서 뽑은 **마스터 이미지의 URL을 모든 파츠 프롬프트에 `--cref`로 걸고**, `--cw 100`(캐릭터 가중치 최대)과 **동일한 `--seed`** 를 씁니다. 팔레트 hex는 `--cref`가 복제하지 못하므로 프롬프트에 매번 직접 적습니다.

---

## 1. 공통 설정

### 스타일 서픽스 (모든 프롬프트 맨 끝에 그대로 붙임)

```
flat 2D cartoon game sprite, side profile, thick clean dark outline (#2B3A47), soft two-tone cel shading, rounded friendly shapes, cute stylized, arctic ice palette, crisp vector-like edges, solid flat magenta background (#FF00FF), no gradient in background, no text, no watermark, no drop shadow, no ground, no props
```

### 팔레트 (프롬프트에 hex 그대로 인용)

| 역할 | Hex |
|---|---|
| 새끼 물범 몸통 라이트 | `#E8EEF2` |
| 새끼 물범 몸통 섀도 | `#A9BCCB` |
| 새끼 물범 배 | `#FBFDFF` |
| 지느러미 | `#C9D6E2` |
| 눈·코·윤곽선 | `#2B3A47` |
| 홍조 | `#F2A2A2` |
| 엄마 물범 라이트 | `#F5E9DC` |
| 엄마 물범 섀도 | `#D9C3AE` |
| 엄마 물범 윤곽선 | `#4A3B33` |
| 하늘 | `#BFE3F5` → `#EAF6FB` |
| 얼음·눈 지면 | `#DCEBF5` |
| 얼음 섀도 | `#7FA8C0` |
| 깊은 물 | `#2E6E8E` |

### 공통 파라미터

| 파라미터 | 값 | 이유 |
|---|---|---|
| `--ar 1:1` | 파츠용 | 정사각 캔버스에 원점 규칙이 가장 단순 |
| `--ar 16:9` | 마스터 시트·배경용 | |
| `--cref <MASTER_URL>` | 파츠 전부 | 캐릭터 고정 |
| `--cw 100` | 파츠 전부 | 최대 일관성 |
| `--seed 12345` | 전부 동일 | 스타일 흔들림 방지 |
| `--stylize 80~150` | 낮을수록 프롬프트 충실 | 팔레트가 새는 걸 막음 |
| `--v 7` (또는 `--v 6.1`) | | |

`<MASTER_URL>` 은 Step 1에서 네가 고른 이미지의 URL로 치환합니다.

---

## 2. 원점 규칙 (이게 제일 중요)

게임에서는 파츠를 **관절 위치에 붙여서 회전**시킵니다. 그래서 그림의 원점이 어디인지가 맞아야 코드에서 오프셋을 만지작거리지 않습니다.

**규칙 A — 관절 중심 파츠** (새끼 물범 전 부위, 엄마 물범 전 부위)

캔버스 128×128. **연결점(관절)이 이미지 정중앙(64, 64)** 에 오게 그리고, 부위는 그 점에서 뻗어 나가게 합니다. 중심으로부터 반경 60px 안에 다 들어와야 합니다.

**규칙 B — 도형 중심 파츠** (적, 고드름, 물고기, 타일)

캔버스 규격은 개별 표 참고. **물체의 시각적 중심이 캔버스 정중앙**에 오게 합니다. 고드름처럼 매달린 것은 규칙 A처럼 **꼭대기가 중심**에 옵니다(표에 별도 표기).

**규칙 C — 원점 공유** (머리·얼굴·수염)

`head`, `face`, `whiskers`는 셋 다 **목 연결점을 정중앙에** 둡니다. 게임에서 세 노드를 같은 좌표에 쌓으므로, 원점이 같아야 얼굴이 머리에 정확히 붙습니다.

---

## 3. Step 1 — 마스터 캐릭터 시트

아기 물범의 기준이 되는 한 장입니다. 4칸 시트로 뽑고, 그중 가장 깔끔한 한 칸을 잘내어 `--cref`에 씁니다.

```
A cute cartoon baby harp seal character design sheet, flat 2D game art style, four views arranged in one row: side profile facing right, front view, back view, three-quarter view, thick clean dark outline (#2B3A47), soft two-tone cel shading, pale blue-white fur (#E8EEF2) with shadow (#A9BCCB), big round glossy eyes, tiny front flippers, fan-shaped hind tail flippers, small whiskers, round friendly body, arctic snow palette, crisp vector-like shapes, solid flat magenta background (#FF00FF), no text, no watermark, no gradient background --ar 16:9 --v 7 --stylize 120
```

고른 뒤 할 일:

1. 시트에서 **측면(side profile facing right)** 칸만 잘낸다
2. 이 이미지를 Midjourney에 올려 URL을 확보한다 → `<MASTER_URL>`
3. `--seed` 는 시트 뽑은 값 그대로 파츠에도 쓴다

---

## 4. 파츠 사양표

게임에 들어가는 최종 규격. 여기 적힌 **인게임 크기**가 Godot에서의 실제 표시 크기이고, PNG는 그보다 크게 뽑아서 후처리로 줄입니다.

### 4.1 새끼 물범 파츠 (8종)

| 파일명 | 부위 | 원점 | 캔버스 | 인게임 크기 | 뻗는 방향 / 비고 |
|---|---|---|---|---|---|
| `baby_tail.png` | 꼬리 + 뒷지느러미 | 꼬리뿌리(골반) | 128 | 40×24 | 왼쪽(뒤)으로 부채꼴 펼침 |
| `baby_body.png` | 몸통 | 몸통 중심 | 128 | 48×32 | 등이 위로 둥글게 |
| `baby_belly.png` | 배 | 몸통 중심 | 128 | 44×20 | 몸통 **아래·앞쪽**에 겹쳐 깔림 |
| `baby_flipper_back.png` | 뒷 앞지느러미 | 어깨 | 128 | 20×14 | 왼쪽·아래. `flipper_front`보다 어둡고 탁하게 |
| `baby_flipper_front.png` | 앞 앞지느러미 | 어깨 | 128 | 22×16 | 오른쪽·아래 |
| `baby_head.png` | 머리 | 목 연결점 | 128 | 30×28 | 위·오른쪽으로 |
| `baby_face.png` | 눈·코 | 목 연결점 | 128 | 26×16 | `head`와 **동일 원점** |
| `baby_whiskers.png` | 수염 | 목 연결점 | 128 | 24×12 | `head`와 **동일 원점** |

### 4.2 엄마 물범 파츠 (3종)

| 파일명 | 부위 | 원점 | 캔버스 | 인게임 크기 | 비고 |
|---|---|---|---|---|---|
| `mom_body.png` | 몸통 | 몸통 중심 | 256 | 120×96 | 새끼보다 크고 단정. 3/4 각도 허용 |
| `mom_head.png` | 머리 | 목 연결점 | 256 | 60×44 | 위·오른쪽 |
| `mom_flipper.png` | 흔드는 앞지느러미 | 어깨 | 256 | 34×26 | 오른쪽·위로 뻗음 (도착 시 흔드는 동작) |

### 4.3 적 (4종)

| 파일명 | 부위 | 원점 | 캔버스 | 인게임 크기 | 비고 |
|---|---|---|---|---|---|
| `seagull_1.png` | 갈매기, 날개 위로 | 도형 중심 | 128 | 36×28 | 프레임 1 |
| `seagull_2.png` | 갈매기, 날개 아래로 | 도형 중심 | 128 | 36×28 | 프레임 2. **몸통·머리 위치는 1번과 동일** |
| `crab_1.png` | 게, 다리 모음 | 도형 중심 | 128 | 32×24 | 프레임 1 |
| `crab_2.png` | 게, 다리 벌림 | 도형 중심 | 128 | 32×24 | 프레임 2. **집게·몸통 위치 동일** |

### 4.4 위험 요소 (3종)

| 파일명 | 부위 | 원점 | 캔버스 | 인게임 크기 | 비고 |
|---|---|---|---|---|---|
| `thin_ice.png` | 얇은 얼음 타일 | 도형 중심 | 128 | 64×32 | 밟으면 깨지는 판. 금 간 표면 |
| `ice_block.png` | 깨지는 얼음 블록 | 도형 중심 | 128 | 48×48 | 꼬리치기로 파괴. 금 간 얼음 덩이 |
| `icicle.png` | 고드름 | **꼭대기** | 128 | 20×48 | 매달린 형태. 규칙 A처럼 꼭대기가 중심 |

### 4.5 환경 (5종)

| 파일명 | 부위 | 원점 | 캔버스 | 인게임 크기 | 비고 |
|---|---|---|---|---|---|
| `ground_tile.png` | 얼음 지면 타일 | 도형 중심 | 128 | 64×32 | 좌우·상하 타일 가능해야 함(패턴 가장자리가 자연스럽게) |
| `platform_tile.png` | 눈 플랫폼 | 도형 중심 | 128 | 64×24 | 떠 있는 발판 |
| `background_far.png` | 먼 배경 | — | 1024×576 | 640×360 | 하늘·산·물. 캐릭터 없음 |
| `mom_floe.png` | 엄마가 서 있는 빙하 | 도형 중심 | 256 | 160×64 | 각 레벨 끝에 등장 |
| `fish.png` | 물고기 수집품 | 도형 중심 | 128 | 24×20 | 길에 놓이는 수집물 |

### 4.6 UI (1종)

| 파일명 | 부위 | 원점 | 캔버스 | 인게임 크기 | 비고 |
|---|---|---|---|---|---|
| `heart.png` | 하트 | 도형 중심 | 128 | 20×18 | 체력 표시. `#F2A2A2` 계열 |

---

## 5. 프롬프트 — 새끼 물범 파츠

아래 8개를 순서대로 뽑습니다. 각 프롬프트 끝의 공통 파라미터는 그대로 두고 `<MASTER_URL>` 만 채웁니다.

### `baby_tail.png`

```
A single isolated cartoon seal tail: two fan-shaped hind flippers spread wide like a paddle, flat 2D game sprite style, thick clean dark outline (#2B3A47), soft two-tone cel shading, pale blue-white fur (#E8EEF2) with shadow (#A9BCCB), rounded cute shapes, side view facing right, the joint where the tail attaches to the body sits at the exact center of the image and the tail fans out to the left of that center point, crisp vector-like edges, solid flat magenta background (#FF00FF), no text, no watermark, no shadow, no ground --ar 1:1 --cref <MASTER_URL> --cw 100 --seed 12345 --stylize 100 --v 7
```

### `baby_body.png`

```
A single isolated cartoon baby seal torso, pear-shaped round body, flat 2D game sprite style, thick clean dark outline (#2B3A47), soft two-tone cel shading, pale blue-white fur (#E8EEF2) with shadow (#A9BCCB) along the lower back, rounded friendly shape, side view facing right, the center of the torso is at the exact center of the image, no head, no flippers, no tail, crisp vector-like edges, solid flat magenta background (#FF00FF), no text, no watermark, no shadow, no ground --ar 1:1 --cref <MASTER_URL> --cw 100 --seed 12345 --stylize 100 --v 7
```

### `baby_belly.png`

```
A single isolated cartoon baby seal belly patch, a soft rounded pale underside that follows the curve of the torso, flat 2D game sprite style, thick clean dark outline (#2B3A47), soft two-tone cel shading, near-white fur (#FBFDFF) with light shadow (#C9D6E2), side view facing right, the center of the torso is at the exact center of the image so this patch overlays the lower and front part of the body, no head, no flippers, no tail, crisp vector-like edges, solid flat magenta background (#FF00FF), no text, no watermark, no shadow, no ground --ar 1:1 --cref <MASTER_URL> --cw 100 --seed 12345 --stylize 100 --v 7
```

### `baby_flipper_back.png`

```
A single isolated cartoon baby seal front flipper, small paddle-shaped flipper angled down and back, flat 2D game sprite style, thick clean dark outline (#2B3A47), soft two-tone cel shading, desaturated grey-blue fur (#A9BCCB) so it reads as behind the body, rounded cute shape, side view facing right, the shoulder joint where the flipper attaches is at the exact center of the image and the flipper extends down and to the left, no body, no head, no tail, crisp vector-like edges, solid flat magenta background (#FF00FF), no text, no watermark, no shadow, no ground --ar 1:1 --cref <MASTER_URL> --cw 100 --seed 12345 --stylize 100 --v 7
```

### `baby_flipper_front.png`

```
A single isolated cartoon baby seal front flipper, small paddle-shaped flipper angled down and forward, flat 2D game sprite style, thick clean dark outline (#2B3A47), soft two-tone cel shading, light blue-grey fur (#C9D6E2), rounded cute shape, side view facing right, the shoulder joint where the flipper attaches is at the exact center of the image and the flipper extends down and to the right, no body, no head, no tail, crisp vector-like edges, solid flat magenta background (#FF00FF), no text, no watermark, no shadow, no ground --ar 1:1 --cref <MASTER_URL> --cw 100 --seed 12345 --stylize 100 --v 7
```

### `baby_head.png`

```
A single isolated cartoon baby seal head, round friendly head with a short muzzle, flat 2D game sprite style, thick clean dark outline (#2B3A47), soft two-tone cel shading, pale blue-white fur (#E8EEF2) with shadow (#A9BCCB) under the jaw, side view facing right, the neck joint where the head attaches to the body is at the exact center of the image and the head extends up and to the right of that point, blank head with no eyes no nose no whiskers, no body, no flippers, crisp vector-like edges, solid flat magenta background (#FF00FF), no text, no watermark, no shadow, no ground --ar 1:1 --cref <MASTER_URL> --cw 100 --seed 12345 --stylize 100 --v 7
```

### `baby_face.png`

```
A single isolated cartoon baby seal face detail, two large round glossy eyes and a small dark nose, flat 2D game sprite style, thick clean dark outline (#2B3A47), eyes in near-black (#2B3A47) with a single white highlight dot, no eyelids, friendly happy expression, side view facing right, the neck joint is at the exact center of the image so this detail overlays the upper right of the head, no head shape, no body, no flippers, crisp vector-like edges, solid flat magenta background (#FF00FF), no text, no watermark, no shadow, no ground --ar 1:1 --cref <MASTER_URL> --cw 100 --seed 12345 --stylize 100 --v 7
```

### `baby_whiskers.png`

```
A single isolated cartoon baby seal whiskers, three short curved whiskers on each side of the muzzle, flat 2D game sprite style, thin dark lines (#2B3A47), side view facing right, the neck joint is at the exact center of the image so the whiskers sit at the front of the muzzle on the upper right, no head shape, no body, no eyes, crisp vector-like edges, solid flat magenta background (#FF00FF), no text, no watermark, no shadow, no ground --ar 1:1 --cref <MASTER_URL> --cw 100 --seed 12345 --stylize 100 --v 7
```

---

## 6. 프롬프트 — 엄마 물범 파츠

엄마는 도착 지점에서 거의 가만히 서서 앞지느러미만 흔듭니다. 그래서 몸통 1장 + 머리 + 흔드는 지느러미면 충분하고, 새끼와 같은 규칙으로 조립합니다. 팔레트는 의도적으로 따뜻한 크림색으로 바꿔서 새끼와 구분됩니다.

### `mom_body.png`

```
A single isolated cartoon mother harp seal torso, large calm pear-shaped body, noticeably bigger and more rounded than a baby seal, flat 2D game sprite style, thick clean dark outline (#4A3B33), soft two-tone cel shading, warm cream fur (#F5E9DC) with shadow (#D9C3AE) along the lower back, three-quarter view, the center of the torso is at the exact center of the image, no head, no flippers, no tail, crisp vector-like edges, solid flat magenta background (#FF00FF), no text, no watermark, no shadow, no ground --ar 1:1 --cref <MASTER_URL> --cw 100 --seed 12345 --stylize 100 --v 7
```

### `mom_head.png`

```
A single isolated cartoon mother harp seal head, large round gentle head with a short muzzle, flat 2D game sprite style, thick clean dark outline (#4A3B33), soft two-tone cel shading, warm cream fur (#F5E9DC) with shadow (#D9C3AE) under the jaw, three-quarter view, the neck joint where the head attaches to the body is at the exact center of the image and the head extends up and to the right, blank head with no eyes no nose no whiskers, no body, no flippers, crisp vector-like edges, solid flat magenta background (#FF00FF), no text, no watermark, no shadow, no ground --ar 1:1 --cref <MASTER_URL> --cw 100 --seed 12345 --stylize 100 --v 7
```

### `mom_flipper.png`

```
A single isolated cartoon mother harp seal front flipper raised up in a waving gesture, large paddle-shaped flipper angled up and forward, flat 2D game sprite style, thick clean dark outline (#4A3B33), soft two-tone cel shading, warm cream fur (#F5E9DC) with shadow (#D9C3AE), three-quarter view, the shoulder joint where the flipper attaches is at the exact center of the image and the flipper extends up and to the right, no body, no head, no tail, crisp vector-like edges, solid flat magenta background (#FF00FF), no text, no watermark, no shadow, no ground --ar 1:1 --cref <MASTER_URL> --cw 100 --seed 12345 --stylize 100 --v 7
```

> 엄마 얼굴이 필요하면 `baby_face.png` 프롬프트에서 `baby seal` → `mother harp seal`, 팔레트를 `#4A3B33` 계열로 바꿔서 한 장 더 뽑습니다. 엄마는 눈을 따로 분리하지 않고 `mom_head`에 직접 넣는 편이 더 자연스럽습니다.

---

## 7. 프롬프트 — 적

두 프레임 모두 같은 `--seed`를 쓰고, **"몸통과 머리 위치는 이전 프레임과 동일"** 을 명시해야 흔들리지 않습니다.

### `seagull_1.png`

```
A single isolated cartoon seagull with wings raised up, flat 2D game sprite style, thick clean dark outline (#2B3A47), soft two-tone cel shading, white body (#FBFDFF) with grey wing tips (#A9BCCB), orange beak and feet, round cartoon proportions, side view facing left, the center of the body is at the exact center of the image, crisp vector-like edges, solid flat magenta background (#FF00FF), no text, no watermark, no shadow, no ground --ar 1:1 --seed 12345 --stylize 120 --v 7
```

### `seagull_2.png`

```
A single isolated cartoon seagull with wings swept down, flat 2D game sprite style, thick clean dark outline (#2B3A47), soft two-tone cel shading, white body (#FBFDFF) with grey wing tips (#A9BCCB), orange beak and feet, round cartoon proportions, side view facing left, the body and head stay in exactly the same position as the previous frame with only the wings moving down, the center of the body is at the exact center of the image, crisp vector-like edges, solid flat magenta background (#FF00FF), no text, no watermark, no shadow, no ground --ar 1:1 --seed 12345 --stylize 120 --v 7
```

### `crab_1.png`

```
A single isolated cartoon crab with legs tucked in, flat 2D game sprite style, thick clean dark outline (#2B3A47), soft two-tone cel shading, orange-red shell (#E8834A) with lighter underside (#F7C3A0), two big claws, round cartoon proportions, top-down three-quarter view, the center of the body is at the exact center of the image, crisp vector-like edges, solid flat magenta background (#FF00FF), no text, no watermark, no shadow, no ground --ar 1:1 --seed 12345 --stylize 120 --v 7
```

### `crab_2.png`

```
A single isolated cartoon crab with legs spread wide, flat 2D game sprite style, thick clean dark outline (#2B3A47), soft two-tone cel shading, orange-red shell (#E8834A) with lighter underside (#F7C3A0), two big claws, round cartoon proportions, top-down three-quarter view, the body and claws stay in exactly the same position as the previous frame with only the legs spreading out, the center of the body is at the exact center of the image, crisp vector-like edges, solid flat magenta background (#FF00FF), no text, no watermark, no shadow, no ground --ar 1:1 --seed 12345 --stylize 120 --v 7
```

---

## 8. 프롬프트 — 위험 요소

### `thin_ice.png`

```
A single isolated cartoon thin cracked ice floe tile, a flat rectangular slab of pale ice with visible cracks and a slightly darker translucent patch in the middle, flat 2D game art style, thick clean dark outline (#2B3A47), soft two-tone cel shading, ice blue (#DCEBF5) with shadow (#7FA8C0) in the cracks, top-down slightly angled view, the center of the slab is at the exact center of the image, tileable edges, crisp vector-like edges, solid flat magenta background (#FF00FF), no text, no watermark, no shadow, no ground --ar 1:1 --seed 12345 --stylize 100 --v 7
```

### `ice_block.png`

```
A single isolated cartoon chunk of solid ice, an irregular rounded block with a flat bottom, cracks running through it and chipped corners, flat 2D game art style, thick clean dark outline (#2B3A47), soft two-tone cel shading, bright ice blue (#DCEBF5) with deeper shadow (#7FA8C0) and white highlights (#FBFDFF), three-quarter view, the center of the block is at the exact center of the image, crisp vector-like edges, solid flat magenta background (#FF00FF), no text, no watermark, no shadow, no ground --ar 1:1 --seed 12345 --stylize 100 --v 7
```

### `icicle.png`

```
A single isolated cartoon icicle hanging down, a long tapered translucent spike of ice with a rounded tip and a slightly wider frozen top, flat 2D game art style, thick clean dark outline (#2B3A47), soft two-tone cel shading, pale ice blue (#EAF6FB) with shadow (#A9BCCB) along one side, the frozen attachment point at the very top of the icicle is at the exact center of the image and the icicle hangs straight down from that point, crisp vector-like edges, solid flat magenta background (#FF00FF), no text, no watermark, no shadow, no ceiling --ar 1:1 --seed 12345 --stylize 100 --v 7
```

---

## 9. 프롬프트 — 환경

### `ground_tile.png`

```
A single cartoon ice and snow ground tile, a flat rectangular slab of packed snow with a glossy ice sheen on top and a chunkier snow lip along the bottom edge, flat 2D game art style, thick clean dark outline (#2B3A47), soft two-tone cel shading, snow (#FBFDFF) on top with ice blue (#DCEBF5) and shadow (#7FA8C0) below, front-facing side view, tileable left and right edges so copies sit side by side seamlessly, the center of the tile is at the exact center of the image, crisp vector-like edges, solid flat magenta background (#FF00FF), no text, no watermark, no shadow, no props --ar 1:1 --seed 12345 --stylize 100 --v 7
```

### `platform_tile.png`

```
A single cartoon floating snow platform, a rounded rectangular slab of packed snow with a chunkier underside and a couple of small icicles hanging below, flat 2D game art style, thick clean dark outline (#2B3A47), soft two-tone cel shading, snow (#FBFDFF) on top with ice blue (#DCEBF5) and shadow (#7FA8C0) underneath, front-facing side view, tileable left and right edges, the center of the platform is at the exact center of the image, crisp vector-like edges, solid flat magenta background (#FF00FF), no text, no watermark, no shadow, no props --ar 1:1 --seed 12345 --stylize 100 --v 7
```

### `background_far.png`

```
A wide cartoon arctic background, layered snow-covered mountains on the horizon, a calm dark blue sea (#2E6E8E) with slow swell lines, drifting ice floes, a pale sky gradient from #BFE3F5 at the horizon to #EAF6FB overhead, a few soft clouds, flat 2D game art style, thick clean outlines, soft two-tone cel shading, no characters, no animals, no foreground objects, no text, no watermark --ar 16:9 --seed 12345 --stylize 120 --v 7
```

### `mom_floe.png`

```
A single isolated cartoon large ice floe with a flat snow-covered top, a chunky slab of ice with a rounded rim, small icicles and cracks along the edges, flat 2D game art style, thick clean dark outline (#2B3A47), soft two-tone cel shading, snow (#FBFDFF) on top with ice blue (#DCEBF5) and deep shadow (#7FA8C0) below, three-quarter view, the center of the floe is at the exact center of the image, no characters, no animals, crisp vector-like edges, solid flat magenta background (#FF00FF), no text, no watermark, no shadow --ar 1:1 --seed 12345 --stylize 100 --v 7
```

### `fish.png`

```
A single isolated cartoon small arctic fish, a plump rounded silver fish with a forked tail and a tiny fin, flat 2D game sprite style, thick clean dark outline (#2B3A47), soft two-tone cel shading, pale silver-blue body (#C9D6E2) with a lighter belly (#FBFDFF), side view facing left, the center of the fish is at the exact center of the image, crisp vector-like edges, solid flat magenta background (#FF00FF), no text, no watermark, no shadow, no ground --ar 1:1 --seed 12345 --stylize 120 --v 7
```

---

## 10. 프롬프트 — UI

### `heart.png`

```
A single isolated cartoon heart icon, a rounded soft heart shape with a small glossy highlight, flat 2D game UI art style, thick clean dark outline (#2B3A47), soft two-tone cel shading, soft pink-red (#F2A2A2) with a lighter top (#F7C3C3), the center of the heart is at the exact center of the image, crisp vector-like edges, solid flat magenta background (#FF00FF), no text, no watermark, no shadow --ar 1:1 --seed 12345 --stylize 100 --v 7
```

---

## 11. 후처리 (게임에 넣을 상태로 만들기)

### 11.1 배경 제거 — 마젠타 키

Midjourney는 투명 배경을 만들지 않으므로 마젠타를 걷어냅니다. 우선순위 순서:

1. **Midjourney 웹 에디터의 Background Remover** — 가장 깔끔합니다. 직접 뽑은 이미지에 쓸 수 있으면 이걸 쓰세요.
2. **`ffmpeg` chromakey** — 이 머신에 있습니다. 1px 정도 마젠타 프린지가 남을 수 있는데, 게임에서 표시 크기가 작으면 눈에 안 띕니다.

```bash
mkdir -p sprites
ffmpeg -y -i raw/baby_tail.png \
  -vf "chromakey=0xFF00FF:0.22:0.04,format=rgba" \
  sprites/baby_tail.png
```

### 11.2 균일 축소

**관절 중심 파츠는 캔버스 전체를 균일하게 줄입니다.** 원점이 캔버스 정중앙이므로 균일 축소하면 중심은 그대로 유지되고 원점 규칙이 깨지지 않습니다. 잘라내면 중심이 어긋나므로 **자르지 마세요.**

```bash
# 128 캔버스 파츠 → 64
ffmpeg -y -i raw/baby_tail.png -vf "scale=64:64:flags=lanczos,format=rgba" sprites/baby_tail.png

# 256 캔버스 파츠(엄마, 빙하) → 128
ffmpeg -y -i raw/mom_body.png -vf "scale=128:128:flags=lanczos,format=rgba" sprites/mom_body.png

# 1024 캔버스(배경) → 512
ffmpeg -y -i raw/background_far.png -vf "scale=512:288:flags=lanczos" sprites/background_far.png
```

축소 배율은 **같은 캔버스 규격끼리 동일**해야 파츠끼리 비례가 맞습니다. 표의 "인게임 크기"는 목표 감각이며, 정확한 최종 배율은 내가 씬 파일에서 파츠별 `scale`로 맞춥니다.

### 11.3 디렉토리 규칙

```
assets/sprites/seal/baby_tail.png ...
assets/sprites/mom/mom_body.png ...
assets/sprites/enemies/seagull_1.png ...
assets/sprites/hazards/thin_ice.png ...
assets/sprites/env/ground_tile.png ...
assets/sprites/ui/heart.png
```

파일명은 4장의 표와 **정확히** 같아야 합니다. 내가 코드에서 이 이름으로 찾습니다.

### 11.4 자동화

파일이 모이면 내가 `tools/prepare_sprites.sh`를 만들어 드립니다. `raw/`에 전부 넣고 한 번 실행하면 배경 제거 → 축소 → `assets/sprites/` 배치까지 끝나도록.

---

## 12. 애니메이션 프레임 — 지금은 0개

새끼 물범은 **도형 퍼펫** 방식이라 그림 프레임이 하나도 필요 없습니다. idle/run/jump/fall/swat/hurt 전부 `AnimationPlayer`가 **피벗 노드**의 위치·스케일·회전을 조작해 만듭니다. 위 8개 파츠만 있으면 새끼 물범 동작은 전부 구현됩니다.

### 왜 "피벗 노드"인가

게임에서는 파츠마다 `Node2D` 피벗을 두고, 그 아래에 시각을 붙입니다.

```
HeadPivot (Node2D)          ← 씬에서 좌표만 가짐. (0, -18)
└── VisualSlot (Node2D)
    ├── PolygonPuppet       ← 지금: 도형 파츠
    └── SpriteSwap          ← 나중: AnimatedSprite2D
```

`AnimationPlayer`의 트랙은 `HeadPivot:rotation` 처럼 **피벗의 프로퍼티**만 겨냥합니다. 시각 노드는 건드리지 않습니다. 그래서 그림을 교체할 때 애니메이션 파일이 영향을 받지 않습니다 — 피벗은 rest pose로 남아 있고, 스프라이트 프레임이 시각을 담당합니다.

> 이 문서의 앞선 버전에는 "코드가 매 프레임 파츠를 직접 조작한다"고 적혀 있었습니다. 이는 설계 문서 4장·7.3과 충돌하며, 실제로는 `AnimationPlayer`가 담당합니다. 매 프레임 직접 조작 방식은 그림 교체 시 충돌하므로 기각되었습니다.

나중에 Midjourney 스프라이트 시트로 교체할 때 비로소 프레임이 필요하고, 그때의 목록은 다음과 같습니다. 지금 뽑지 않아도 됩니다.

| 대상 | 필요 프레임 |
|---|---|
| 아기 물범 | idle 2, run 4, jump 1, fall 1, swat 2, hurt 1 |
| 엄마 물범 | idle 2, wave 2 |
| 갈매기 | fly 2 (이미 뽑음) |
| 게 | walk 2 (이미 뽑음) |

---

## 13. 체크리스트

- [ ] Step 1 마스터 시트 1장 생성, 측면 칸 잘내기, `<MASTER_URL>` 확보
- [ ] `--seed` 고정값 확인 (파츠 전부 동일)
- [ ] 4.1 새끼 물범 파츠 8종
- [ ] 4.2 엄마 물범 파츠 3종
- [ ] 4.3 적 4종 (프레임 2종 × 2마리)
- [ ] 4.4 위험 요소 3종
- [ ] 4.5 환경 5종
- [ ] 4.6 UI 1종
- [ ] 배경 제거 (11.1)
- [ ] 균일 축소 (11.2)
- [ ] 파일명·디렉토리 규칙 확인 (11.3)
- [ ] 완료 알림 → 내가 `tools/prepare_sprites.sh` 작성 및 게임 연결

---

## 다음 단계

이 프롬프트는 **그림 작업**을 위한 문서입니다. 게임 코드는 아직 쓰지 않았습니다.
그림을 뽑는 동안 내가 할 일은 설계 문서를 쓰는 것입니다 — 코어 루프, 레벨별 난이도 상승 규칙, 파츠 조립 구조, 씬 트리. 이 문서를 당신이 승인해야 코드를 쓰기 시작합니다.
