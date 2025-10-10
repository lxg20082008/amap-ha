// 修改后的初始化脚本 - 最小修改原代码
const MAX_Z = 18;
const TILE_SIZE = 256;

/**
 * 将超出最大支持级别的tile xyz数据，降级到maxZoom，并返回变换参数
 */
function downgradeTile(x, y, z, maxZoom) {
    if (z <= maxZoom) {
        return {
            srcX: x,
            srcY: y,
            srcZ: z,
            scale: 1,
            dx: 0,
            dy: 0
        };
    }
    const scale = 2 ** (z - maxZoom);
    const srcX = Math.floor(x / scale);
    const srcY = Math.floor(y / scale);
    const srcZ = maxZoom;

    const tileSize = 256;
    const offsetX = (x % scale) * tileSize / scale;
    const offsetY = (y % scale) * tileSize / scale;
    return {
        srcX,
        srcY,
        srcZ,
        scale,
        dx: -offsetX * scale,
        dy: -offsetY * scale
    };
}

const luckyServer = Math.floor(Math.random() * 8);

// 修改：使用动态获取的Key
function generateTileUrl(x, y, z, type) {
    const apiKey = window.tiandituConfig?.getApiKey();
    if (!apiKey) {
        console.warn('[天地图] API Key未设置');
        return '';
    }
    return `//t${luckyServer}.tianditu.com/DataServer?T=${type}&x=${x}&y=${y}&l=${z}&tk=${apiKey}`;
}

const existsCoordSet = new Set();

function initDomObserver() {
    function createCvaImg(src, img) {
        const cvaImg = new Image();
        cvaImg.src = src;
        cvaImg.classList.add("leaflet-tile");
        cvaImg.style.position = 'absolute';
        cvaImg.style.top = img.style.top;
        cvaImg.style.left = img.style.left;
        cvaImg.style.transform = img.style.transform;
        cvaImg.style.width = img.style.width;
        cvaImg.style.height = img.style.height;
        cvaImg.style.mixBlendMode = 'unset';

        cvaImg.onload = () => {
            cvaImg.classList.add("leaflet-tile-loaded");
        };

        img["cvaImgRef"] = cvaImg;
        return cvaImg;
    }

    function transformCartoImg(img, addImgEls = null) {
        const src = img.src;
        if (!src.startsWith('https://basemaps.cartocdn.com/')) {
            return;
        }

        const match = src.match(/rastertiles\/voyager\/(\d+)\/(\d+)\/(\d+)(?:@2x)?\.png/);
        if (!match) {
            return;
        }

        let [_, zStr, xStr, yStr] = match;
        let z = parseInt(zStr);
        let x = parseInt(xStr);
        let y = parseInt(yStr);

        if (z <= MAX_Z) {
            const vecSrc = generateTileUrl(x, y, z, 'vec_w');
            const cvaSrc = generateTileUrl(x, y, z, 'cva_w');
            if (!vecSrc || !cvaSrc) return;
            
            if (!addImgEls) {
                img.style.backgroundImage = `url("${vecSrc}")`;
                img.src = cvaSrc;
            } else {
                const cvaImg = createCvaImg(cvaSrc, img);
                addImgEls.push(cvaImg);
                img.src = vecSrc;
            }
            console.debug('[天地图换图]', src, '→', cvaSrc);
            return;
        }

        const { srcX, srcY, srcZ, scale, dx, dy } = downgradeTile(x, y, z, MAX_Z);
        const downgradeKey = `${srcX},${srcY},${srcZ},${z}`;

        if (existsCoordSet.has(downgradeKey)) {
            img.src = "data:image/gif;base64,R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs=";
            img.style.display = "none";
            return;
        }

        img["downgradeKey"] = downgradeKey;
        existsCoordSet.add(downgradeKey);

        const vecSrc = generateTileUrl(srcX, srcY, srcZ, 'vec_w');
        const cvaSrc = generateTileUrl(srcX, srcY, srcZ, 'cva_w');
        if (!vecSrc || !cvaSrc) return;

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

        if (!addImgEls) {
            img.style.backgroundImage = `url("${vecSrc}")`;
            img.style.backgroundSize = `${TILE_SIZE}px ${TILE_SIZE}px`;
            img.src = cvaSrc;
        } else {
            const cvaImg = createCvaImg(cvaSrc, img);
            cvaImg.style.transformOrigin = 'top left';
            addImgEls.push(cvaImg);
            img.src = vecSrc;
        }
        console.debug('[天地图降级]', `${z} → ${MAX_Z}, src:`, cvaSrc);
    }

    // ... 其余DOM观察器代码保持不变（与原hass_tianditu.js相同）
    // 这里应该包含完整的initDomObserver函数实现
    // 由于篇幅限制，省略了重复的部分，实际使用时请保持原样
}

// 初始化函数
async function initTiandituMap() {
    // 等待配置加载
    if (window.tiandituConfig) {
        await window.tiandituConfig.init();
        window.tiandituConfig.setupProxy();
    }
    
    // 初始化DOM观察器
    initDomObserver();
    
    console.log('[天地图] 初始化完成');
}

// 页面加载后初始化
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initTiandituMap);
} else {
    initTiandituMap();
}