#!/bin/bash

# End-to-End тест файлового сервиса через клиентское приложение
# Этот скрипт тестирует всю цепочку: ClientApp -> FileService.Client -> FileService.WebApi -> MinIO

set -e

echo "🚀 Начинаем End-to-End тестирование файлового сервиса"
echo "========================================================"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLIENT_APP_URL="http://localhost:9080"
TEST_FILE="/tmp/e2e_test_file.txt"
DOWNLOADED_FILE="/tmp/e2e_downloaded_file.txt"

# Функция для проверки доступности сервиса
check_service() {
    local url=$1
    local name=$2
    echo -n "Проверяем доступность $name... "
    
    if curl -s -f "$url/swagger/index.html" > /dev/null; then
        echo -e "${GREEN}✓ Доступен${NC}"
        return 0
    else
        echo -e "${RED}✗ Недоступен${NC}"
        return 1
    fi
}

# Функция для создания тестового файла
create_test_file() {
    echo -n "Создаем тестовый файл... "
    cat > "$TEST_FILE" << EOF
Это тестовый файл для End-to-End тестирования
Создан: $(date)
Содержит UTF-8 текст с русскими символами: Привет, мир! 🌍
EOF
    echo -e "${GREEN}✓ Создан${NC}"
}

# Функция для очистки
cleanup() {
    echo "🧹 Очистка временных файлов..."
    rm -f "$TEST_FILE" "$DOWNLOADED_FILE"
}

# Функция для парсинга ID из JSON ответа
extract_file_id() {
    echo "$1" | grep -o '"id":"[^"]*"' | cut -d'"' -f4
}

# Функция для проверки JSON ответа
validate_json_response() {
    local response="$1"
    local description="$2"
    
    if echo "$response" | jq . > /dev/null 2>&1; then
        echo -e "${GREEN}✓ $description - валидный JSON${NC}"
        return 0
    else
        echo -e "${RED}✗ $description - невалидный JSON${NC}"
        echo "Ответ: $response"
        return 1
    fi
}

# Установка обработчика для очистки при выходе
trap cleanup EXIT

echo -e "\n${BLUE}1. Проверка доступности сервисов${NC}"
check_service "$CLIENT_APP_URL" "ClientApp (порт 9080)" || {
    echo -e "${RED}Ошибка: ClientApp недоступен. Запустите docker-compose up -d${NC}"
    exit 1
}

echo -e "\n${BLUE}2. Подготовка тестовых данных${NC}"
create_test_file

echo -e "\n${BLUE}3. Тест загрузки файла через ClientApp${NC}"
echo -n "Загружаем файл... "
UPLOAD_RESPONSE=$(curl -s -X POST "$CLIENT_APP_URL/api/files/upload" \
    -H "Content-Type: multipart/form-data" \
    -F "file=@$TEST_FILE" \
    -F "tags=e2e,test,$(date +%s)")

if [ $? -eq 0 ] && [ -n "$UPLOAD_RESPONSE" ]; then
    echo -e "${GREEN}✓ Успешно${NC}"
    validate_json_response "$UPLOAD_RESPONSE" "Ответ загрузки"
    
    FILE_ID=$(extract_file_id "$UPLOAD_RESPONSE")
    if [ -n "$FILE_ID" ]; then
        echo -e "📄 ID загруженного файла: ${YELLOW}$FILE_ID${NC}"
        echo "📋 Полный ответ: $UPLOAD_RESPONSE"
    else
        echo -e "${RED}✗ Не удалось извлечь ID файла${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Ошибка при загрузке${NC}"
    echo "Ответ: $UPLOAD_RESPONSE"
    exit 1
fi

echo -e "\n${BLUE}4. Тест получения информации о файле${NC}"
echo -n "Получаем информацию о файле... "
INFO_RESPONSE=$(curl -s -X GET "$CLIENT_APP_URL/api/files/$FILE_ID/info")

if [ $? -eq 0 ] && [ -n "$INFO_RESPONSE" ]; then
    echo -e "${GREEN}✓ Успешно${NC}"
    validate_json_response "$INFO_RESPONSE" "Информация о файле"
    echo "📋 Информация о файле: $INFO_RESPONSE"
else
    echo -e "${RED}✗ Ошибка при получении информации${NC}"
    echo "Ответ: $INFO_RESPONSE"
    exit 1
fi

echo -e "\n${BLUE}5. Тест скачивания файла${NC}"
echo -n "Скачиваем файл... "
HTTP_CODE=$(curl -s -w "%{http_code}" -X GET "$CLIENT_APP_URL/api/files/$FILE_ID/download" -o "$DOWNLOADED_FILE")

if [ "$HTTP_CODE" = "200" ] && [ -f "$DOWNLOADED_FILE" ]; then
    echo -e "${GREEN}✓ Успешно${NC}"
    
    echo -n "Проверяем содержимое... "
    if diff -q "$TEST_FILE" "$DOWNLOADED_FILE" > /dev/null; then
        echo -e "${GREEN}✓ Содержимое совпадает${NC}"
    else
        echo -e "${RED}✗ Содержимое не совпадает${NC}"
        echo "Оригинал:"
        cat "$TEST_FILE"
        echo -e "\nСкачанный:"
        cat "$DOWNLOADED_FILE"
        exit 1
    fi
else
    echo -e "${RED}✗ Ошибка при скачивании (HTTP: $HTTP_CODE)${NC}"
    exit 1
fi

echo -e "\n${BLUE}6. Тест удаления файла${NC}"
echo -n "Удаляем файл... "
DELETE_HTTP_CODE=$(curl -s -w "%{http_code}" -X DELETE "$CLIENT_APP_URL/api/files/$FILE_ID" -o /dev/null)

if [ "$DELETE_HTTP_CODE" = "200" ] || [ "$DELETE_HTTP_CODE" = "204" ]; then
    echo -e "${GREEN}✓ Успешно${NC}"
else
    echo -e "${RED}✗ Ошибка при удалении (HTTP: $DELETE_HTTP_CODE)${NC}"
    exit 1
fi

echo -e "\n${BLUE}7. Проверка, что файл действительно удален${NC}"
echo -n "Проверяем удаление... "
CHECK_HTTP_CODE=$(curl -s -w "%{http_code}" -X GET "$CLIENT_APP_URL/api/files/$FILE_ID/info" -o /dev/null)

if [ "$CHECK_HTTP_CODE" = "404" ]; then
    echo -e "${GREEN}✓ Файл удален корректно${NC}"
else
    echo -e "${RED}✗ Файл не был удален (HTTP: $CHECK_HTTP_CODE)${NC}"
    exit 1
fi

echo -e "\n${GREEN}🎉 Все End-to-End тесты прошли успешно!${NC}"
echo "========================================================"
echo -e "${BLUE}Протестированная цепочка:${NC}"
echo "1. ClientApp (порт 9080) ✓"
echo "2. FileService.Client библиотека ✓"  
echo "3. FileService.WebApi (порт 8080) ✓"
echo "4. MinIO хранилище ✓"
echo ""
echo -e "${YELLOW}Все компоненты работают корректно!${NC}"