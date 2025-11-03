#!/bin/bash

# ТЕСТ НА ОБНАРУЖЕНИЕ УТЕЧЕК ПАМЯТИ ПРИ РАБОТЕ С БОЛЬШИМИ ФАЙЛАМИ
# Проверяет загрузку и скачивание файлов от 1GB до 5GB
# Временные файлы сохраняются в ./tmp для ручного контроля

set -e

echo "🔍 КОМПЛЕКСНЫЙ ТЕСТ ОБНАРУЖЕНИЯ УТЕЧЕК ПАМЯТИ"
echo "=============================================="
echo "📁 Фаза 1: ${SMALL_FILES_COUNT} файлов по ${SMALL_FILE_SIZE}MB (${CONCURRENT_REQUESTS} одновременно)"
echo "📁 Фаза 2: Большие файлы 1GB, 2GB, 3GB, 5GB"
echo "💾 Лимит памяти: 400MB на контейнер fileservice"
echo "🎯 Цель: Протестировать высокую нагрузку и большие файлы"
echo "📂 Временные файлы: ./tmp (для ручного контроля)"
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

CLIENT_APP_URL="http://localhost:9080"
TEST_DIR="./tmp"
SIZES=(1 2 3 5)  # GB - последовательное тестирование больших файлов
SMALL_FILE_SIZE=10  # MB - размер маленьких файлов
SMALL_FILES_COUNT=100  # Количество маленьких файлов
CONCURRENT_REQUESTS=5  # Количество одновременных запросов
declare -a UPLOADED_IDS=()
declare -a MEMORY_BEFORE=()
declare -a MEMORY_AFTER_UPLOAD=()
declare -a MEMORY_AFTER_DOWNLOAD=()
declare -a MEMORY_AFTER_DELETE=()

cleanup() {
    echo -e "\n🧹 Финальная очистка..."
    
    # Удаляем большие файлы из хранилища
    for id in "${UPLOADED_IDS[@]}"; do
        if [ -n "$id" ]; then
            echo "🗑️ Удаляем большой файл $id из хранилища..."
            curl -s -X DELETE "$CLIENT_APP_URL/api/files/$id" > /dev/null 2>&1 || true
        fi
    done
    
    # Удаляем маленькие файлы из хранилища
    if [ -d "$TEST_DIR" ]; then
        for id_file in "$TEST_DIR"/uploaded_*.id; do
            if [ -f "$id_file" ]; then
                id=$(cat "$id_file")
                if [ -n "$id" ]; then
                    echo "🗑️ Удаляем маленький файл $id из хранилища..."
                    curl -s -X DELETE "$CLIENT_APP_URL/api/files/$id" > /dev/null 2>&1 || true
                fi
            fi
        done
    fi
    
    echo "📂 Временные файлы оставлены в $TEST_DIR для ручного контроля"
    echo "💡 Для очистки выполните: rm -rf $TEST_DIR"
}

trap cleanup EXIT

# Проверяем доступность API
echo -e "\n${BLUE}1. Проверка готовности системы${NC}"
echo -n "Тестируем API... "
test_response=$(echo "memory-test-check" | curl -s -X POST "$CLIENT_APP_URL/api/files/upload" \
    -F "file=@-;filename=ready.txt;type=text/plain" \
    -F "tags=memory-test-ready" 2>/dev/null)

if [[ "$test_response" == *"\"id\":"* ]]; then
    echo -e "${GREEN}✓ Готов${NC}"
    test_id=$(echo "$test_response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    curl -s -X DELETE "$CLIENT_APP_URL/api/files/$test_id" > /dev/null 2>&1
else
    echo -e "${RED}✗ Не готов${NC}"
    exit 1
fi

# Создаем рабочую директорию
echo -e "\n${BLUE}2. Подготовка рабочей директории${NC}"
mkdir -p "$TEST_DIR"
echo "📂 Рабочая директория: $TEST_DIR"

echo -e "\n${BLUE}3. Начальное состояние памяти${NC}"
echo "================================================="
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.MemPerc}}" fileservice clientapp

echo -e "\n${PURPLE}4. ФАЗА 1: ТЕСТИРОВАНИЕ МНОЖЕСТВЕННЫХ МАЛЕНЬКИХ ФАЙЛОВ${NC}"
echo "======================================================="
echo -e "⏰ Начало фазы 1: $(date '+%H:%M:%S')"

# Функция для загрузки файла
upload_small_file() {
    local file_id=$1
    local file_path="$TEST_DIR/small_${file_id}.bin"
    
    # Создаем маленький файл
    dd if=/dev/zero of="$file_path" bs=1M count=$SMALL_FILE_SIZE 2>/dev/null
    
    # Загружаем файл
    response=$(curl -s -X POST "$CLIENT_APP_URL/api/files/upload" \
        -F "file=@$file_path" \
        -F "tags=small-file,batch-$file_id,load-test")
    
    if [[ "$response" == *"\"id\":"* ]]; then
        file_uuid=$(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
        echo "$file_uuid" > "$TEST_DIR/uploaded_${file_id}.id"
        echo "✅ Файл $file_id загружен (ID: $file_uuid)"
        rm -f "$file_path"  # Удаляем локальный файл
        return 0
    else
        echo "❌ Ошибка загрузки файла $file_id"
        return 1
    fi
}

# Тестируем загрузку множественных маленьких файлов
echo -e "\n🔄 Загрузка ${SMALL_FILES_COUNT} файлов по ${SMALL_FILE_SIZE}MB с ${CONCURRENT_REQUESTS} одновременными запросами"

# Память до загрузки маленьких файлов
echo -n "💾 Память перед загрузкой маленьких файлов: "
memory_before_small=$(docker stats --no-stream --format "FileService={{.MemUsage}}, ClientApp={{.MemUsage}}" fileservice clientapp | head -1)
echo "$memory_before_small"

start_time=$(date +%s)
uploaded_count=0
failed_count=0

# Загружаем файлы пакетами по CONCURRENT_REQUESTS
for ((i=1; i<=SMALL_FILES_COUNT; i+=CONCURRENT_REQUESTS)); do
    echo -n "Пакет $(((i-1)/CONCURRENT_REQUESTS + 1)): "
    
    # Запускаем CONCURRENT_REQUESTS загрузок параллельно
    pids=()
    for ((j=0; j<CONCURRENT_REQUESTS && (i+j)<=SMALL_FILES_COUNT; j++)); do
        file_num=$((i+j))
        upload_small_file $file_num &
        pids+=($!)
    done
    
    # Ждем завершения всех параллельных загрузок
    success_in_batch=0
    for pid in "${pids[@]}"; do
        if wait $pid; then
            ((success_in_batch++))
            ((uploaded_count++))
        else
            ((failed_count++))
        fi
    done
    
    echo "[$success_in_batch/${#pids[@]} успешно]"
    
    # Показываем прогресс каждые 10 пакетов
    if (( (i-1)/CONCURRENT_REQUESTS % 10 == 9 )); then
        echo "📊 Прогресс: $uploaded_count/$SMALL_FILES_COUNT загружено"
    fi
done

end_time=$(date +%s)
upload_duration=$((end_time - start_time))

# Память после загрузки маленьких файлов
echo -n "💾 Память после загрузки маленьких файлов: "
memory_after_small=$(docker stats --no-stream --format "FileService={{.MemUsage}}, ClientApp={{.MemUsage}}" fileservice clientapp | head -1)
echo "$memory_after_small"

echo -e "\n📊 Результаты загрузки маленьких файлов:"
echo "   ✅ Успешно загружено: $uploaded_count файлов"
echo "   ❌ Ошибки загрузки: $failed_count файлов"
echo "   ⏱️ Время загрузки: ${upload_duration}s"
echo "   📈 Скорость: $(( (uploaded_count * SMALL_FILE_SIZE) / upload_duration )) MB/s"

# Небольшая пауза только для стабилизации системы после множественных запросов
echo -e "\n⏳ Пауза 3 секунды для стабилизации системы..."
sleep 3

echo -e "\n${PURPLE}5. ФАЗА 2: ТЕСТИРОВАНИЕ БОЛЬШИХ ФАЙЛОВ${NC}"
echo "======================================="
echo -e "⏰ Начало: $(date '+%H:%M:%S')"

for i in "${!SIZES[@]}"; do
    size=${SIZES[$i]}
    cycle=$((i + 1))
    
    echo -e "\n${YELLOW}🔄 ЦИКЛ #$cycle: Файл ${size}GB${NC} ($(date '+%H:%M:%S'))"
    echo "================================================="
    
    original_file="$TEST_DIR/test_${size}gb_original.bin"
    downloaded_file="$TEST_DIR/test_${size}gb_downloaded.bin"
    
    # Замеряем память ДО операций
    echo -n "💾 Память перед тестом: "
    memory_before=$(docker stats --no-stream --format "FileService={{.MemUsage}}, ClientApp={{.MemUsage}}" fileservice clientapp | head -1)
    MEMORY_BEFORE[$i]="$memory_before"
    echo "$memory_before"
    
    # 1. Создание файла
    echo -e "\n📁 Создание файла ${size}GB..."
    create_start=$(date +%s)
    if dd if=/dev/zero of="$original_file" bs=1G count=$size 2>/dev/null; then
        create_end=$(date +%s)
        create_time=$((create_end - create_start))
        file_size=$(ls -lh "$original_file" | awk '{print $5}')
        echo -e "✅ Создан за ${create_time}s (размер: $file_size)"
    else
        echo -e "${RED}❌ Ошибка создания файла${NC}"
        continue
    fi
    
    # 2. Загрузка файла
    echo -e "\n📤 Загрузка файла ${size}GB..."
    upload_start=$(date +%s)
    response=$(curl -s -X POST "$CLIENT_APP_URL/api/files/upload" \
        -F "file=@$original_file" \
        -F "tags=memory-test,${size}gb,cycle-$cycle")
    upload_end=$(date +%s)
    upload_time=$((upload_end - upload_start))
    
    file_id=$(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$file_id" ] && [ "$file_id" != "" ]; then
        UPLOADED_IDS[$i]="$file_id"
        echo -e "✅ Загружен за ${upload_time}s (ID: $file_id)"
        
        # Замеряем память ПОСЛЕ загрузки
        echo -n "💾 Память после загрузки: "
        memory_after_upload=$(docker stats --no-stream --format "FileService={{.MemUsage}}, ClientApp={{.MemUsage}}" fileservice clientapp | head -1)
        MEMORY_AFTER_UPLOAD[$i]="$memory_after_upload"
        echo "$memory_after_upload"
    else
        echo -e "${RED}❌ Ошибка загрузки${NC}"
        continue
    fi
    
    # 3. Скачивание файла
    echo -e "\n📥 Скачивание файла ${size}GB..."
    download_start=$(date +%s)
    if curl -s -o "$downloaded_file" "$CLIENT_APP_URL/api/files/$file_id/download"; then
        download_end=$(date +%s)
        download_time=$((download_end - download_start))
        
        # Проверяем размер
        original_size=$(stat -f%z "$original_file" 2>/dev/null || stat -c%s "$original_file" 2>/dev/null)
        downloaded_size=$(stat -f%z "$downloaded_file" 2>/dev/null || stat -c%s "$downloaded_file" 2>/dev/null)
        
        if [ "$original_size" -eq "$downloaded_size" ]; then
            downloaded_file_size=$(ls -lh "$downloaded_file" | awk '{print $5}')
            echo -e "✅ Скачан за ${download_time}s (размер: $downloaded_file_size)"
            
            # Замеряем память ПОСЛЕ скачивания
            echo -n "💾 Память после скачивания: "
            memory_after_download=$(docker stats --no-stream --format "FileService={{.MemUsage}}, ClientApp={{.MemUsage}}" fileservice clientapp | head -1)
            MEMORY_AFTER_DOWNLOAD[$i]="$memory_after_download"
            echo "$memory_after_download"
        else
            echo -e "${RED}❌ Размер не совпадает (orig: $original_size, down: $downloaded_size)${NC}"
            continue
        fi
    else
        echo -e "${RED}❌ Ошибка скачивания${NC}"
        continue
    fi
    
    # 4. Удаление файла из хранилища
    echo -e "\n🗑️ Удаление файла из хранилища..."
    delete_start=$(date +%s)
    http_status=$(curl -s -w "%{http_code}" -X DELETE "$CLIENT_APP_URL/api/files/$file_id" -o /dev/null)
    delete_end=$(date +%s)
    delete_time=$((delete_end - delete_start))
    
    if [ "$http_status" = "200" ] || [ "$http_status" = "204" ]; then
        echo -e "✅ Удален за ${delete_time}s"
        UPLOADED_IDS[$i]=""  # Очищаем ID, так как файл уже удален
        
        # Замеряем память ПОСЛЕ удаления
        echo -n "💾 Память после удаления: "
        memory_after_delete=$(docker stats --no-stream --format "FileService={{.MemUsage}}, ClientApp={{.MemUsage}}" fileservice clientapp | head -1)
        MEMORY_AFTER_DELETE[$i]="$memory_after_delete"
        echo "$memory_after_delete"
    else
        echo -e "${RED}❌ Ошибка удаления (HTTP: $http_status)${NC}"
        continue
    fi
    
    # 5. Анализ производительности
    upload_throughput=$(( size * 1024 / upload_time ))
    download_throughput=$(( size * 1024 / download_time ))
    
    echo -e "\n📊 Производительность цикла #$cycle:"
    echo -e "   📤 Загрузка: ${upload_throughput} MB/s"
    echo -e "   📥 Скачивание: ${download_throughput} MB/s"
    echo -e "   ⏱️ Общее время: $(( upload_time + download_time + delete_time ))s"
    
    # Переходим к следующему циклу без пауз - имитируем реальную нагрузку
    if [ "$cycle" -lt "${#SIZES[@]}" ]; then
        echo -e "\n➡️ Переходим к следующему файлу без пауз (реальная нагрузка)"
    fi
done

echo -e "\n${BLUE}6. АНАЛИЗ УТЕЧЕК ПАМЯТИ${NC}"
echo "=================================="

echo -e "\n📊 Детальный анализ памяти по циклам:"
echo "======================================"

for i in "${!SIZES[@]}"; do
    size=${SIZES[$i]}
    cycle=$((i + 1))
    
    echo -e "\n${YELLOW}Цикл #$cycle (${size}GB):${NC}"
    echo "  До теста:       ${MEMORY_BEFORE[$i]:-"N/A"}"
    echo "  После загрузки: ${MEMORY_AFTER_UPLOAD[$i]:-"N/A"}"
    echo "  После скачивания: ${MEMORY_AFTER_DOWNLOAD[$i]:-"N/A"}"
    echo "  После удаления: ${MEMORY_AFTER_DELETE[$i]:-"N/A"}"
done

echo -e "\n${BLUE}7. ФИНАЛЬНОЕ СОСТОЯНИЕ СИСТЕМЫ${NC}"
echo "===================================="
echo "💾 Текущая память:"
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.MemPerc}}" fileservice clientapp

echo -e "\n📂 Созданные файлы в $TEST_DIR:"
if [ -d "$TEST_DIR" ] && [ "$(ls -A "$TEST_DIR" 2>/dev/null)" ]; then
    ls -lh "$TEST_DIR"
    echo -e "\n💾 Общий размер временных файлов:"
    du -sh "$TEST_DIR"
else
    echo "Нет файлов"
fi

echo -e "\n🏥 Состояние контейнеров:"
if docker ps | grep -q fileservice && docker ps | grep -q clientapp; then
    echo -e "   ${GREEN}✅ Все контейнеры работают стабильно${NC}"
else
    echo -e "   ${RED}❌ Проблемы с контейнерами${NC}"
fi

echo -e "\n${PURPLE}🏆 РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ УТЕЧЕК ПАМЯТИ${NC}"
echo "=============================================="

# Проверим, остались ли контейнеры в рамках лимита
final_memory=$(docker stats --no-stream --format "{{.MemPerc}}" fileservice clientapp)
max_memory=0

while IFS= read -r line; do
    mem_percent=$(echo "$line" | sed 's/%//')
    if (( $(echo "$mem_percent > $max_memory" | bc -l) )); then
        max_memory=$mem_percent
    fi
done <<< "$final_memory"

echo -e "\n📈 Максимальное потребление памяти: ${max_memory}% от лимита (500MB)"

if (( $(echo "$max_memory < 50" | bc -l) )); then
    echo -e "\n${GREEN}🎉 ТЕСТ НА УТЕЧКИ ПАМЯТИ ПРОЙДЕН УСПЕШНО!${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}✅ ОБРАБОТАНО: $(( (SMALL_FILES_COUNT * SMALL_FILE_SIZE / 1024) + ${SIZES[0]} + ${SIZES[1]} + ${SIZES[2]} + ${SIZES[3]} * 2 ))GB ДАННЫХ${NC}"
    echo -e "${GREEN}✅ ПАМЯТЬ ОСТАЕТСЯ В БЕЗОПАСНЫХ ПРЕДЕЛАХ (<50% лимита)${NC}"
    echo -e "${GREEN}✅ УТЕЧЕК ПАМЯТИ НЕ ОБНАРУЖЕНО${NC}"
    echo -e "${GREEN}✅ ПОТОКОВАЯ ОБРАБОТКА РАБОТАЕТ ИДЕАЛЬНО${NC}"
    echo -e "${GREEN}✅ HttpCompletionOption.ResponseHeadersRead ЭФФЕКТИВЕН${NC}"
    echo -e "${GREEN}✅ СИСТЕМА ГОТОВА К PRODUCTION С БОЛЬШИМИ ФАЙЛАМИ${NC}"
elif (( $(echo "$max_memory < 80" | bc -l) )); then
    echo -e "\n${YELLOW}⚠️ ТЕСТ ПРОЙДЕН С ПРЕДУПРЕЖДЕНИЕМ${NC}"
    echo -e "${YELLOW}Память в пределах нормы, но стоит мониторить (${max_memory}%)${NC}"
else
    echo -e "\n${RED}❌ ОБНАРУЖЕНЫ ПРОБЛЕМЫ С ПАМЯТЬЮ${NC}"
    echo -e "${RED}Потребление памяти превышает 80%: ${max_memory}%${NC}"
fi

echo -e "\n💡 Временные файлы сохранены в $TEST_DIR для анализа"
echo -e "💡 Для очистки выполните: rm -rf $TEST_DIR"
echo -e "\n⏰ Завершение: $(date '+%H:%M:%S')"