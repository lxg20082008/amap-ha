"""The AMap Tile Layer integration."""
from __future__ import annotations
import logging
import voluptuous as vol

from homeassistant.core import HomeAssistant
import homeassistant.helpers.config_validation as cv

from .http import AmapTileLayerView

_LOGGER = logging.getLogger(__name__)

DOMAIN = "amap_ha"
CONF_PROXY_URL = "proxy_url"
CONF_MAX_ZOOM = "max_zoom"
CONF_TILE_TYPE = "tile_type"

DEFAULT_PROXY_URL = "http://192.168.31.3:8280"
DEFAULT_MAX_ZOOM = 18
DEFAULT_TILE_TYPE = "normal"

CONFIG_SCHEMA = vol.Schema(
    {
        DOMAIN: vol.Schema(
            {
                vol.Optional(CONF_PROXY_URL, default=DEFAULT_PROXY_URL): cv.string,
                vol.Optional(CONF_MAX_ZOOM, default=DEFAULT_MAX_ZOOM): vol.All(
                    vol.Coerce(int), vol.Range(min=1, max=20)
                ),
                vol.Optional(CONF_TILE_TYPE, default=DEFAULT_TILE_TYPE): vol.In(
                    ["normal", "satellite"]
                ),
            }
        )
    },
    extra=vol.ALLOW_EXTRA,
)

async def async_setup(hass: HomeAssistant, config: dict) -> bool:
    """Set up the AMap Tile Layer component."""
    # 获取配置
    domain_config = config.get(DOMAIN, {})
    
    # 存储配置到hass数据
    hass.data[DOMAIN] = {
        "proxy_url": domain_config.get(CONF_PROXY_URL, DEFAULT_PROXY_URL),
        "max_zoom": domain_config.get(CONF_MAX_ZOOM, DEFAULT_MAX_ZOOM),
        "tile_type": domain_config.get(CONF_TILE_TYPE, DEFAULT_TILE_TYPE),
    }
    
    # 注册HTTP视图
    hass.http.register_view(AmapTileLayerView(hass))
    
    _LOGGER.info("AMap Tile Layer integration loaded with config: %s", hass.data[DOMAIN])
    
    return True