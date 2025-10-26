# AMap Tile Layer for Home Assistant

使用高德地图替换Home Assistant内置的Carto地图瓦片，支持坐标纠偏。

## 功能特点

- 🗺️ 替换Carto地图为高德地图
- 🎯 自动坐标纠偏（WGS84转GCJ02）
- 🔧 支持自定义代理服务
- 📱 完美兼容移动端

## 安装

### 通过HACS安装

1. 在HACS中添加自定义仓库
2. 搜索 "AMap Tile Layer" 并安装
3. 重启Home Assistant

### 手动安装

1. 将 `amap-tile-layer.js` 复制到 `/config/www/community/amap_ha/`
2. 在Lovelace配置中添加资源

## 配置

### Lovelace资源配置

```yaml
resources:
  - url: /local/community/amap_ha/amap-tile-layer.js
    type: module