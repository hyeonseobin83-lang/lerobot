#!/bin/bash

# 1. USB 포트 권한 자동 부여
echo "==========================================="
echo "🔑 USB 포트 권한 설정을 시도합니다..."
echo "==========================================="
sudo chmod 666 /dev/ttyACM0 /dev/ttyACM1 2>/dev/null

# 2. 포트 설정 결정 (파라미터로 swap 입력 시 포트 위치 변경)
ROBOT_PORT="/dev/ttyACM1"
TELEOP_PORT="/dev/ttyACM0"

if [ "$1" == "swap" ]; then
    echo "🔄 포트 위치를 맞바꿔 구동합니다 (ACM0 <-> ACM1)."
    ROBOT_PORT="/dev/ttyACM0"
    TELEOP_PORT="/dev/ttyACM1"
else
    echo "🤖 기본 포트 설정으로 구동합니다 (Follower: ACM1, Leader: ACM0)."
    echo "💡 만약 모터 통신 에러가 나면 './teleop.sh swap'으로 실행해 보세요."
fi

echo "==========================================="
echo "🚀 텔레오퍼레이션 구동 시작..."
echo "==========================================="

# 3. 콘다 가상환경 내에서 lerobot-teleoperate 실행
conda run -n lerobot lerobot-teleoperate \
  --robot.type=so100_follower \
  --robot.port=$ROBOT_PORT \
  --robot.id=my_follower \
  --teleop.type=so100_leader \
  --teleop.port=$TELEOP_PORT \
  --teleop.id=my_leader \
  --display_data=true
