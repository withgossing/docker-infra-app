#!/bin/bash

# =====================================================================
# 프로덕션 환경 데이터베이스 시작 스크립트
# =====================================================================
# 사용법: ./docker/db/prod/start.sh
# 기능: 프로덕션 환경 PostgreSQL 데이터베이스 컨테이너 시작 (Primary + Standby)
# =====================================================================

# 스크립트의 위치와 상관없이 항상 db/prod 디렉토리로 이동
cd "$(dirname "$0")"

echo "프로덕션 환경 데이터베이스를 시작합니다..."

# 필요한 디렉토리 경로 확인
if [ ! -d "../../prod/postgres/primary" ] || [ ! -d "../../prod/postgres/standby" ] || [ ! -d "../../prod/postgres/conf" ]; then
    echo "오류: 필요한 PostgreSQL 설정 디렉토리가 존재하지 않습니다."
    echo "다음 디렉토리가 필요합니다:"
    echo "  - docker/prod/postgres/primary"
    echo "  - docker/prod/postgres/standby"
    echo "  - docker/prod/postgres/conf"
    exit 1
fi

# 네트워크 존재 여부 확인 및 생성
if ! docker network inspect vue_prod_db_network &>/dev/null; then
    echo "Docker 네트워크 'vue_prod_db_network'을 생성합니다..."
    docker network create vue_prod_db_network
fi

# 볼륨 존재 여부 확인
for vol in postgres_primary_data postgres_standby_data; do
    if ! docker volume inspect $vol &>/dev/null; then
        echo "Docker 볼륨 '$vol'를 생성합니다..."
        docker volume create $vol
    fi
done

# 데이터베이스 실행 (이미 실행 중이면 메시지만 출력)
if [ "$(docker ps -q -f name=vue-postgres-primary)" ] && [ "$(docker ps -q -f name=vue-postgres-standby)" ]; then
    echo "프로덕션 데이터베이스 컨테이너가 이미 실행 중입니다."
else
    # 백그라운드에서 실행
    docker-compose up -d
    echo "프로덕션 데이터베이스가 백그라운드에서 시작되었습니다."
    
    # Primary 데이터베이스 준비 확인
    echo "Primary 데이터베이스 준비를 기다리는 중..."
    max_wait=60
    counter=0
    while [ $counter -lt $max_wait ]; do
        if docker exec vue-postgres-primary pg_isready -U postgres &>/dev/null; then
            echo "Primary 데이터베이스가 준비되었습니다."
            break
        fi
        sleep 2
        counter=$((counter+2))
        echo -n "."
    done
    
    if [ $counter -ge $max_wait ]; then
        echo ""
        echo "Primary 데이터베이스 준비 상태를 확인할 수 없습니다. 로그를 확인해보세요: docker logs vue-postgres-primary"
        exit 1
    fi
    
    # Standby 데이터베이스 준비 확인
    echo "Standby 데이터베이스 준비 및 복제 설정을 기다리는 중..."
    max_wait=120
    counter=0
    while [ $counter -lt $max_wait ]; do
        if docker exec vue-postgres-standby pg_isready -U postgres &>/dev/null; then
            # 복제 상태 확인
            if docker exec vue-postgres-standby psql -U postgres -c "SELECT pg_is_in_recovery();" | grep -q "t"; then
                echo "Standby 데이터베이스가 준비되었고 복제가 활성화되었습니다."
                break
            fi
        fi
        sleep 2
        counter=$((counter+2))
        echo -n "."
    done
    
    if [ $counter -ge $max_wait ]; then
        echo ""
        echo "Standby 데이터베이스 준비 상태를 확인할 수 없습니다. 로그를 확인해보세요: docker logs vue-postgres-standby"
    else
        echo ""
        echo "프로덕션 데이터베이스가 성공적으로 시작되었습니다."
        echo "Primary: postgres://postgres:prodpassword@localhost:5432/vue_prod"
        echo "Standby (읽기 전용): postgres://postgres:prodpassword@localhost:5433/vue_prod"
    fi
fi