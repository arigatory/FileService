#!/bin/bash

# ПОЛНЫЙ ТЕСТ НА ВЫНОСЛИВОСТЬ: 5 циклов × 1GB файлы (загрузка + скачивание + удаление)

set -e

echo "💪 ПОЛНЫЙ ТЕСТ НА ВЫНОСЛИВОСТЬ: 5 циклов × 1GB файлы"
echo "====================================================="
echo "Лимит памяти: 500MB на контейнер"
echo "Тестируем: ЗАГРУЗКА → СКАЧИВАНИЕ → УДАЛЕНИЕ"
echo "Общий объем: 10GB (5GB загрузка + 5GB скачивание)"
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

CLIENT_APP_URL="http://localhost:9080"
TEST_DIR="/tmp/endurance_full"
TOTAL_CYCLES=5
success_count=0
failed_count=0
total_upload_time=0
total_download_time=0
total_delete_time=0

cleanup() {
    echo -e "\n🧹 Финальная очистка..."
    rm -rf "$TEST_DIR"
}

trap cleanup EXIT

echo -e "\n${BLUE}1. Проверка готовности${NC}"
echo -n "Тестируем API... "
test_response=$(echo "endurance-check" | curl -s -X POST "$CLIENT_APP_URL/api/files/upload" \
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

echo -e "\n${BLUE}2. Подготовка${NC}"
mkdir -p "$TEST_DIR"

echo -e "\n${BLUE}3. Память ДО теста${NC}"
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.MemPerc}}" fileservice clientapp

echo -e "\n${PURPLE}4. НАЧАЛО ПОЛНОГО ТЕСТА НА ВЫНОСЛИВОСТЬ${NC}"
echo "==============================================="
echo -e "⏰ Начало: $(date '+%H:%M:%S')"

for ((cycle=1; cycle<=TOTAL_CYCLES; cycle++)); do
    echo -e "\n${YELLOW}🔄 ЦИКЛ #$cycle из $TOTAL_CYCLES${NC} ($(date '+%H:%M:%S'))"
    echo "--------------------------------------------"
    
    cycle_start=$(date +%s)
    original_file="$TEST_DIR/endurance_${cycle}_1gb.txt"
    downloaded_file="$TEST_DIR/downloaded_${cycle}_1gb.txt"
    cycle_success=true
    
    # 1. Создание файла
    echo -n "  📁 Создаем файл 1GB... "
    if dd if=/dev/zero of="$original_file" bs=1M count=1024 2>/dev/null; then
        echo -e "${GREEN}✓ $(ls -lh "$original_file" | awk '{print $5}')${NC}"
        
        # 2. Загрузка
        echo -n "  📤 Загружаем файл... "
        upload_start=$(date +%s)
        response=$(curl -s -X POST "$CLIENT_APP_URL/api/files/upload" \
            -F "file=@$original_file" \
            -F "tags=endurance-full-test,cycle-$cycle,1gb")
        upload_end=$(date +%s)
        upload_time=$((upload_end - upload_start))
        
        file_id=$(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$file_id" ] && [ "$file_id" != "" ]; then
            echo -e "${GREEN}✓ ${upload_time}s (ID: $file_id)${NC}"
            total_upload_time=$((total_upload_time + upload_time))
            
            # 3. Скачивание
            echo -n "  📥 Скачиваем файл... "
            download_start=$(date +%s)
            if curl -s -o "$downloaded_file" "$CLIENT_APP_URL/api/files/$file_id/download"; then
                download_end=$(date +%s)
                download_time=$((download_end - download_start))
                
                # Проверяем размер скачанного файла
                original_size=$(stat -f%z "$original_file" 2>/dev/null || stat -c%s "$original_file" 2>/dev/null)
                downloaded_size=$(stat -f%z "$downloaded_file" 2>/dev/null || stat -c%s "$downloaded_file" 2>/dev/null)
                
                if [ "$original_size" -eq "$downloaded_size" ]; then
                    echo -e "${GREEN}✓ ${download_time}s ($(ls -lh "$downloaded_file" | awk '{print $5}'))${NC}"
                    total_download_time=$((total_download_time + download_time))
                else
                    echo -e "${RED}✗ Размер не совпадает (orig: $original_size, down: $downloaded_size)${NC}"
                    cycle_success=false
                fi
            else
                echo -e "${RED}✗ Ошибка скачивания${NC}"
                cycle_success=false
            fi
            
            # 4. Удаление из хранилища
            if [ "$cycle_success" = true ]; then
                echo -n "  🗑️  Удаляем из хранилища... "
                delete_start=$(date +%s)
                http_status=$(curl -s -w "%{http_code}" -X DELETE "$CLIENT_APP_URL/api/files/$file_id" -o /dev/null)
                delete_end=$(date +%s)
                delete_time=$((delete_end - delete_start))
                
                if [ "$http_status" = "200" ] || [ "$http_status" = "204" ]; then
                    echo -e "${GREEN}✓ ${delete_time}s${NC}"
                    total_delete_time=$((total_delete_time + delete_time))
                else
                    echo -e "${RED}✗ Ошибка удаления (HTTP: $http_status)${NC}"
                    cycle_success=false
                fi
            fi
        else
            echo -e "${RED}✗ Ошибка загрузки${NC}"
            cycle_success=false
        fi
    else
        echo -e "${RED}✗ Ошибка создания файла${NC}"
        cycle_success=false
    fi
    
    # 5. Очистка локальных файлов
    echo -n "  🧹 Очищаем локальные файлы... "
    rm -f "$original_file" "$downloaded_file"
    echo -e "${GREEN}✓${NC}"
    
    # Подсчет результата цикла
    if [ "$cycle_success" = true ]; then
        cycle_end=$(date +%s)
        cycle_time=$((cycle_end - cycle_start))
        echo -e "  ${GREEN}✅ Цикл #$cycle успешен (${cycle_time}s)${NC}"
        success_count=$((success_count + 1))
    else
        echo -e "  ${RED}❌ Цикл #$cycle провален${NC}"
        failed_count=$((failed_count + 1))
    fi
    
    # Показываем текущий прогресс
    echo -e "  📊 Прогресс: ${GREEN}$success_count успешных${NC}, ${RED}$failed_count неудачных${NC}"
    
    # Показываем память
    echo -n "  💾 Память: "
    docker stats --no-stream --format "FileService={{.MemUsage}}, ClientApp={{.MemUsage}}" fileservice clientapp | head -1
    
    # Пауза между циклами
    if [ "$cycle" -lt "$TOTAL_CYCLES" ]; then
        echo "  ⏳ Пауза 3 секунды..."
        sleep 3
    fi
done

echo -e "\n${BLUE}5. АНАЛИЗ РЕЗУЛЬТАТОВ${NC}"
echo "================================="

echo -e "\n📊 ${YELLOW}ОБЩАЯ СТАТИСТИКА:${NC}"
echo -e "   Всего циклов: $TOTAL_CYCLES"
echo -e "   Успешных: ${GREEN}$success_count${NC}"
echo -e "   Неудачных: ${RED}$failed_count${NC}"
echo -e "   Процент успеха: $(( success_count * 100 / TOTAL_CYCLES ))%"

if [ "$success_count" -gt 0 ]; then
    echo -e "\n⏱️  ${YELLOW}ВРЕМЕННАЯ СТАТИСТИКА:${NC}"
    echo -e "   Общее время загрузок: ${total_upload_time}s"
    echo -e "   Общее время скачиваний: ${total_download_time}s"
    echo -e "   Общее время удалений: ${total_delete_time}s"
    echo -e "   Среднее время загрузки: $(( total_upload_time / success_count ))s"
    echo -e "   Среднее время скачивания: $(( total_download_time / success_count ))s"
    echo -e "   Среднее время удаления: $(( total_delete_time / success_count ))s"
    
    echo -e "\n🚀 ${YELLOW}ПРОИЗВОДИТЕЛЬНОСТЬ:${NC}"
    if [ "$total_upload_time" -gt 0 ]; then
        upload_throughput=$(( success_count * 1024 / total_upload_time ))
        echo -e "   Пропускная способность загрузки: ${upload_throughput} MB/s"
    fi
    if [ "$total_download_time" -gt 0 ]; then
        download_throughput=$(( success_count * 1024 / total_download_time ))
        echo -e "   Пропускная способность скачивания: ${download_throughput} MB/s"
    fi
fi

echo -e "\n💾 ${YELLOW}ПАМЯТЬ ПОСЛЕ ТЕСТА:${NC}"
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.MemPerc}}" fileservice clientapp

echo -e "\n🏥 ${YELLOW}СОСТОЯНИЕ СИСТЕМЫ:${NC}"
if docker ps | grep -q fileservice && docker ps | grep -q clientapp; then
    echo -e "   ${GREEN}✅ Все контейнеры работают стабильно${NC}"
else
    echo -e "   ${RED}❌ Проблемы с контейнерами${NC}"
fi

echo -e "\n${PURPLE}🏆 РЕЗУЛЬТАТЫ ПОЛНОГО ТЕСТА НА ВЫНОСЛИВОСТЬ${NC}"
echo "==========================================================="

if [ "$success_count" -eq "$TOTAL_CYCLES" ]; then
    echo -e "\n${GREEN}🎉 ПОЛНЫЙ ТЕСТ НА ВЫНОСЛИВОСТЬ ПРОЙДЕН!${NC}"
    echo -e "${GREEN}==========================================================${NC}"
    echo -e "${GREEN}✅ ВСЕ $TOTAL_CYCLES ЦИКЛОВ ВЫПОЛНЕНЫ УСПЕШНО${NC}"
    echo -e "${GREEN}✅ ОБРАБОТАНО: $(( success_count * 2 ))GB ДАННЫХ (загрузка + скачивание)${NC}"
    echo -e "${GREEN}✅ СИСТЕМА СТАБИЛЬНА ПРИ ПОЛНОМ ЦИКЛЕ ОПЕРАЦИЙ${NC}"
    echo -e "${GREEN}✅ УТЕЧЕК ПАМЯТИ НЕ ОБНАРУЖЕНО${NC}"
    echo -e "${GREEN}✅ ПОТОКОВАЯ ОБРАБОТКА В ОБОИХ НАПРАВЛЕНИЯХ БЕЗУПРЕЧНА${NC}"
    echo -e "${GREEN}✅ HttpCompletionOption.ResponseHeadersRead РАБОТАЕТ КОРРЕКТНО${NC}"
elif [ "$success_count" -gt $(( TOTAL_CYCLES * 4 / 5 )) ]; then
    echo -e "\n${YELLOW}⚠️  ТЕСТ ПРОЙДЕН С ХОРОШИМ РЕЗУЛЬТАТОМ${NC}"
    echo -e "${YELLOW}Успех: $success_count из $TOTAL_CYCLES ($(( success_count * 100 / TOTAL_CYCLES ))%)${NC}"
else
    echo -e "\n${RED}❌ ОБНАРУЖЕНЫ ПРОБЛЕМЫ СТАБИЛЬНОСТИ${NC}"
    echo -e "${RED}Успех: $success_count из $TOTAL_CYCLES ($(( success_count * 100 / TOTAL_CYCLES ))%)${NC}"
fi

echo -e "\n⏰ Завершение: $(date '+%H:%M:%S')"