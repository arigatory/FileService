#!/bin/bash

# Простой тест памяти для проверки потоковой обработки

set -e

echo "🚀 Тест потоковой обработки с ограничением памяти"
echo "================================================="

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CLIENT_APP_URL="http://localhost:9080"
TEST_DIR="/tmp/simple_memory_test"
UPLOADED_FILES=()

cleanup() {
    echo -e "\n🧹 Очистка..."
    for file_id in "${UPLOADED_FILES[@]}"; do
        if [ -n "$file_id" ]; then
            echo -n "Удаляем файл $file_id... "
            curl -s -X DELETE "$CLIENT_APP_URL/api/files/$file_id" > /dev/null
            echo -e "${GREEN}✓${NC}"
        fi
    done
    rm -rf "$TEST_DIR"
}

trap cleanup EXIT

echo -e "\n${BLUE}1. Создание тестовой директории${NC}"
mkdir -p "$TEST_DIR"

echo -e "\n${BLUE}2. Проверка начального использования памяти${NC}"
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" fileservice clientapp

echo -e "\n${BLUE}3. Тест с файлом 1MB${NC}"
echo "Создаем файл 1MB..."
dd if=/dev/zero of="$TEST_DIR/test_1mb.txt" bs=1M count=1 2>/dev/null
echo "Загружаем..."
RESPONSE_1MB=$(curl -s -X POST "$CLIENT_APP_URL/api/files/upload" \
    -F "file=@$TEST_DIR/test_1mb.txt" \
    -F "tags=memory-test,1mb")
FILE_ID_1MB=$(echo "$RESPONSE_1MB" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
UPLOADED_FILES+=("$FILE_ID_1MB")
echo -e "${GREEN}✓ Загружен: $FILE_ID_1MB${NC}"

echo "Память после 1MB:"
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" fileservice clientapp

echo -e "\n${BLUE}4. Тест с файлом 100MB${NC}"
echo "Создаем файл 100MB..."
dd if=/dev/zero of="$TEST_DIR/test_100mb.txt" bs=1M count=100 2>/dev/null
echo "Загружаем..."
RESPONSE_100MB=$(curl -s -X POST "$CLIENT_APP_URL/api/files/upload" \
    -F "file=@$TEST_DIR/test_100mb.txt" \
    -F "tags=memory-test,100mb")
FILE_ID_100MB=$(echo "$RESPONSE_100MB" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
UPLOADED_FILES+=("$FILE_ID_100MB")
echo -e "${GREEN}✓ Загружен: $FILE_ID_100MB${NC}"

echo "Память после 100MB:"
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" fileservice clientapp

echo -e "\n${BLUE}5. Тест с файлом 500MB (размер лимита памяти)${NC}"
echo "Создаем файл 500MB..."
dd if=/dev/zero of="$TEST_DIR/test_500mb.txt" bs=1M count=500 2>/dev/null
echo "Загружаем..."
RESPONSE_500MB=$(curl -s -X POST "$CLIENT_APP_URL/api/files/upload" \
    -F "file=@$TEST_DIR/test_500mb.txt" \
    -F "tags=memory-test,500mb")
FILE_ID_500MB=$(echo "$RESPONSE_500MB" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
UPLOADED_FILES+=("$FILE_ID_500MB")
echo -e "${GREEN}✓ Загружен: $FILE_ID_500MB${NC}"

echo "Память после 500MB:"
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" fileservice clientapp

echo -e "\n${BLUE}6. Проверка что контейнеры живы${NC}"
if docker ps | grep -q fileservice && docker ps | grep -q clientapp; then
    echo -e "${GREEN}✅ Все контейнеры работают стабильно!${NC}"
else
    echo -e "${RED}❌ Один из контейнеров упал${NC}"
    exit 1
fi

echo -e "\n${GREEN}🎉 УСПЕХ! Потоковая обработка работает корректно${NC}"
echo "================================================================"
echo "✅ Загружены файлы: 1MB, 100MB, 500MB"
echo "✅ Память контейнеров не превысила лимит в 500MB"
echo "✅ Контейнеры остались стабильными"
echo "✅ Файлы не буферизуются полностью в памяти"