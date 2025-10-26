"""高德地图瓦片图层集成."""
import logging
import os
from aiohttp import web
from homeassistant.core import HomeAssistant

_LOGGER = logging.getLogger(__name__)

DOMAIN = "amap_tile_layer"

async def async_setup(hass: HomeAssistant, config: dict):
    """设置集成."""
    
    def _serve_amap_js(request):
        """服务 JavaScript 文件并设置正确的 Content-Type."""
        file_path = hass.config.path("www/community/amap-tile-layer/amap-tile-layer.js")
        
        if not os.path.exists(file_path):
            return web.Response(status=404, text="File not found")
        
        try:
            with open(file_path, 'rb') as f:
                content = f.read()
            
            # 强制设置正确的 Content-Type
            return web.Response(
                body=content,
                content_type='application/javascript; charset=utf-8'
            )
        except Exception as e:
            _LOGGER.error("读取文件失败: %s", e)
            return web.Response(status=500, text="Internal server error")
    
    # 注册自定义路由
    hass.http.register_route(
        'GET',
        '/hacsfiles/amap-tile-layer/amap-tile-layer.js',
        _serve_amap_js
    )
    
    _LOGGER.info("高德地图瓦片图层前端资源已注册")
    return True

async def async_setup_entry(hass, entry):
    """设置集成条目."""
    return True