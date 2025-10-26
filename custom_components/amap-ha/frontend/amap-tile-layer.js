// 确保正确的 Content-Type 和字符集
class AmapTileLayer extends HTMLElement {
    constructor() {
        super();
        this._map = null;
        this._tileLayer = null;
        this._proxyUrl = 'http://192.168.31.3:8280';
    }

    setConfig(config) {
        this._config = config;
    }

    set map(map) {
        if (this._map === map) return;
        
        this._map = map;
        if (map) {
            this._attachTileLayer();
        } else {
            this._detachTileLayer();
        }
    }

    _attachTileLayer() {
        if (!this._map || this._tileLayer) return;

        // 创建高德代理瓦片层
        this._tileLayer = L.tileLayer(this._getTileUrl(), {
            attribution: '©高德地图',
            maxZoom: 18,
            minZoom: 1,
            tileSize: 256,
            zoomOffset: 0
        });

        this._tileLayer.addTo(this._map);
    }

    _detachTileLayer() {
        if (this._tileLayer) {
            this._map.removeLayer(this._tileLayer);
            this._tileLayer = null;
        }
    }

    _getTileUrl() {
        const { _proxyUrl } = this;
        return `${_proxyUrl}/normal/{z}/{x}/{y}.png`;
    }

    // 监听属性变化
    static get observedAttributes() {
        return ['proxy-url'];
    }

    attributeChangedCallback(name, oldValue, newValue) {
        if (name === 'proxy-url' && oldValue !== newValue) {
            this._proxyUrl = newValue;
            this._refreshTileLayer();
        }
    }

    _refreshTileLayer() {
        if (this._tileLayer) {
            this._detachTileLayer();
            this._attachTileLayer();
        }
    }
}

// 注册自定义元素
customElements.define('amap-tile-layer', AmapTileLayer);

// 导出模块
console.log('AMap Tile Layer 模块加载成功');