#!/bin/bash

# =====================================================================
# 개발 환경 데이터베이스 중지 스크립트
# =====================================================================
# 사용법: ./docker/db/dev/stop.sh
# 기능: 개발 환경 PostgreSQL 데이터베이스 컨테이너 중지
# =====================================================================

# 스크립트의 위치와 상관없이 항상 db/dev 디렉토리로 이동
cd "$(dirname "$0")"

echo "개발 환경 데이터베이스를 중지합니다..."

# 실행 중인 데이터베이스 컨테이너 확인 및 중지
if [ "$(docker ps -q -f name=vue-postgres-dev)" ]; then
    # 컨테이너가 실행 중인 경우 중지
    docker-compose down
    echo "개발 환경 데이터베이스가 중지되었습니다."
else
    # 실행 중인 컨테이너가 없는 경우 안내 메시지 출력
    echo "실행 중인 개발 환경 데이터베이스 컨테이너가 없습니다."
fi