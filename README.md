# tianditu_map
天地图瓦片替换homeassistant内置地图。

[![hacs_badge](https://img.shields.io/badge/HACS-Custom-orange.svg)](https://github.com/hacs/integration)

这个 Home Assistant 自定义集成将默认的 Carto 地图替换为中国的天地图服务。

## 功能特点

- 🗺️ 将 Home Assistant 默认地图替换为天地图
- 🔐 安全的 API Key 管理（通过 secrets.yaml）
- 🚀 支持高缩放级别（通过降级算法）
- 🎯 自动处理瓦片加载和版权信息
- 🔄 实时 DOM 监控，动态替换地图瓦片

## 安装

### 方法一：通过 HACS（推荐）

1. 在 HACS 中点击「自定义仓库」
2. 添加此仓库地址
3. 选择「集成」类别
4. 安装集成
5. 重启 Home Assistant

### 方法二：手动安装

1. 下载本仓库
2. 将 `custom_components/tianditu_map` 文件夹复制到您的 Home Assistant 配置目录中的 `custom_components` 文件夹
3. 重启 Home Assistant

## 配置

### 1. 获取天地图 API Key

1. 访问 [天地图 API 申请页面](http://lbs.tianditu.gov.cn/home.html)
2. 注册账号并申请 **个人开发者** 账户
3. 建立应用，记录您的 API Key

### 2. 配置 Home Assistant

在您的 `configuration.yaml` 文件中添加：

```yaml
tianditu_map:
  api_key: !secret tianditu_key
```

在 `secrets.yaml` 文件中添加：

```yaml
tianditu_key: "您的天地图API_Key"
```

### 3. 重启 Home Assistant

重启 Home Assistant 使配置生效。

## 使用方法

配置完成后，Home Assistant 中的地图卡片将自动使用天地图服务：

1. 在 Lovelace 界面添加地图卡片
2. 地图将显示天地图的地图和标注图层
3. 支持所有缩放级别（超过18级时自动降级处理）

## 技术说明

### 瓦片降级算法

当缩放级别超过天地图支持的最大级别（18级）时，集成会自动使用降级算法：
- 将高级别瓦片转换为低级别瓦片
- 通过 CSS 变换保持显示精度
- 自动处理瓦片拼接和偏移

### 图层说明

- **vec_w**: 地图底图（无标注）
- **cva_w**: 中文标注图层
- 两个图层叠加显示完整的中文地图

## 故障排除

### 地图不显示

1. 检查 API Key 是否正确
2. 确认 `secrets.yaml` 文件格式正确
3. 查看 Home Assistant 日志是否有错误信息

### 部分区域显示空白

1. 检查网络连接，确保可以访问天地图服务
2. 确认 API Key 有足够的调用额度

### 版权信息显示

集成会自动隐藏天地图的版权信息，如需显示请修改前端代码。

## 文件结构

```
custom_components/tianditu_map/
├── __init__.py              # 集成主文件
├── manifest.json            # 集成清单
└── frontend/
    ├── tianditu_config.js   # 配置和代理逻辑
    └── hass_tianditu.js     # 核心替换逻辑
```

## 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 贡献

欢迎提交 Issue 和 Pull Request！

## 致谢

- 感谢 [天地图](http://www.tianditu.gov.cn/) 提供的地图服务
- 感谢原脚本作者 [NXY6668](https://gist.github.com/NXY666) 提供的代码 [NXY666/hass_tianditu.js](https://gist.github.com/NXY666/47104ba68473b338da61c7e59bcf8bcf)



## 更新日志

### v1.0.0
- 初始版本发布
- 支持天地图瓦片替换
- 安全的 API Key 配置
