#!/bin/bash

echo "=== Тестирование FileService API ==="
echo ""

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

API_URL="http://localhost:8080"

# Функция для проверки доступности API
check_api() {
    echo -e "${BLUE}Проверяем доступность API...${NC}"
    if curl -s -f "$API_URL/swagger" > /dev/null; then
        echo -e "${GREEN}✓ API доступен${NC}"
        return 0
    else
        echo -e "${RED}✗ API недоступен. Убедитесь, что сервис запущен.${NC}"
        return 1
    fi
}

# Функция для создания тестового файла
create_test_file() {
    echo "Это тестовый файл для проверки FileService API" > test-file.txt
    echo "Дата создания: $(date)" >> test-file.txt
    echo "Содержимое для тестирования upload/download функций" >> test-file.txt
}

# Функция для загрузки файла
upload_file() {
    echo -e "${BLUE}1. Загружаем тестовый файл...${NC}"
    
    response=$(curl -s -X POST "$API_URL/api/Files/upload" \
        -F "file=@test-file.txt" \
        -F "tags=test,curl,demo")
    
    if [ $? -eq 0 ] && [[ $response == *"id"* ]]; then
        file_id=$(echo $response | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
        echo -e "${GREEN}✓ Файл загружен успешно${NC}"
        echo "Response: $response"
        echo "File ID: $file_id"
        echo ""
        return 0
    else
        echo -e "${RED}✗ Ошибка загрузки файла${NC}"
        echo "Response: $response"
        return 1
    fi
}

# Функция для получения информации о файле
get_file_info() {
    echo -e "${BLUE}2. Получаем информацию о файле...${NC}"
    
    response=$(curl -s "$API_URL/api/Files/$file_id/info")
    
    if [ $? -eq 0 ] && [[ $response == *"id"* ]]; then
        echo -e "${GREEN}✓ Информация получена успешно${NC}"
        echo "Response: $response"
        echo ""
        return 0
    else
        echo -e "${RED}✗ Ошибка получения информации${NC}"
        echo "Response: $response"
        return 1
    fi
}

# Функция для скачивания файла
download_file() {
    echo -e "${BLUE}3. Скачиваем файл...${NC}"
    
    curl -s "$API_URL/api/Files/$file_id" -o downloaded-file.txt
    
    if [ $? -eq 0 ] && [ -f downloaded-file.txt ]; then
        echo -e "${GREEN}✓ Файл скачан успешно${NC}"
        echo "Размер скачанного файла: $(wc -c < downloaded-file.txt) байт"
        echo "Содержимое:"
        cat downloaded-file.txt
        echo ""
        return 0
    else
        echo -e "${RED}✗ Ошибка скачивания файла${NC}"
        return 1
    fi
}

# Функция для сравнения файлов
compare_files() {
    echo -e "${BLUE}4. Сравниваем оригинальный и скачанный файлы...${NC}"
    
    if cmp -s test-file.txt downloaded-file.txt; then
        echo -e "${GREEN}✓ Файлы идентичны${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ Файлы отличаются${NC}"
        echo "Различия:"
        diff test-file.txt downloaded-file.txt
        echo ""
        return 1
    fi
}

# Функция для удаления файла
delete_file() {
    echo -e "${BLUE}5. Удаляем файл...${NC}"
    
    response=$(curl -s -X DELETE "$API_URL/api/Files/$file_id" -w "%{http_code}")
    http_code="${response: -3}"
    
    if [ "$http_code" = "204" ]; then
        echo -e "${GREEN}✓ Файл удален успешно${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ Ошибка удаления файла${NC}"
        echo "HTTP Code: $http_code"
        echo "Response: ${response%???}"
        return 1
    fi
}

# Функция для проверки удаления
verify_deletion() {
    echo -e "${BLUE}6. Проверяем удаление файла...${NC}"
    
    response=$(curl -s "$API_URL/api/Files/$file_id/info" -w "%{http_code}")
    http_code="${response: -3}"
    
    if [ "$http_code" = "404" ]; then
        echo -e "${GREEN}✓ Файл действительно удален${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ Файл все еще существует${NC}"
        echo "HTTP Code: $http_code"
        return 1
    fi
}

# Функция очистки
cleanup() {
    echo -e "${BLUE}Очистка временных файлов...${NC}"
    rm -f test-file.txt downloaded-file.txt
    echo -e "${GREEN}✓ Очистка завершена${NC}"
}

# Основной процесс тестирования
main() {
    # Проверяем доступность API
    if ! check_api; then
        exit 1
    fi
    
    # Создаем тестовый файл
    create_test_file
    
    # Выполняем тесты
    if upload_file && get_file_info && download_file && compare_files && delete_file && verify_deletion; then
        echo -e "${GREEN}=== Все тесты прошли успешно! ===${NC}"
        cleanup
        exit 0
    else
        echo -e "${RED}=== Некоторые тесты не прошли ===${NC}"
        cleanup
        exit 1
    fi
}

# Запускаем тесты
main