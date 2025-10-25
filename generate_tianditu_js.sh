#!/bin/bash
# generate_tianditu_js.sh

# 从文件读取天地图 Key
TIANDITU_KEY_FILE="/etc/custom_vars/secure_env/tianditu_key"
JS_URL="https://gist.githubusercontent.com/lxg20082008/2ea957ddc339a552bc09847fa550e7b0/raw/74ef092297f8920e5151f9bb416428699dddb7d9/hass_tianditu.js"
JS_OUTPUT_DIR="/opt/docker/ha/config/www/community/hass_tianditu"
JS_OUTPUT_FILE="${JS_OUTPUT_DIR}/hass_tianditu.js"

# 颜色输出函数
log_info() {
    echo "[INFO] $1"
}

log_warn() {
    echo "[WARN] $1"
}

log_error() {
    echo "[ERROR] $1"
}

# 检查并创建目录
create_directories() {
    log_info "检查目录结构..."
    
    # 检查 Key 文件目录
    if [ ! -d "/etc/custom_vars/secure_env" ]; then
        log_error "Key 文件目录不存在: /etc/custom_vars/secure_env"
        return 1
    fi
    
    # 创建 JS 输出目录
    mkdir -p "$JS_OUTPUT_DIR"
    if [ $? -ne 0 ]; then
        log_error "创建目录失败: $JS_OUTPUT_DIR"
        return 1
    fi
    log_info "目录创建成功: $JS_OUTPUT_DIR"
    return 0
}

# 读取天地图 Key
read_tianditu_key() {
    log_info "读取天地图 API Key..."
    
    if [ ! -f "$TIANDITU_KEY_FILE" ]; then
        log_error "Key 文件不存在: $TIANDITU_KEY_FILE"
        return 1
    fi
    
    TIANDITU_KEY=$(cat "$TIANDITU_KEY_FILE" | tr -d '[:space:]')
    
    if [ -z "$TIANDITU_KEY" ]; then
        log_error "Key 文件为空: $TIANDITU_KEY_FILE"
        return 1
    fi
    
    key_length=$(echo -n "$TIANDITU_KEY" | wc -c)
    log_info "成功读取天地图 Key (长度: $key_length 字符)"
    
    # 显示 Key 的前后几位用于验证
    if [ $key_length -ge 8 ]; then
        key_start=$(echo "$TIANDITU_KEY" | cut -c1-4)
        key_end=$(echo "$TIANDITU_KEY" | rev | cut -c1-4 | rev)
        log_info "Key 预览: ${key_start}...${key_end}"
    fi
    
    return 0
}

# 下载并处理 JS 文件
download_and_process_js() {
    log_info "下载 JS 模板文件..."
    
    # 下载原始 JS 文件
    if command -v curl >/dev/null 2>&1; then
        if ! curl -s -o "/tmp/hass_tianditu_original.js" "$JS_URL"; then
            log_error "下载 JS 文件失败: $JS_URL"
            return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -q -O "/tmp/hass_tianditu_original.js" "$JS_URL"; then
            log_error "下载 JS 文件失败: $JS_URL"
            return 1
        fi
    else
        log_error "未找到 curl 或 wget，无法下载文件"
        return 1
    fi
    
    if [ ! -s "/tmp/hass_tianditu_original.js" ]; then
        log_error "下载的 JS 文件为空"
        return 1
    fi
    
    log_info "JS 模板下载成功"
    return 0
}

# 生成最终的 JS 文件
generate_final_js() {
    log_info "生成最终的 JS 文件..."
    
    # 读取原始 JS 内容
    if [ ! -f "/tmp/hass_tianditu_original.js" ]; then
        log_error "原始 JS 文件不存在"
        return 1
    fi
    
    original_content=$(cat "/tmp/hass_tianditu_original.js")
    
    # 替换 Key 占位符
    if echo "$original_content" | grep -q "const KEY = '<天地图Key>';"; then
        # 方法1: 直接替换占位符
        final_content=$(echo "$original_content" | sed "s/const KEY = '<天地图Key>';/const KEY = '$TIANDITU_KEY';/")
    elif echo "$original_content" | grep -q "天地图Key"; then
        # 方法2: 替换其他可能的占位符格式
        final_content=$(echo "$original_content" | sed "s/天地图Key/$TIANDITU_KEY/g")
    else
        # 方法3: 如果没有找到占位符，在文件开头添加 Key 定义
        final_content="// 自动生成的天地图配置\nconst KEY = '$TIANDITU_KEY';\n\n$original_content"
    fi
    
    # 写入最终文件
    echo "$final_content" > "$JS_OUTPUT_FILE"
    
    if [ $? -ne 0 ]; then
        log_error "写入 JS 文件失败: $JS_OUTPUT_FILE"
        return 1
    fi
    
    log_info "JS 文件生成成功: $JS_OUTPUT_FILE"
    return 0
}

# 验证生成的文件
validate_output() {
    log_info "验证生成的文件..."
    
    if [ ! -f "$JS_OUTPUT_FILE" ]; then
        log_error "输出文件不存在: $JS_OUTPUT_FILE"
        return 1
    fi
    
    file_size=$(wc -c < "$JS_OUTPUT_FILE")
    if [ "$file_size" -eq 0 ]; then
        log_error "输出文件为空: $JS_OUTPUT_FILE"
        return 1
    fi
    
    # 检查 Key 是否正确插入
    if grep -q "const KEY = '$TIANDITU_KEY';" "$JS_OUTPUT_FILE"; then
        log_info "Key 已成功插入到 JS 文件中"
    else
        log_warn "Key 可能未正确插入到 JS 文件中"
        log_info "检查文件内容..."
        # 显示包含 KEY 的行
        grep -i "key" "$JS_OUTPUT_FILE" | head -5
    fi
    
    log_info "文件大小: $file_size 字节"
    return 0
}

# 清理临时文件
cleanup() {
    if [ -f "/tmp/hass_tianditu_original.js" ]; then
        rm -f "/tmp/hass_tianditu_original.js"
        log_info "清理临时文件完成"
    fi
}

# 设置文件权限
set_permissions() {
    log_info "设置文件权限..."
    
    # 设置 JS 文件权限为 644
    chmod 644 "$JS_OUTPUT_FILE" 2>/dev/null || true
    
    # 如果需要，设置目录权限
    chmod 755 "$JS_OUTPUT_DIR" 2>/dev/null || true
    
    log_info "文件权限设置完成"
}

# 主函数
main() {
    log_info "开始生成天地图 JS 配置文件..."
    
    # 执行各个步骤
    if ! create_directories; then
        exit 1
    fi
    
    if ! read_tianditu_key; then
        exit 1
    fi
    
    if ! download_and_process_js; then
        exit 1
    fi
    
    if ! generate_final_js; then
        exit 1
    fi
    
    if ! validate_output; then
        exit 1
    fi
    
    set_permissions
    cleanup
    
    log_info "天地图 JS 配置文件生成完成!"
    log_info "文件位置: $JS_OUTPUT_FILE"
    log_info "Key 状态: 已从 $TIANDITU_KEY_FILE 安全加载"
    
    # 重启提示
    echo
    log_warn "请注意: 生成完成后需要重启 Home Assistant 使更改生效"
    log_info "重启命令: docker restart ha"
}

# 运行主函数
main