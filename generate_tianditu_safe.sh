#!/bin/bash
# generate_tianditu_safe.sh

# ==================== 配置变量 ====================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HA_CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"
COMPONENT_DIR="$HA_CONFIG_DIR/custom_components"
INTEGRATION_DIR="$COMPONENT_DIR/tianditu_map"
FRONTEND_DIR="$INTEGRATION_DIR/frontend"

# 集成配置变量
DOMAIN_NAME="tianditu_map"
INTEGRATION_NAME="天地图安全代理"
INTEGRATION_VERSION="1.0.0"
AUTHOR="@lxg20082008"
DOCUMENTATION_URL="https://github.com/lxg20082008/tianditu_map"
SOURCE_JS_URL="https://gist.githubusercontent.com/lxg20082008/2ea957ddc339a552bc09847fa550e7b0/raw/hass_tianditu.js"

# 集成文件路径
INIT_PY="$INTEGRATION_DIR/__init__.py"
MANIFEST_JSON="$INTEGRATION_DIR/manifest.json"
CONFIG_JS="$FRONTEND_DIR/tianditu_config.js"
MAIN_JS="$FRONTEND_DIR/hass_tianditu.js"
INIT_JS="$FRONTEND_DIR/tianditu_init.js"

# ==================== 日志函数 ====================
log_info() {
    echo "[INFO] $1"
}

log_warn() {
    echo "[WARN] $1"
}

log_error() {
    echo "[ERROR] $1"
}

# ==================== 目录创建 ====================
create_directories() {
    log_info "创建集成目录结构..."
    
    local dirs=("$COMPONENT_DIR" "$INTEGRATION_DIR" "$FRONTEND_DIR")
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            if ! mkdir -p "$dir"; then
                log_error "创建目录失败: $dir"
                return 1
            fi
            log_info "目录创建成功: $dir"
        else
            log_info "目录已存在: $dir"
        fi
    done
    
    return 0
}

# ==================== 集成文件生成 ====================
generate_init_py() {
    log_info "生成集成主文件..."
    
    cat > "$INIT_PY" << EOF
\"\"\"天地图安全代理集成.\"\"\"
import logging
import os
from homeassistant.core import HomeAssistant
from homeassistant.config_entries import ConfigEntry

_LOGGER = logging.getLogger(__name__)

DOMAIN = "${DOMAIN_NAME}"

async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    \"\"\"设置天地图代理集成.\"\"\"
    hass.data.setdefault(DOMAIN, {})
    
    # 注册前端资源
    await register_frontend_resources(hass)
    
    # 注册代理服务
    await register_proxy_services(hass, entry)
    
    # 注册 HTTP 端点
    await register_http_endpoints(hass, entry)
    
    _LOGGER.info("天地图安全代理集成初始化完成")
    return True

async def register_frontend_resources(hass):
    \"\"\"注册前端 JS 资源.\"\"\"
    try:
        integration_dir = os.path.dirname(__file__)
        frontend_dir = os.path.join(integration_dir, "frontend")
        
        # 注册三个前端文件
        frontend_files = [
            ("tianditu_config.js", "/local/tianditu_map/tianditu_config.js"),
            ("hass_tianditu.js", "/local/tianditu_map/hass_tianditu.js"), 
            ("tianditu_init.js", "/local/tianditu_map/tianditu_init.js")
        ]
        
        for filename, url_path in frontend_files:
            file_path = os.path.join(frontend_dir, filename)
            if os.path.exists(file_path):
                hass.http.register_static_path(url_path, file_path, cache_headers=False)
        
        # 只添加初始化脚本到前端
        hass.components.frontend.add_extra_js_url(hass, "/local/tianditu_map/tianditu_init.js")
        
        _LOGGER.info("前端资源注册成功")
    except Exception as e:
        _LOGGER.error("前端资源注册失败: %s", e)

async def register_proxy_services(hass: HomeAssistant, entry: ConfigEntry):
    \"\"\"注册代理服务.\"\"\"
    import aiohttp
    
    async def handle_get_tile(call):
        \"\"\"处理瓦片请求 - API Key 在后端使用.\"\"\"
        x = call.data.get("x")
        y = call.data.get("y")
        z = call.data.get("z")
        layer = call.data.get("layer", "vec")
        api_key = entry.data.get("api_key")
        
        if not all([x, y, z, api_key]):
            return {"status": "error", "message": "缺少必要参数"}
        
        # 天地图服务配置
        layer_config = {
            "vec": "vec_w",
            "cva": "cva_w",
            "img": "img_w", 
            "cia": "cia_w",
            "ter": "ter_w",
            "cta": "cta_w"
        }
        
        service_type = layer_config.get(layer, "vec_w")
        url = f"https://t0.tianditu.gov.cn/{service_type}/wmts"
        
        params = {
            "SERVICE": "WMTS",
            "REQUEST": "GetTile",
            "VERSION": "1.0.0",
            "LAYER": layer,
            "STYLE": "default",
            "FORMAT": "tiles",
            "TILEMATRIXSET": "w", 
            "TILEMATRIX": z,
            "TILEROW": y,
            "TILECOL": x,
            "tk": api_key  # API Key 在后端安全使用
        }
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(url, params=params) as response:
                    if response.status == 200:
                        content = await response.read()
                        return {
                            "status": "success",
                            "content": content,
                            "content_type": response.headers.get("Content-Type", "image/png")
                        }
                    else:
                        _LOGGER.error("天地图请求失败: %s", response.status)
                        return {"status": "error", "code": response.status}
        except Exception as e:
            _LOGGER.error("代理请求异常: %s", e)
            return {"status": "error", "message": str(e)}
    
    # 注册服务
    hass.services.async_register(DOMAIN, "get_tile", handle_get_tile)
    _LOGGER.info("天地图代理服务注册成功")

async def register_http_endpoints(hass: HomeAssistant, entry: ConfigEntry):
    \"\"\"注册 HTTP 端点.\"\"\"
    from homeassistant.components.http import HomeAssistantView
    from aiohttp import web
    
    class TianDiTuTileProxy(HomeAssistantView):
        \"\"\"天地图瓦片代理端点.\"\"\"
        
        url = "/api/tianditu_map/tile"
        name = "api:tianditu_map:tile"
        requires_auth = False  # 可以根据需要设置为 True
        
        def __init__(self, entry):
            self.entry = entry
        
        async def get(self, request):
            \"\"\"处理瓦片 GET 请求.\"\"\"
            x = request.query.get("x")
            y = request.query.get("y") 
            z = request.query.get("z")
            layer = request.query.get("layer", "vec")
            
            if not all([x, y, z]):
                return web.Response(status=400, text="缺少参数")
            
            # 调用代理服务
            result = await hass.services.async_call(
                "${DOMAIN_NAME}",
                "get_tile", 
                {"x": x, "y": y, "z": z, "layer": layer},
                blocking=True
            )
            
            if result and isinstance(result, dict):
                service_data = result.get('get_tile', {})
                if service_data.get('status') == 'success':
                    return web.Response(
                        body=service_data['content'],
                        content_type=service_data['content_type']
                    )
            
            return web.Response(status=500, text="瓦片获取失败")
    
    hass.http.register_view(TianDiTuTileProxy(entry))
    _LOGGER.info("HTTP 代理端点注册成功")
EOF

    if [ $? -eq 0 ]; then
        log_info "集成主文件生成成功: $(basename "$INIT_PY")"
        return 0
    else
        log_error "集成主文件生成失败"
        return 1
    fi
}

generate_manifest_json() {
    log_info "生成清单文件..."
    
    cat > "$MANIFEST_JSON" << EOF
{
    "domain": "${DOMAIN_NAME}",
    "name": "${INTEGRATION_NAME}",
    "version": "${INTEGRATION_VERSION}",
    "documentation": "${DOCUMENTATION_URL}",
    "requirements": ["aiohttp"],
    "dependencies": ["http", "frontend"],
    "codeowners": ["${AUTHOR}"],
    "config_flow": true,
    "iot_class": "cloud_polling"
}
EOF

    if [ $? -eq 0 ]; then
        log_info "清单文件生成成功: $(basename "$MANIFEST_JSON")"
        return 0
    else
        log_error "清单文件生成失败"
        return 1
    fi
}

# ==================== 前端文件生成 ====================
generate_config_js() {
    log_info "生成天地图配置文件..."
    
    cat > "$CONFIG_JS" << 'EOF'
/**
 * 天地图安全配置 - 使用 Home Assistant 后端代理
 * 此文件包含代理逻辑，避免 API Key 硬编码在前端
 */

window.TianDiTuConfig = {
    // 使用代理服务获取地图瓦片，不暴露 API Key
    getTileUrl: function(x, y, z, layer = 'vec') {
        // 方法1: 优先使用 HA 服务代理
        if (window.hass && window.hass.callService) {
            return this.getTileViaService(x, y, z, layer);
        }
        
        // 方法2: 使用代理端点回退方案
        return this.getTileViaEndpoint(x, y, z, layer);
    },
    
    // 通过 HA 服务代理获取瓦片
    getTileViaService: async function(x, y, z, layer) {
        try {
            const result = await window.hass.callService('tianditu_map', 'get_tile', {
                x: x,
                y: y, 
                z: z,
                layer: layer
            });
            
            if (result && result.status === 'success') {
                // 创建 Blob URL 返回图块数据
                const blob = new Blob([result.content], { type: result.content_type });
                return URL.createObjectURL(blob);
            }
        } catch (error) {
            console.error('天地图服务调用失败:', error);
        }
        return null;
    },
    
    // 通过 HTTP 端点获取瓦片
    getTileViaEndpoint: function(x, y, z, layer) {
        // 使用代理端点，API Key 在后端处理
        return `/api/tianditu_map/tile?x=${x}&y=${y}&z=${z}&layer=${layer}&t=${Date.now()}`;
    }
};
EOF

    if [ $? -eq 0 ]; then
        log_info "配置文件生成成功: $(basename "$CONFIG_JS")"
        return 0
    else
        log_error "配置文件生成失败"
        return 1
    fi
}

generate_main_js() {
    log_info "下载并修改主 JS 文件..."
    log_info "源文件: $SOURCE_JS_URL"
    
    # 临时文件
    TEMP_JS="/tmp/hass_tianditu_original.js"
    
    # 下载原始文件
    if command -v curl >/dev/null 2>&1; then
        if ! curl -s -o "$TEMP_JS" "$SOURCE_JS_URL"; then
            log_error "下载 JS 文件失败"
            return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -q -O "$TEMP_JS" "$SOURCE_JS_URL"; then
            log_error "下载 JS 文件失败"
            return 1
        fi
    else
        log_error "未找到 curl 或 wget"
        return 1
    fi
    
    if [ ! -s "$TEMP_JS" ]; then
        log_error "下载的文件为空"
        return 1
    fi
    
    log_info "原始文件下载成功，开始最小化修改..."
    
    # 最小化修改：只修改 KEY 常量和 TILE_URL 中的 URL 生成逻辑
    sed -e 's|const KEY = .*|// 安全修改: 使用代理服务替代硬编码 Key 开始\nconst KEY = window.TianDiTuConfig ? null : ""; // API Key 在后端处理\n// 安全修改: 使用代理服务替代硬编码 Key 结束|' \
        -e 's|https://t{0-7}.tianditu.gov.cn/\(.*\)_w/wmts?tk=.*|// 安全修改: 使用代理服务生成 URL\n        "\1": window.TianDiTuConfig ? window.TianDiTuConfig.getTileUrl : function(x, y, z) { return `https://t{0-7}.tianditu.gov.cn/\1_w/wmts?tk=${KEY}`; }|g' \
        "$TEMP_JS" > "$MAIN_JS"
    
    # 检查修改是否成功
    if [ $? -eq 0 ] && [ -s "$MAIN_JS" ]; then
        log_info "主 JS 文件修改成功: $(basename "$MAIN_JS")"
        
        # 显示修改的内容
        log_info "修改内容预览:"
        grep -n -A2 -B2 "安全修改" "$MAIN_JS" | head -10
    else
        log_error "主 JS 文件修改失败"
        # 回退方案：直接复制原文件
        cp "$TEMP_JS" "$MAIN_JS"
        log_warn "已使用原始文件（需要手动修改 API Key）"
    fi
    
    # 清理临时文件
    rm -f "$TEMP_JS"
    
    return 0
}

generate_init_js() {
    log_info "生成初始化文件..."
    
    cat > "$INIT_JS" << 'EOF'
/**
 * 天地图安全初始化脚本
 * 负责加载配置并初始化代理服务
 */

(function() {
    'use strict';
    
    function initializeTianDiTu() {
        // 检查配置是否已加载
        if (window.TianDiTuConfig) {
            console.log('天地图安全代理配置已加载');
            
            // 如果原地图已初始化，重新加载地图以应用代理配置
            if (typeof window.updateLocation === 'function') {
                console.log('天地图代理模式已激活');
            }
        } else {
            // 重试机制
            setTimeout(initializeTianDiTu, 500);
        }
    }
    
    // 等待页面加载完成后初始化
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initializeTianDiTu);
    } else {
        initializeTianDiTu();
    }
})();
EOF

    if [ $? -eq 0 ]; then
        log_info "初始化文件生成成功: $(basename "$INIT_JS")"
        return 0
    else
        log_error "初始化文件生成失败"
        return 1
    fi
}

# ==================== 权限设置和验证 ====================
set_permissions() {
    log_info "设置文件权限..."
    
    local files=("$INIT_PY" "$MANIFEST_JSON" "$CONFIG_JS" "$MAIN_JS" "$INIT_JS")
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            chmod 644 "$file" 2>/dev/null || log_warn "权限设置失败: $file"
        fi
    done
    
    chmod 755 "$INTEGRATION_DIR" 2>/dev/null || true
    chmod 755 "$FRONTEND_DIR" 2>/dev/null || true
    
    log_info "文件权限设置完成"
}

validate_output() {
    log_info "验证生成结果..."
    
    local files=("$INIT_PY" "$MANIFEST_JSON" "$CONFIG_JS" "$MAIN_JS" "$INIT_JS")
    local success=true
    
    for file in "${files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "文件不存在: $(basename "$file")"
            success=false
        elif [ ! -s "$file" ]; then
            log_error "文件为空: $(basename "$file")"
            success=false
        else
            log_info "✓ $(basename "$file") ($(wc -c < "$file") 字节)"
        fi
    done
    
    if $success; then
        log_info "✅ 所有文件验证通过"
        return 0
    else
        log_error "❌ 文件验证失败"
        return 1
    fi
}

# ==================== 完成信息 ====================
show_completion_info() {
    log_info ""
    log_info "🎉 天地图安全代理集成生成完成!"
    log_info ""
    log_info "📁 文件结构:"
    log_info "  $INTEGRATION_DIR/"
    log_info "  ├── __init__.py          # Python 集成主文件"
    log_info "  ├── manifest.json        # 集成清单文件" 
    log_info "  └── frontend/"
    log_info "      ├── tianditu_config.js # 安全配置"
    log_info "      ├── hass_tianditu.js   # 最小修改的主逻辑"
    log_info "      └── tianditu_init.js   # 初始化脚本"
    log_info ""
    log_info "🔧 下一步配置:"
    log_info "1. 在 secrets.yaml 中添加:"
    log_info "   tianditu_key: \"您的天地图API_Key\""
    log_info ""
    log_info "2. 在 configuration.yaml 中添加:"
    log_info "   tianditu_map:"
    log_info "     api_key: !secret tianditu_key"
    log_info ""
    log_info "3. 重启 Home Assistant:"
    log_info "   docker restart ha"
    log_info ""
    log_info "4. 在 HA 界面中添加集成:"
    log_info "   配置 → 设备与服务 → 添加集成 → 搜索 '${INTEGRATION_NAME}'"
    log_info ""
    log_info "📚 文档: $DOCUMENTATION_URL"
}

# ==================== 主函数 ====================
main() {
    log_info "开始生成天地图安全代理集成..."
    log_info "脚本目录: $SCRIPT_DIR"
    log_info "HA配置目录: $HA_CONFIG_DIR"
    log_info "集成名称: $INTEGRATION_NAME"
    log_info "集成域名: $DOMAIN_NAME"
    log_info "版本: $INTEGRATION_VERSION"
    log_info "文档: $DOCUMENTATION_URL"
    log_info ""
    
    # 执行各个步骤
    local steps=(
        "create_directories"
        "generate_init_py" 
        "generate_manifest_json"
        "generate_config_js"
        "generate_main_js"
        "generate_init_js"
        "set_permissions"
        "validate_output"
    )
    
    for step in "${steps[@]}"; do
        if ! $step; then
            log_error "步骤 $step 执行失败，退出"
            exit 1
        fi
    done
    
    show_completion_info
}

# 运行主函数
main