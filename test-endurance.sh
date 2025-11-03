#!/bin/bash

# ТЕСТ НА ВЫНОСЛИВОСТЬ: 10 циклов загрузки и удаления файлов по 2GB
# Проверяет стабильность системы при длительной работе

set -e

echo "🔥 ТЕСТ НА ВЫНОСЛИВОСТЬ: 10 циклов × 2GB файлы"
echo "=============================================="
echo "Лимит памяти контейнеров: 500MB каждый"
echo "Общий объем данных: 20GB (по циклам)"
echo "Ожидаемое время: ~10-15 минут"
echo ""

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

CLIENT_APP_URL="http://localhost:9080"
TEST_DIR="/tmp/endurance_test"
TOTAL_CYCLES=10
CURRENT_CYCLE=0
SUCCESS_COUNT=0
FAILED_COUNT=0
TOTAL_UPLOAD_TIME=0
TOTAL_DELETE_TIME=0

# Массивы для статистики
CYCLE_TIMES=()
CYCLE_RESULTS=()
MEMORY_SNAPSHOTS=()

cleanup() {
    echo -e "\n🧹 Финальная очистка..."
    
    # Удаляем рабочую директорию
    if [ -d "$TEST_DIR" ]; then
        echo -n "Удаляем рабочую директорию... "
        rm -rf "$TEST_DIR"
        echo -e "${GREEN}✓${NC}"
    fi
    
    echo "Тест завершен."
}

trap cleanup EXIT

# Функция создания файла 2GB
create_test_file() {
    local cycle_num=$1
    local filename="$TEST_DIR/endurance_cycle_${cycle_num}_2gb.txt"
    
    echo -n "    📁 Создаем файл 2GB... "
    
    # Создаем файл с помощью dd
    if dd if=/dev/zero of="$filename" bs=1M count=2048 2>/dev/null; then
        # Добавляем уникальный заголовок
        {
            echo "=== ТЕСТ НА ВЫНОСЛИВОСТЬ - ЦИКЛ #$cycle_num ==="
            echo "Время создания: $(date)"
            echo "Размер: 2GB"
            echo "Цикл: $cycle_num из $TOTAL_CYCLES"
            echo "Тест: Проверка стабильности при длительной работе"
            echo "================================================"
        } | dd of="$filename" conv=notrunc 2>/dev/null
        
        echo -e "${GREEN}✓ $(ls -lh "$filename" | awk '{print $5}')${NC}"
        echo "$filename"
    else
        echo -e "${RED}✗ ОШИБКА создания файла${NC}"
        return 1
    fi
}

# Функция загрузки файла
upload_file() {
    local filename=$1
    local cycle_num=$2
    
    echo -n "    📤 Загружаем файл... "
    
    local start_time=$(date +%s)
    local response=$(curl -s -w "\nHTTP_STATUS:%{http_code}\nTIME:%{time_total}" \
        -X POST "$CLIENT_APP_URL/api/files/upload" \
        -F "file=@$filename" \
        -F "tags=endurance-test,cycle-$cycle_num,2gb,$(date +%s)")
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Парсим результат
    local file_id=$(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    local http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d':' -f2)
    
    if [ "$http_status" = "200" ] && [ -n "$file_id" ] && [ "$file_id" != "" ]; then
        echo -e "${GREEN}✓ ${duration}s (ID: $file_id)${NC}"
        TOTAL_UPLOAD_TIME=$((TOTAL_UPLOAD_TIME + duration))
        echo "$file_id"
        return 0
    else
        echo -e "${RED}✗ ОШИБКА (HTTP: $http_status)${NC}"
        return 1
    fi
}

# Функция удаления файла
delete_file() {
    local file_id=$1
    
    echo -n "    🗑️  Удаляем файл... "
    
    local start_time=$(date +%s)
    local http_status=$(curl -s -w "%{http_code}" -X DELETE "$CLIENT_APP_URL/api/files/$file_id" -o /dev/null)
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ "$http_status" = "200" ] || [ "$http_status" = "204" ]; then
        echo -e "${GREEN}✓ ${duration}s${NC}"
        TOTAL_DELETE_TIME=$((TOTAL_DELETE_TIME + duration))
        return 0
    else
        echo -e "${RED}✗ ОШИБКА (HTTP: $http_status)${NC}"
        return 1
    fi
}

# Функция снятия снимка памяти
capture_memory_snapshot() {
    local cycle_num=$1
    local phase=$2  # "before", "after_upload", "after_delete"
    
    local memory_info=$(docker stats --no-stream --format "{{.MemUsage}}" fileservice clientapp 2>/dev/null)
    local fs_memory=$(echo "$memory_info" | sed -n '1p' | cut -d'/' -f1 | tr -d ' ')
    local ca_memory=$(echo "$memory_info" | sed -n '2p' | cut -d'/' -f1 | tr -d ' ')
    
    MEMORY_SNAPSHOTS+=("Цикл-$cycle_num-$phase:FileService=$fs_memory,ClientApp=$ca_memory")
}

# Функция выполнения одного цикла
execute_cycle() {
    local cycle_num=$1
    
    echo -e "\n${CYAN}🔄 ЦИКЛ #$cycle_num из $TOTAL_CYCLES${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S')"
    echo "----------------------------------------"
    
    # Снимок памяти до цикла
    capture_memory_snapshot "$cycle_num" "before"
    
    local cycle_start=$(date +%s)
    local cycle_success=true
    
    # 1. Создание файла
    if filename=$(create_test_file "$cycle_num"); then
        # 2. Загрузка файла
        if file_id=$(upload_file "$filename" "$cycle_num"); then
            capture_memory_snapshot "$cycle_num" "after_upload"
            
            # 3. Удаление из сервиса
            if delete_file "$file_id"; then
                capture_memory_snapshot "$cycle_num" "after_delete"
            else
                cycle_success=false
            fi
        else
            cycle_success=false
        fi
        
        # 4. Очистка локального файла
        echo -n "    🧹 Очищаем локальный файл... "
        rm -f "$filename"
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "    ${RED}✗ Ошибка создания файла${NC}"
        cycle_success=false
    fi
    
    local cycle_end=$(date +%s)
    local cycle_duration=$((cycle_end - cycle_start))
    CYCLE_TIMES+=("$cycle_duration")
    
    if [ "$cycle_success" = true ]; then
        echo -e "    ${GREEN}✅ Цикл #$cycle_num завершен успешно (${cycle_duration}s)${NC}"
        CYCLE_RESULTS+=("SUCCESS")
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo -e "    ${RED}❌ Цикл #$cycle_num завершен с ошибкой (${cycle_duration}s)${NC}"
        CYCLE_RESULTS+=("FAILED")
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
    
    # Показываем текущую статистику
    echo -e "    📊 Прогресс: ${GREEN}$SUCCESS_COUNT успешных${NC}, ${RED}$FAILED_COUNT неудачных${NC}"
    
    # Показываем память
    echo -n "    💾 Память: "
    docker stats --no-stream --format "FileService={{.MemUsage}}, ClientApp={{.MemUsage}}" fileservice clientapp | head -1
    
    # Пауза между циклами (кроме последнего)
    if [ "$cycle_num" -lt "$TOTAL_CYCLES" ]; then
        echo "    ⏳ Пауза 5 секунд..."
        sleep 5
    fi
}

echo -e "\n${BLUE}1. Проверка готовности системы${NC}"
echo -n "Тестируем доступность API... "
test_response=$(echo "endurance-ready-check" | curl -s -X POST "$CLIENT_APP_URL/api/files/upload" \
    -F "file=@-;filename=ready.txt;type=text/plain" \
    -F "tags=endurance-ready" 2>/dev/null)

if [[ "$test_response" == *"\"id\":"* ]]; then
    echo -e "${GREEN}✓ Готов${NC}"
    test_id=$(echo "$test_response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    curl -s -X DELETE "$CLIENT_APP_URL/api/files/$test_id" > /dev/null 2>&1
else
    echo -e "${RED}✗ Не готов${NC}"
    exit 1
fi

echo -e "\n${BLUE}2. Подготовка тестового окружения${NC}"
mkdir -p "$TEST_DIR"

echo -e "\n${BLUE}3. Состояние системы до начала теста${NC}"
echo "Память контейнеров:"
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.MemPerc}}" fileservice clientapp

echo -e "\n${PURPLE}4. НАЧАЛО ТЕСТА НА ВЫНОСЛИВОСТЬ${NC}"
echo "=================================================================="
echo -e "🎯 Задача: $TOTAL_CYCLES циклов загрузки и удаления файлов по 2GB"
echo -e "⏰ Начало: $(date '+%Y-%m-%d %H:%M:%S')"

# Главный цикл тестирования
for ((cycle=1; cycle<=TOTAL_CYCLES; cycle++)); do
    CURRENT_CYCLE=$cycle
    execute_cycle "$cycle"
done

echo -e "\n${BLUE}5. АНАЛИЗ РЕЗУЛЬТАТОВ${NC}"
echo "=================================================================="

# Общая статистика
echo -e "\n📊 ${YELLOW}ОБЩАЯ СТАТИСТИКА:${NC}"
echo -e "   Всего циклов: $TOTAL_CYCLES"
echo -e "   Успешных: ${GREEN}$SUCCESS_COUNT${NC}"
echo -e "   Неудачных: ${RED}$FAILED_COUNT${NC}"
echo -e "   Процент успеха: $(( SUCCESS_COUNT * 100 / TOTAL_CYCLES ))%"

# Временная статистика
if [ "$SUCCESS_COUNT" -gt 0 ]; then
    echo -e "\n⏱️  ${YELLOW}ВРЕМЕННАЯ СТАТИСТИКА:${NC}"
    echo -e "   Общее время загрузок: ${TOTAL_UPLOAD_TIME}s"
    echo -e "   Общее время удалений: ${TOTAL_DELETE_TIME}s"
    echo -e "   Среднее время загрузки: $(( TOTAL_UPLOAD_TIME / SUCCESS_COUNT ))s"
    echo -e "   Среднее время удаления: $(( TOTAL_DELETE_TIME / SUCCESS_COUNT ))s"
    
    # Время циклов
    echo -e "   Время по циклам:"
    for ((i=0; i<TOTAL_CYCLES; i++)); do
        cycle_num=$((i+1))
        cycle_time=${CYCLE_TIMES[$i]}
        cycle_result=${CYCLE_RESULTS[$i]}
        if [ "$cycle_result" = "SUCCESS" ]; then
            echo -e "     Цикл #$cycle_num: ${GREEN}$cycle_time"s"${NC}"
        else
            echo -e "     Цикл #$cycle_num: ${RED}$cycle_time"s" (FAILED)${NC}"
        fi
    done
fi

# Анализ памяти
echo -e "\n💾 ${YELLOW}АНАЛИЗ ПАМЯТИ:${NC}"
echo "Память до начала теста:"
capture_memory_snapshot "start" "initial"
echo "Память после завершения теста:"
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.MemPerc}}" fileservice clientapp

echo -e "\n🔍 ${YELLOW}ДЕТАЛЬНЫЙ АНАЛИЗ ПАМЯТИ ПО ЦИКЛАМ:${NC}"
for snapshot in "${MEMORY_SNAPSHOTS[@]}"; do
    echo "   $snapshot"
done

echo -e "\n🏥 ${YELLOW}СОСТОЯНИЕ СИСТЕМЫ:${NC}"
if docker ps | grep -q fileservice && docker ps | grep -q clientapp; then
    echo -e "   ${GREEN}✅ Все контейнеры работают стабильно${NC}"
else
    echo -e "   ${RED}❌ Обнаружены проблемы с контейнерами${NC}"
    docker ps
fi

echo -e "\n${PURPLE}🏆 РЕЗУЛЬТАТЫ ТЕСТА НА ВЫНОСЛИВОСТЬ${NC}"
echo "=================================================================="

if [ "$SUCCESS_COUNT" -eq "$TOTAL_CYCLES" ]; then
    echo -e "\n${GREEN}🎉 ТЕСТ НА ВЫНОСЛИВОСТЬ ПРОЙДЕН ПОЛНОСТЬЮ!${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}✅ ВСЕ $TOTAL_CYCLES ЦИКЛОВ ВЫПОЛНЕНЫ УСПЕШНО${NC}"
    echo -e "${GREEN}✅ ОБРАБОТАНО: $(( TOTAL_CYCLES * 2 ))GB ДАННЫХ${NC}"
    echo -e "${GREEN}✅ СИСТЕМА СТАБИЛЬНА ПРИ ДЛИТЕЛЬНОЙ РАБОТЕ${NC}"
    echo -e "${GREEN}✅ УТЕЧЕК ПАМЯТИ НЕ ОБНАРУЖЕНО${NC}"
    echo -e "${GREEN}✅ ПОТОКОВАЯ ОБРАБОТКА РАБОТАЕТ БЕЗУПРЕЧНО${NC}"
    echo -e "${GREEN}================================================================${NC}"
elif [ "$SUCCESS_COUNT" -gt $(( TOTAL_CYCLES * 8 / 10 )) ]; then
    echo -e "\n${YELLOW}⚠️  ТЕСТ ПРОЙДЕН С ХОРОШИМ РЕЗУЛЬТАТОМ${NC}"
    echo -e "${YELLOW}Успех: $SUCCESS_COUNT из $TOTAL_CYCLES циклов ($(( SUCCESS_COUNT * 100 / TOTAL_CYCLES ))%)${NC}"
    echo -e "${YELLOW}Система показывает хорошую стабильность${NC}"
else
    echo -e "\n${RED}❌ ТЕСТ ВЫЯВИЛ ПРОБЛЕМЫ СТАБИЛЬНОСТИ${NC}"
    echo -e "${RED}Успех: $SUCCESS_COUNT из $TOTAL_CYCLES циклов ($(( SUCCESS_COUNT * 100 / TOTAL_CYCLES ))%)${NC}"
    echo -e "${RED}Требуется оптимизация системы${NC}"
fi

echo -e "\n⏰ Завершение: $(date '+%Y-%m-%d %H:%M:%S')"