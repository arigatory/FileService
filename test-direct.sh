#!/bin/bash

# Простой тест прямого обращения к основному файловому сервису
# Для сравнения с end-to-end тестом через ClientApp

set -e

echo "📡 Тест прямого обращения к FileService API"
echo "============================================"

GREEN='\033[0;32m'
NC='\033[0m'

API_URL="http://localhost:8080"
TEST_FILE="/tmp/direct_test.txt"

echo "Test content for direct API call" > "$TEST_FILE"

echo -n "Загрузка через прямой API... "
RESPONSE=$(curl -s -X POST "$API_URL/api/files/upload" \
    -F "file=@$TEST_FILE" \
    -F "tags=direct,test")

FILE_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
echo -e "${GREEN}✓ ID: $FILE_ID${NC}"

echo -n "Удаление... "
curl -s -X DELETE "$API_URL/api/files/$FILE_ID" > /dev/null
echo -e "${GREEN}✓ Удален${NC}"

rm -f "$TEST_FILE"
echo -e "${GREEN}🎉 Прямой тест завершен${NC}"