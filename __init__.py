"""天地图地图集成."""
import logging
import os

import homeassistant.helpers.config_validation as cv
import voluptuous as vol
from homeassistant.core import HomeAssistant
from homeassistant.helpers.typing import ConfigType

_LOGGER = logging.getLogger(__name__)

DOMAIN = "tianditu_map"

CONFIG_SCHEMA = vol.Schema(
    {
        DOMAIN: vol.Schema(
            {
                vol.Required("api_key"): cv.string,
            }
        )
    },
    extra=vol.ALLOW_EXTRA,
)

async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    """设置天地图地图集成."""
    if DOMAIN not in config:
        _LOGGER.info("未找到天地图配置")
        return True

    conf = config[DOMAIN]
    api_key = conf["api_key"]
    
    # 将API密钥存储到hass数据中，供前端使用
    hass.data[DOMAIN] = {"api_key": api_key}
    
    # 注册前端资源
    hass.http.register_static_path(
        "/tianditu_map",
        os.path.join(os.path.dirname(__file__), "frontend"),
        True
    )
    
    _LOGGER.info("天地图地图集成加载完成")
    return True