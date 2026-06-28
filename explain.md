# LeRobot SO-100 리더-팔로워 텔레오퍼레이션 작동 원리 및 가이드

이 문서에서는 LeRobot 라이브러리를 통해 SO-100 로봇 팔과 리더 암(Leader Arm)을 구동할 때의 핵심 작동 메커니즘, 제어 원리, 하드웨어 연동 구조 및 주의할 점을 자세히 정리합니다.

---

## 🔍 1. 핵심 작동 원리 (Operating Principle)

SO-100의 실시간 조작(Teleoperation)은 사람이 조작용 리더 암(Leader)을 움직이면, 로봇 본체인 팔로워 암(Follower)이 그 움직임을 그대로 실시간 복사하여 따라하는 **동작 마스터-슬레이브(Master-Slave) 구조**로 동작합니다.

### ⚙️ 리더-팔로워 매핑 프로세스
1. **상태 분리 (Torque Control):**
   - **리더 암 (Leader):** 사람이 손으로 잡고 직접 움직여야 하므로 모터의 토크(Torque)를 차단하여 부드럽게 움직일 수 있는 **수동 역구동 상태(Passive Backdrive Mode)**로 동작합니다.
   - **팔로워 암 (Follower):** 리더 암의 각도를 전달받아 고정되거나 능동적으로 힘을 내서 움직여야 하므로 토크가 켜진 **능동 위치 제어 상태(Active Position Control Mode)**로 동작합니다.
2. **캘리브레이션 매핑 (Calibration Mapping):**
   - 두 로봇 팔의 기계적 오차와 모터 조립 각도 편차를 보정하기 위해 미리 정의한 `my_leader.json` 및 `my_follower.json` 파일을 불러옵니다.
   - 리더 암의 각 관절 위치 센서가 측정하는 로(Raw) 값의 최소/최대 범위(`range_min`, `range_max`)를 `[0, 1]`의 범위로 **정규화(Normalization)**합니다.
   - 정규화된 제어값 `[0, 1]`을 팔로워 로봇 모터의 캘리브레이션 범위에 맞춰 다시 물리적인 모터 목표값으로 역변환(Denormalization)하여 모터 명령으로 전송합니다.

---

## 💻 2. 코드 작동 방식 및 제어 루프 (Code Mechanics)

LeRobot의 텔레오퍼레이션 제어 루프는 `lerobot-teleoperate` 스크립트 실행 시 [lerobot_teleoperate.py](file:///home/tombin1204/lerobot/src/lerobot/scripts/lerobot_teleoperate.py)의 `teleop_loop` 함수를 통해 구현됩니다.

```mermaid
sequenceDiagram
    participant User as 사용자 (리더 암 조작)
    participant Teleop as Leader Arm (pyserial)
    participant Loop as Teleop Loop (Python)
    participant Robot as Follower Arm (pyserial)

    loop 매 초 60회 (60 Hz)
        User->>Teleop: 관절 회전 및 조작
        Loop->>Teleop: get_action() (현재 관절 각도 획득)
        Teleop-->>Loop: Raw 모터 각도 데이터 반환
        Loop->>Loop: 캘리브레이션 값을 통한 정규화 및 크기 변환 (Processor)
        Loop->>Robot: send_action() (목표 제어 명령 전송)
        Robot->>Robot: 모터 토크 작동 및 물리적 이동
    end
```

### 주요 루프 작동 과정:
- **`teleop.get_action()`:** 리더 암의 모터 버스(pyserial을 통한 Feetech SDK 버스)에 동기식 읽기(`Present_Position`)를 요청하여 관절 각도를 수집합니다.
- **`teleop_action_processor` & `robot_action_processor`:** 수집된 관절 위치 배열을 정규화하고 팔로워 모터가 이해할 수 있는 값으로 전처리합니다.
- **`robot.send_action()`:** 가공된 목표 위치 값을 팔로워 모터 버스로 전송하여 실시간 구동합니다.
- **`precise_sleep`:** 지정된 FPS(기본값 60 FPS, 즉 약 16.6ms 주기)를 정확하게 유지하여 지연이 적고 부드러운 실시간 제어 성능을 보장합니다.

---

## ⚡ 3. 하드웨어 및 통신 구조 (Hardware & Comms)

- **Feetech 스마트 서보모터 (STS 계열):** Half-Duplex(반이중) 직렬 통신 방식을 사용하며, 전원선과 데이터선이 하나로 연결되는 데이지 체인(Daisy Chain) 방식으로 모터들이 직렬 연결됩니다.
- **USB-to-Serial 컨버터:** PC와 모터 체인을 연결하며, WSL2 환경의 포트 포워딩을 통해 `/dev/ttyACM0` 및 `/dev/ttyACM1`과 같은 리눅스 파일 디스크립터로 매핑됩니다.
- **통신 보드 전압 지원:** SO-100용 Feetech 모터 모델에 따라 인가 전압 규격(5V/7.4V 또는 12V)이 엄격하게 구분됩니다. 전압 부족이나 과전압 인가 시 통신 칩이 손상되거나 타임아웃 오류가 발생합니다.

---

## ⚠️ 4. 안전 및 구동 시 주의할 점 (Precautions & Troubleshooting)

1. **WSL2 USB 기기 연결 유실:**
   - PC 전원을 끄거나 USB 케이블을 뽑았다가 다시 꽂는 경우, Windows 호스트에서 WSL2 환경으로 `usbipd attach` 명령을 매번 다시 수행해 주어야 합니다.
   - WSL2 터미널에서 `ls -la /dev/ttyACM*` 명령어로 장치 파일이 정상적으로 존재하는지 매 구동 전에 습관적으로 확인하는 것이 좋습니다.

2. **포트 권한 설정 필수:**
   - 리눅스는 시리얼 기기 파일에 대해 기본적으로 일반 사용자의 쓰기 권한을 차단합니다. 텔레오퍼레이션 구동 직전 `sudo chmod 666 /dev/ttyACM0 /dev/ttyACM1` 명령어로 읽기/쓰기 권한을 열어주어야 `Permission Denied` 에러를 방지할 수 있습니다.

3. **모터 과열 및 에러 상태 (LED 깜빡임):**
   - 모터에 물리적인 방해를 주어 관절 한계치를 넘어서 힘을 주거나 장시간 강제로 짓누르면 모터 내부 드라이버 칩이 오버로드(Overload) 상태가 됩니다.
   - 이때 **모터의 빨간색 LED가 깜빡이며 동작이 정지**합니다. 모터 보존을 위한 자체 보호 회로이므로, 기기를 끈 뒤 열을 식히고 물리적 조작부가 간섭 없이 잘 움직이는지 확인한 후 전원을 재인가해야 합니다.

4. **포트 매핑 바뀜:**
   - 두 로봇 팔을 장착한 순서에 따라 `/dev/ttyACM0`이 팔로워가 되고 `/dev/ttyACM1`이 리더가 될 수도 있고, 그 반대가 될 수도 있습니다.
   - 구동 시 `Feetech timeout` 또는 `Motors initialization failed` 등의 직렬 연결 에러가 나면, 실행 명령의 포트 번호를 서로 맞바꾸어 실행해 주어야 합니다.
