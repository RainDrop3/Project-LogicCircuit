# FPGA 폭탄 해제 게임 - 최종 프로젝트 명세서 (Updated Final Version)

## 1. 프로젝트 개요
**FPGA 보드(Xilinx Spartan-7)**를 사용하여 제한 시간 내에 가상의 폭탄을 해제하는 시뮬레이션 게임입니다. [cite_start]사용자는 키패드, DIP 스위치, ADC 다이얼, 조도 센서를 조작하여 총 4단계(Phase)의 퍼즐을 순차적으로 해결해야 합니다[cite: 3, 4, 8, 9].

* [cite_start]**Target Board**: Xilinx Spartan-7 Board (Device: xc7s75fgga484-1) [cite: 4]
* [cite_start]**Language**: Verilog HDL [cite: 5]
* [cite_start]**Tool**: Xilinx Vivado [cite: 6]

---

## 2. 핵심 특징 및 변경 사항

### 2.1 주요 인터페이스 변경
* [cite_start]**No Dedicated Buttons**: 별도의 외부 푸시 버튼을 사용하지 않습니다[cite: 11].
* [cite_start]**System Reset**: **키패드의 KEY 9**가 유일한 시스템 리셋(Active High Logic) 역할을 수행합니다[cite: 12].
* [cite_start]**Random Events**: 게임 진행 중 예측할 수 없는 타이밍에 돌발 이벤트가 자동 발생합니다[cite: 13].
* [cite_start]**Conflict Prevention**: 이벤트 발생 시 메인 퍼즐의 조작이 잠기며(Disable), 이벤트 해결에만 집중해야 합니다[cite: 14].

### 2.2 시각/물리 피드백 (Feedback)
* [cite_start]**Main Display (8-Digit 7-Segment)**: 각 단계별 퍼즐 데이터 및 결과값 표시 (기존 타이머 표시 기능 제거됨)[cite: 16].
* [cite_start]**Stability Display (Single 7-Segment)**: 폭탄의 안정도(0~9)를 표시합니다[cite: 17].
* **Information (Text LCD)**:
    * [cite_start]Line 1: 현재 단계 및 상태 메시지[cite: 22].
    * [cite_start]Line 2: 실시간 타이머 ("TIME: MM:SS") 항상 표시[cite: 23].
* **Status Indicators**:
    * [cite_start]LED Array: 퍼즐 진행 상황 및 모드 표시[cite: 19].
    * [cite_start]RGB LED: 평상시 OFF, **Event 2(위험 탐색)** 발생 시에만 상태 표시 (초록/노랑/빨강)[cite: 20].
* **Actuators**:
    * [cite_start]Servo Motor: 게이지 표시 및 이벤트 모션(과부하/왕복)[cite: 25].
    * [cite_start]Step Motor: Phase 4 연타 게임 진동 피드백[cite: 26].
    * [cite_start]Piezo Buzzer: Event 1 발생 시 경고음[cite: 27].

### 2.3 승리 및 패배 조건
* [cite_start]**승리 (Bomb Defused)**: 제한 시간 내에 Phase 4까지 모두 클리어[cite: 29].
* [cite_start]**패배 (Explosion)**: 오직 **제한 시간 초과 (00:00)** 시에만 발생합니다[cite: 30].
    * [cite_start]*Note*: 안정도(Stability)가 0이 되어도 게임이 즉시 종료되지 않으며, 타이머 가속 페널티만 유지됩니다[cite: 31].

---

## 3. 하드웨어 아키텍처 및 I/O

### 3.1 입력 장치 (Input Devices)
| 장치명 | 포트명 | 비트 폭 | 상세 설명 |
| :--- | :--- | :--- | :--- |
| **System Clock** | `clk` | 1-bit | [cite_start]50MHz 메인 클럭 [cite: 38] |
| **Keypad** | `keypad_in` | 12-bit | [cite_start]3x4 Matrix Keypad (Parallel) [cite: 38] |
| **DIP Switch** | `dip_in` | 8-bit | [cite_start]퍼즐 로직 제어 (Active High) [cite: 38] |
| **ADC Interface** | `adc_data_in` | 1-bit | [cite_start]SPI MISO (From MCP3202) [cite: 38] |

### 3.2 Keypad 핀 매핑 (Role Mapping)
| Key | Function | Key | Function |
| :---: | :--- | :---: | :--- |
| **1** | Number 1 | **7** | Number 7 |
| **2** | Number 2 | **8** | Number 8 |
| **3** | Number 3 | **9** | **System Reset (Global)** |
| **4** | Number 4 | **\*** | Invert Mode |
| **5** | Number 5 | **0** | **Main Action (Submit/Click)** |
| **6** | Number 6 | **#** | **Op Change / Event 2 Solution** |
> [cite_start][cite: 40]

### 3.3 출력 장치 (Output Devices)
* [cite_start]**7-Segment (Main)**: `seg_data`, `seg_com` [cite: 42]
* [cite_start]**7-Segment (Stability)**: `seg_single_data` [cite: 43]
* [cite_start]**LED Array**: `led_out` [cite: 44]
* [cite_start]**RGB LED (x4)**: `f_led1` ~ `f_led4` (Event 2 전용) [cite: 45]
* [cite_start]**Text LCD**: `lcd_data`, `lcd_rs`, `lcd_rw`, `lcd_en` [cite: 46]
* [cite_start]**Motors**: `servo_pwm`, `step_motor_phase` [cite: 47]
* [cite_start]**Sound**: `piezo_out` [cite: 48]
* [cite_start]**ADC Control**: `adc_cs_n`, `adc_sclk`, `adc_din` [cite: 49]

---

## 4. 시스템 로직 (System Logic)

### 4.1 메인 FSM (Flow Control)
1.  **IDLE**: 대기 상태. [cite_start]LCD "READY TO PLAY", 타이머 리셋, 7-Seg "PLAY"[cite: 52].
2.  [cite_start]**PHASE 1~4**: 순차적 퍼즐 진행 (랜덤 이벤트 발생 가능 구간: P1, P3, P4)[cite: 53].
3.  **SUCCESS**: 모든 단계 클리어. [cite_start]LCD "BOMB DEFUSED", 7-Seg "8888..."[cite: 54].
4.  **FAIL**: 시간 초과(00:00). [cite_start]LCD "EXPLOSION", 7-Seg "DEAD..."[cite: 55].

### 4.2 랜덤 이벤트 시스템
* [cite_start]**발생 조건**: Phase 1, 3, 4 진행 중 무작위 시간 간격으로 자동 발생[cite: 61].
* [cite_start]**상호 배제 (Mutual Exclusion)**: 이벤트 활성화(`is_event_running`) 시 현재 진행 중인 퍼즐 모듈은 일시 정지(`enable = 0`)되어 키 입력 충돌을 방지함[cite: 62, 63].

---

## 5. 단계별 상세 로직 (Game Phases)

### Phase 1: 숫자 연산 (Number Puzzle)
* [cite_start]**목표**: 9개의 숫자와 연산자를 조합하여 결과값 `0xFF` 만들기[cite: 67].
* [cite_start]**조작**: Key 1~8(선택), Key \*(반전), Key #(연산자 변경), Key 0(제출)[cite: 68].
* [cite_start]**디스플레이**: 7-Segment에 결과값 Hex 표시[cite: 69].

### Phase 2: 다이얼 매칭 (Dial Matching)
* [cite_start]**목표**: 7-Segment의 타겟 위치('O')에 LED 커서를 일치시키기[cite: 71].
* [cite_start]**조작**: ADC Dial 회전, Key 0(확인)[cite: 72].
* [cite_start]**특이사항**: 물리적 조작의 복잡성을 고려하여 **랜덤 이벤트가 발생하지 않음**[cite: 73].

### Phase 3: 논리 퍼즐 (Lights Out)
* [cite_start]**목표**: 모든 LED 끄기[cite: 75].
* [cite_start]**조작**: DIP Switch Toggle, Key 0(확인)[cite: 76].
* [cite_start]**디스플레이**: 7-Segment "CAFE"[cite: 77].

### Phase 4: 최종 해제 (Rapid Click)
* [cite_start]**목표**: 제한 시간 내 목표 횟수 연타[cite: 79].
* [cite_start]**조작**: Key 0 연타[cite: 80].
* [cite_start]**피드백**: 누를 때마다 스텝 모터 진동[cite: 81].

---

## 6. 돌발 이벤트 (Random Events)

### Event 1: 과부하 (Overload)
* [cite_start]**증상**: 서보모터 180도 고정, 피에조 경고음 발생[cite: 84].
* [cite_start]**해결**: 조도 센서(CDS)를 가려 어둡게 만들기[cite: 85].

### Event 2: 위험 탐색 (Danger Search)
* [cite_start]**증상**: 서보모터 왕복(Sweep), RGB LED 색상 변화[cite: 87].
* [cite_start]**해결**: RGB LED가 **초록색(Green)**일 때 **Key # (Hash)** 누르기[cite: 88].
    * [cite_start]*(기존 Key 0에서 Key #으로 변경됨)*[cite: 89].
* [cite_start]**실패**: 빨강/노랑 구간 클릭 또는 시간 초과 시 안정도 감소[cite: 90].

---

## 7. 파일 구성 (File List)

| 모듈 분류 | 파일명 | 변경/신규 내역 |
| :--- | :--- | :--- |
| **Top** | `src/game_top.v` | Key 9 리셋, 랜덤 생성기 연결, 이벤트 시 퍼즐 잠금 추가 |
| **Control** | `src/control/main_fsm.v` | 패배 조건(TimeOut Only) 수정 |
| | `src/control/game_timer.v` | (기존 동일) |
| | `src/control/random_event_generator.v` | **[신규]** 랜덤 타이밍 이벤트 트리거 생성 |
| **Puzzles** | `src/puzzles/phase1_puzzle1.v` | (기존 동일) |
| | `src/puzzles/phase1_puzzle2_dial.v` | (기존 동일) |
| | `src/puzzles/phase1_puzzle3.v` | 타이머 표시 로직 제거 (Top에서 처리) |
| | `src/puzzles/phase1_final_click.v` | (기존 동일) |
| **Events** | `src/events/event1_overload.v` | (기존 동일) |
| | `src/events/event2_danger.v` | 해결 키 입력 포트 분리 |
| **Drivers** | `src/drivers/*.v` | (기존 드라이버 모듈들 동일하게 사용) |

> [cite_start][cite: 95]