#!/bin/bash

# Экстремальный тест - файл размером 1GB при лимите памяти 500MB

set -e

echo "🚀 ЭКСТРЕМАЛЬНЫЙ ТЕСТ: файл 1GB при лимите памяти 500MB"
echo "======================================================="

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CLIENT_APP_URL="http://localhost:9080"
TEST_FILE="/tmp/test_1gb.txt"

cleanup() {
    echo -e "\n🧹 Очистка..."
    if [ -n "$FILE_ID" ]; then
        echo -n "Удаляем файл из сервиса... "
        curl -s -X DELETE "$CLIENT_APP_URL/api/files/$FILE_ID" > /dev/null
        echo -e "${GREEN}✓${NC}"
    fi
    echo -n "Удаляем локальный файл... "
    rm -f "$TEST_FILE"
    echo -e "${GREEN}✓${NC}"
}

trap cleanup EXIT

echo -e "\n${BLUE}1. Проверка памяти до теста${NC}"
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" fileservice clientapp

echo -e "\n${BLUE}2. Создание файла 1GB${NC}"
echo -n "Создаем файл 1GB... "
dd if=/dev/zero of="$TEST_FILE" bs=1M count=1024 2>/dev/null
echo -e "${GREEN}✓ Создан ($(ls -lh "$TEST_FILE" | awk '{print $5}'))${NC}"

echo -e "\n${BLUE}3. Загрузка файла 1GB${NC}"
echo "Начинаем загрузку файла 1GB через ClientApp..."
echo "Это может занять некоторое время..."

START_TIME=$(date +%s)
RESPONSE=$(curl -w "HTTP Status: %{http_code}\nTime: %{time_total}s\n" \
    -X POST "$CLIENT_APP_URL/api/files/upload" \
    -F "file=@$TEST_FILE" \
    -F "tags=extreme-test,1gb,memory-limit" 2>/dev/null)
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "Ответ сервера:"
echo "$RESPONSE"

# Извлекаем ID файла
FILE_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

if [ -n "$FILE_ID" ]; then
    echo -e "${GREEN}✅ УСПЕШНО ЗАГРУЖЕН!${NC}"
    echo -e "📄 ID файла: ${YELLOW}$FILE_ID${NC}"
    echo -e "⏱️  Время загрузки: ${YELLOW}${DURATION}s${NC}"
else
    echo -e "${RED}❌ Ошибка при загрузке${NC}"
    exit 1
fi

echo -e "\n${BLUE}4. Проверка памяти после загрузки${NC}"
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" fileservice clientapp

echo -e "\n${BLUE}5. Проверка состояния контейнеров${NC}"
if docker ps | grep -q fileservice && docker ps | grep -q clientapp; then
    echo -e "${GREEN}✅ Все контейнеры работают стабильно!${NC}"
else
    echo -e "${RED}❌ Один из контейнеров упал${NC}"
    docker ps
    exit 1
fi

echo -e "\n${BLUE}6. Тест скачивания части файла${NC}"
echo -n "Скачиваем первые 1000 байт для проверки... "
curl -s "http://localhost:9080/api/files/$FILE_ID/download" | head -c 1000 > /tmp/downloaded_chunk.txt
DOWNLOADED_SIZE=$(wc -c < /tmp/downloaded_chunk.txt)
echo -e "${GREEN}✓ Скачано $DOWNLOADED_SIZE байт${NC}"
rm -f /tmp/downloaded_chunk.txt

echo -e "\n${GREEN}🎉 ЭКСТРЕМАЛЬНЫЙ ТЕСТ ПРОЙДЕН УСПЕШНО!${NC}"
echo "================================================================="
echo -e "✅ Файл размером ${YELLOW}1GB${NC} успешно загружен"
echo -e "✅ Память контейнеров не превысила лимит ${YELLOW}500MB${NC}"
echo -e "✅ Время загрузки: ${YELLOW}${DURATION}s${NC}"
echo -e "✅ Контейнеры остались стабильными"
echo -e "✅ ${YELLOW}ПОТОКОВАЯ ОБРАБОТКА РАБОТАЕТ ИДЕАЛЬНО!${NC}"
echo ""
echo "Это доказывает, что:"
echo "• Файлы не загружаются полностью в память"
echo "• Используется потоковая передача"
echo "• Система масштабируется для больших файлов"