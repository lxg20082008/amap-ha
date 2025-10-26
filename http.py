"""HTTP views for AMap Tile Layer."""
import logging
from aiohttp import web
from homeassistant.components.http import HomeAssistantView

_LOGGER = logging.getLogger(__name__)

class AmapTileLayerView(HomeAssistantView):
    """View to serve AMap Tile Layer JS file with correct Content-Type."""
    
    url = "/api/amap_ha/amap-tile-layer.js"
    name = "api:amap_ha:amap-tile-layer"
    requires_auth = False
    
    def __init__(self, hass):
        """Initialize."""
        self.hass = hass
    
    async def get(self, request):
        """Return AMap Tile Layer JavaScript with correct charset."""
        try:
            from .frontend.amap_tile_layer import get_js_content
            
            # 获取配置
            config = self.hass.data.get("amap_ha", {})
            proxy_url = config.get("proxy_url", "http://192.168.31.3:8280")
            max_zoom = config.get("max_zoom", 18)
            tile_type = config.get("tile_type", "normal")
            
            js_content = get_js_content(proxy_url, max_zoom, tile_type)
            
            return web.Response(
                text=js_content,
                content_type="application/javascript; charset=utf-8",
                headers={
                    "Cache-Control": "public, max-age=86400",
                    "Access-Control-Allow-Origin": "*"
                }
            )
        except ImportError as e:
            _LOGGER.error("Failed to load AMap Tile Layer JS: %s", e)
            return web.Response(status=404)