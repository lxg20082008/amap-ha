console.log('🎯 AMap Tile Layer 测试脚本加载成功');

const PROXY_URL = 'http://192.168.31.3:8280';
const MAX_ZOOM = 18;
const TILE_SIZE = 256;

// 测试代理服务
async function testProxyService() {
    console.log('🔍 测试代理服务连接...');
    
    const testUrls = [
        `${PROXY_URL}/10/500/300.png`,
        `${PROXY_URL}/tiles/10/500/300.png`,
        `${PROXY_URL}/normal/10/500/300.png`,
        `${PROXY_URL}/satellite/10/500/300.png`
    ];
    
    for (const url of testUrls) {
        try {
            const response = await fetch(url);
            console.log(`📡 ${url}: ${response.status}`);
            if (response.status === 200) {
                console.log('✅ 找到可用的代理URL格式:', url);
                return url.split('/').slice(0, -3).join('/'); // 返回基础URL
            }
        } catch (error) {
            console.log(`❌ ${url}: 连接失败`);
        }
    }
    return null;
}

// 降级算法
function downgradeTile(x, y, z, maxZoom) {
    if (z <= maxZoom) {
        return { srcX: x, srcY: y, srcZ: z, scale: 1, dx: 0, dy: 0 };
    }
    const scale = 2 ** (z - maxZoom);
    const srcX = Math.floor(x / scale);
    const srcY = Math.floor(y / scale);
    const srcZ = maxZoom;

    const offsetX = (x % scale) * TILE_SIZE / scale;
    const offsetY = (y % scale) * TILE_SIZE / scale;
    return { srcX, srcY, srcZ, scale, dx: -offsetX * scale, dy: -offsetY * scale };
}

// 替换地图瓦片
function transformCartoImg(img) {
    const src = img.src;
    if (!src.includes('cartocdn.com')) return;

    const match = src.match(/rastertiles\/voyager\/(\d+)\/(\d+)\/(\d+)/);
    if (!match) return;

    const [_, zStr, xStr, yStr] = match;
    const z = parseInt(zStr);
    const x = parseInt(xStr);
    const y = parseInt(yStr);

    console.log('🗺️ 发现Carto瓦片:', { x, y, z });

    // 先用简单格式测试
    const newUrl = `${PROXY_URL}/${z}/${x}/${y}.png`;
    img.src = newUrl;
    
    console.log('🔄 替换为:', newUrl);
    
    // 添加调试标记
    img.style.border = '2px solid #ff0000';
    img.style.boxShadow = '0 0 10px red';
}

// 初始化DOM监听
function initDomObserver() {
    console.log('👀 启动DOM监听...');
    
    const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
            mutation.addedNodes.forEach((node) => {
                if (node.tagName === 'IMG') {
                    transformCartoImg(node);
                }
            });
        });
    });

    observer.observe(document.body, {
        childList: true,
        subtree: true
    });
    
    // 立即检查现有图片
    document.querySelectorAll('img[src*="cartocdn.com"]').forEach(transformCartoImg);
}

// 主初始化函数
async function init() {
    console.log('🚀 AMap Tile Layer 初始化...');
    
    // 测试代理服务
    const baseUrl = await testProxyService();
    if (!baseUrl) {
        console.error('❌ 无法连接到代理服务，请检查配置');
        return;
    }
    
    console.log('✅ 代理服务连接成功');
    
    // 启动DOM监听
    initDomObserver();
    
    console.log('🎉 AMap Tile Layer 初始化完成');
}

// 启动
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}