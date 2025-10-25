// 配置和代理逻辑
class TiandituConfig {
    constructor() {
        this.apiKey = null;
        this.initialized = false;
    }

    async init() {
        if (this.initialized) return;
        
        try {
            // 从Home Assistant获取配置
            const response = await fetch('/api/config/tianditu_map/config');
            if (response.ok) {
                const config = await response.json();
                this.apiKey = config.api_key;
                console.log('[天地图] 配置加载成功');
            } else {
                console.warn('[天地图] 无法获取配置，使用默认Key');
                // 这里可以设置一个默认Key或显示错误
            }
        } catch (error) {
            console.error('[天地图] 配置加载失败:', error);
        }
        
        this.initialized = true;
    }

    getApiKey() {
        return this.apiKey;
    }

    // 代理天地图请求以添加API Key
    setupProxy() {
        const originalFetch = window.fetch;
        window.fetch = function(...args) {
            const url = args[0];
            if (typeof url === 'string' && url.includes('tianditu.com') && url.includes('tk=')) {
                // 如果URL中已经包含Key，先尝试替换
                const apiKey = window.tiandituConfig?.getApiKey();
                if (apiKey) {
                    const newUrl = url.replace(/tk=[^&]+/, `tk=${apiKey}`);
                    args[0] = newUrl;
                    console.debug('[天地图] 代理请求:', newUrl);
                }
            }
            return originalFetch.apply(this, args);
        };
    }
}

// 全局配置实例
window.tiandituConfig = new TiandituConfig();
