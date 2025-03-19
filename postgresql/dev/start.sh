#!/bin/bash

# =====================================================================
# 개발 환경 데이터베이스 시작 스크립트
# =====================================================================
# 사용법: ./docker/db/dev/start.sh
# 기능: 개발 환경 PostgreSQL 데이터베이스 컨테이너 시작
# =====================================================================

# 스크립트의 위치와 상관없이 항상 db/dev 디렉토리로 이동
cd "$(dirname "$0")"

echo "개발 환경 데이터베이스를 시작합니다..."

# 네트워크 존재 여부 확인 및 생성
if ! docker network inspect vue_dev_network &>/dev/null; then
    echo "Docker 네트워크 'vue_dev_network'을 생성합니다..."
    docker network create vue_dev_network
fi

# 볼륨 존재 여부 확인
if ! docker volume inspect dev_postgres_data &>/dev/null; then
    echo "Docker 볼륨 'dev_postgres_data'를 생성합니다..."
    docker volume create dev_postgres_data
fi

# 데이터베이스 실행 (이미 실행 중이면 메시지만 출력)
if [ "$(docker ps -q -f name=vue-postgres-dev)" ]; then
    echo "개발 데이터베이스 컨테이너가 이미 실행 중입니다."
else
    # 백그라운드에서 실행
    docker-compose up -d
    echo "개발 데이터베이스가 백그라운드에서 시작되었습니다."
    
    # 데이터베이스 준비 확인
    echo "데이터베이스 준비를 기다리는 중..."
    max_wait=30
    counter=0
    while [ $counter -lt $max_wait ]; do
        if docker exec vue-postgres-dev pg_isready -U postgres &>/dev/null; then
            echo "개발 데이터베이스가 준비되었습니다 (postgres://postgres:devpassword@localhost:5432/vue_dev)"
            break
        fi
        sleep 2
        counter=$((counter+2))
        echo -n "."
    done
    
    if [ $counter -ge $max_wait ]; then
        echo ""
        echo "데이터베이스 준비 상태를 확인할 수 없습니다. 로그를 확인해보세요: docker logs vue-postgres-dev"
    fi
fi