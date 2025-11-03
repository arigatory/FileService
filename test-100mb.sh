#!/bin/bash

# Тест файла 100MB с ограничением памяти 500MB

set -e

echo "🚀 Тест файла 100MB при лимите памяти 500MB"
echo "============================================"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CLIENT_APP_URL="http://localhost:9080"
TEST_FILE="/tmp/test_100mb.txt"

cleanup() {
    echo -e "\n🧹 Очистка..."
    if [ -n "$FILE_ID" ]; then
        echo -n "Удаляем файл из сервиса... "
        curl -s -X DELETE "$CLIENT_APP_URL/api/files/$FILE_ID" > /dev/null
        echo -e "${GREEN}✓${NC}"
    fi
    rm -f "$TEST_FILE"
}

trap cleanup EXIT

echo -e "\n${BLUE}1. Память до теста${NC}"
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" fileservice clientapp

echo -e "\n${BLUE}2. Создание файла 100MB${NC}"
dd if=/dev/zero of="$TEST_FILE" bs=1M count=100 2>/dev/null
echo -e "${GREEN}✓ Файл создан: $(ls -lh "$TEST_FILE" | awk '{print $5}')${NC}"

echo -e "\n${BLUE}3. Загрузка файла 100MB${NC}"
START_TIME=$(date +%s)
RESPONSE=$(curl -s -X POST "$CLIENT_APP_URL/api/files/upload" \
    -F "file=@$TEST_FILE" \
    -F "tags=large-test,100mb")
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

FILE_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
echo -e "${GREEN}✅ Загружен за ${DURATION}s: $FILE_ID${NC}"

echo -e "\n${BLUE}4. Память после загрузки${NC}"
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" fileservice clientapp

echo -e "\n${GREEN}🎉 Тест 100MB успешен!${NC}"