"""AMap Tile Layer frontend JavaScript code."""

def get_js_content(proxy_url="http://192.168.31.3:8280", max_zoom=18, tile_type="normal"):
    """Generate JavaScript content with configuration."""
    
    return f"""
const MAX_Z = {max_zoom};
const TILE_SIZE = 256;
const PROXY_BASE_URL = '{proxy_url}';
const TILE_TYPE = '{tile_type}';

// 高德代理服务URL生成
function generateAmapProxyUrl(x, y, z, type = TILE_TYPE) {{
    if (type === 'satellite') {{
        return `${{PROXY_BASE_URL}}/satellite/${{z}}/${{x}}/${{y}}.png`;
    }} else {{
        return `${{PROXY_BASE_URL}}/normal/${{z}}/${{x}}/${{y}}.png`;
    }}
}}

// 降级算法
function downgradeTile(x, y, z, maxZoom) {{
    if (z <= maxZoom) {{
        return {{
            srcX: x,
            srcY: y,
            srcZ: z,
            scale: 1,
            dx: 0,
            dy: 0
        }};
    }}
    const scale = 2 ** (z - maxZoom);
    const srcX = Math.floor(x / scale);
    const srcY = Math.floor(y / scale);
    const srcZ = maxZoom;

    const tileSize = 256;
    const offsetX = (x % scale) * tileSize / scale;
    const offsetY = (y % scale) * tileSize / scale;
    return {{
        srcX,
        srcY,
        srcZ,
        scale,
        dx: -offsetX * scale,
        dy: -offsetY * scale
    }};
}}

class AmapTileLayer extends HTMLElement {{
    constructor() {{
        super();
        this._map = null;
        this._tileLayer = null;
    }}

    setConfig(config) {{
        this._config = config;
    }}

    set map(map) {{
        if (this._map === map) return;
        
        this._map = map;
        if (map) {{
            this._attachTileLayer();
        }} else {{
            this._detachTileLayer();
        }}
    }}

    _attachTileLayer() {{
        if (!this._map || this._tileLayer) return;

        this._tileLayer = L.tileLayer(this._getTileUrl(), {{
            attribution: '©高德地图',
            maxZoom: {max_zoom},
            minZoom: 1,
            tileSize: 256,
            zoomOffset: 0
        }});

        this._tileLayer.addTo(this._map);
    }}

    _detachTileLayer() {{
        if (this._tileLayer) {{
            this._map.removeLayer(this._tileLayer);
            this._tileLayer = null;
        }}
    }}

    _getTileUrl() {{
        return (coords) => {{
            const url = generateAmapProxyUrl(coords.x, coords.y, coords.z, TILE_TYPE);
            return url;
        }};
    }}
}}

// 注册自定义元素
customElements.define('amap-tile-layer', AmapTileLayer);

// DOM替换逻辑
const existsCoordSet = new Set();

function initDomObserver() {{
    function transformCartoImg(img, addImgEls = null) {{
        const src = img.src;
        if (!src.startsWith('https://basemaps.cartocdn.com/')) {{
            return;
        }}

        const match = src.match(/rastertiles\\\\/voyager\\\\/(\\\\d+)\\\\/\\\\/(\\\\d+)\\\\/\\\\/(\\\\d+)(?:@2x)?\\\\.png/);
        if (!match) {{
            return;
        }}

        let [_, zStr, xStr, yStr] = match;
        let z = parseInt(zStr);
        let x = parseInt(xStr);
        let y = parseInt(yStr);

        if (z <= MAX_Z) {{
            const amapSrc = generateAmapProxyUrl(x, y, z, TILE_TYPE);
            img.src = amapSrc;
            console.debug('[AMap替换]', src, '→', amapSrc);
            return;
        }}

        // 降级处理
        const {{ srcX, srcY, srcZ, scale, dx, dy }} = downgradeTile(x, y, z, MAX_Z);
        
        const downgradeKey = `${{srcX}},${{srcY}},${{srcZ}},${{z}}`;

        if (existsCoordSet.has(downgradeKey)) {{
            img.src = "data:image/gif;base64,R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs=";
            img.style.display = "none";
            return;
        }}

        img["downgradeKey"] = downgradeKey;
        existsCoordSet.add(downgradeKey);

        const amapSrc = generateAmapProxyUrl(srcX, srcY, srcZ, TILE_TYPE);

        // 应用transform变换
        if (img.style.transform && img.style.transform.includes('translate3d(')) {{
            const translateMatch = img.style.transform.match(/translate3d\\\\(([^,]+),\\\\s*([^,]+),\\\\s*([^\\\\)]+)\\\\)/);
            if (translateMatch) {{
                const translateX = parseFloat(translateMatch[1]);
                const translateY = parseFloat(translateMatch[2]);
                const newTranslateX = translateX + dx;
                const newTranslateY = translateY + dy;
                img.style.transform = img.style.transform.replace(/translate3d\\\\([^\\\\)]+\\\\)/, `translate3d(${{newTranslateX}}px, ${{newTranslateY}}px, 0px)`);
            }}
        }}

        if (!img.style.transform.includes('scale(')) {{
            img.style.transform = (img.style.transform || '') + ` scale(${{scale}})`;
        }}

        img.style.width = TILE_SIZE + 'px';
        img.style.height = TILE_SIZE + 'px';
        img.style.transformOrigin = 'top left';

        img.src = amapSrc;
        console.debug('[AMap降级]', `${{z}} → ${{MAX_Z}}, src:`, amapSrc);
    }}

    // DOM监听逻辑
    const observer = new MutationObserver((mutations) => {{
        for (const mutation of mutations) {{
            for (const node of mutation.addedNodes) {{
                if (node instanceof Element && node.tagName === 'IMG') {{
                    transformCartoImg(node);
                }}
            }}
        }}
    }});

    observer.observe(document, {{
        childList: true,
        subtree: true
    }});
}}

// 初始化
if (document.readyState === 'loading') {{
    document.addEventListener('DOMContentLoaded', initDomObserver);
}} else {{
    initDomObserver();
}}

console.log('AMap Tile Layer loaded successfully with config:', {{
    proxy_url: '{proxy_url}',
    max_zoom: {max_zoom},
    tile_type: '{tile_type}'
}});
"""