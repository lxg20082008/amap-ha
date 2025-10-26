console.log('🎯 AMap Tile Layer 加载成功');

const PROXY_URL = 'http://192.168.31.3:8280';
const MAX_ZOOM = 18;
const TILE_SIZE = 256;

// 高德代理服务URL生成
function generateAmapProxyUrl(x, y, z, type = 'normal') {
    if (type === 'satellite') {
        return `${PROXY_URL}/satellite/${z}/${x}/${y}.png`;
    } else {
        return `${PROXY_URL}/normal/${z}/${x}/${y}.png`;
    }
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

const existsCoordSet = new Set();

function initDomObserver() {
    function transformCartoImg(img) {
        const src = img.src;
        if (!src.includes('cartocdn.com')) return;

        const match = src.match(/rastertiles\/voyager\/(\d+)\/(\d+)\/(\d+)/);
        if (!match) return;

        const [_, zStr, xStr, yStr] = match;
        const z = parseInt(zStr);
        const x = parseInt(xStr);
        const y = parseInt(yStr);

        if (z <= MAX_Z) {
            const amapSrc = generateAmapProxyUrl(x, y, z, 'normal');
            img.src = amapSrc;
            console.log('[AMap替换]', src, '→', amapSrc);
            return;
        }

        // 降级处理
        const { srcX, srcY, srcZ, scale, dx, dy } = downgradeTile(x, y, z, MAX_Z);
        
        const downgradeKey = `${srcX},${srcY},${srcZ},${z}`;

        if (existsCoordSet.has(downgradeKey)) {
            img.src = "data:image/gif;base64,R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs=";
            img.style.display = "none";
            return;
        }

        existsCoordSet.add(downgradeKey);
        const amapSrc = generateAmapProxyUrl(srcX, srcY, srcZ, 'normal');

        // 应用transform变换
        if (img.style.transform && img.style.transform.includes('translate3d(')) {
            const translateMatch = img.style.transform.match(/translate3d\(([^,]+),\s*([^,]+),\s*([^)]+)\)/);
            if (translateMatch) {
                const translateX = parseFloat(translateMatch[1]);
                const translateY = parseFloat(translateMatch[2]);
                const newTranslateX = translateX + dx;
                const newTranslateY = translateY + dy;
                img.style.transform = img.style.transform.replace(/translate3d\([^)]+\)/, `translate3d(${newTranslateX}px, ${newTranslateY}px, 0px)`);
            }
        }

        if (!img.style.transform.includes('scale(')) {
            img.style.transform = (img.style.transform || '') + ` scale(${scale})`;
        }

        img.style.width = TILE_SIZE + 'px';
        img.style.height = TILE_SIZE + 'px';
        img.style.transformOrigin = 'top left';
        img.src = amapSrc;
        
        console.log('[AMap降级]', `${z} → ${MAX_Z}`, amapSrc);
    }

    // DOM监听逻辑
    const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
            mutation.addedNodes.forEach((node) => {
                if (node.tagName === 'IMG') {
                    transformCartoImg(node);
                }
                // 检查子节点
                if (node.querySelectorAll) {
                    node.querySelectorAll('img[src*="cartocdn.com"]').forEach(transformCartoImg);
                }
            });
        });
    });

    observer.observe(document.body, {
        childList: true,
        subtree: true
    });

    // 立即替换现有图片
    document.querySelectorAll('img[src*="cartocdn.com"]').forEach(transformCartoImg);
}

// 初始化
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initDomObserver);
} else {
    initDomObserver();
}

console.log('🎉 AMap Tile Layer 初始化完成');
