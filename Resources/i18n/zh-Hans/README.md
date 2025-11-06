# 爱啪思道

轻松管理多个 App Store 账户。

[English 🇺🇸](../../../README.md)

## 👀 概览

![截图](../../../Resources/Screenshots/README_PREVIEW_iPhone.png)
![Mac 截图](./Resources/Screenshots/README_PREVIEW_MAC.png)

## 🌟 主要功能

- **多账户管理**: 支持多个 Apple ID
- **跨区访问**: 选择您的 App Store 地区
- **应用搜索**: 按关键词搜索应用
- **应用下载**: 从 App Store 下载应用
- **IPA 安装**: 在非越狱设备上安装 IPA
- **IPA 分享**: 轻松分享 IPA 文件
- **历史版本**: 下载应用的历史版本
- **免费应用入库**: 一键将免费应用加入您的购买记录

## 📝 使用须知

### 前提条件

- [iOS App Signer](https://dantheman827.github.io/ios-app-signer/)
- 使用安装向导生成的二维码下载证书，并在“设置 → 通用 → 关于本机 → 证书信任设置”中启用完全信任

### 问题排查

- 对于类似 [#1](https://github.com/Lakr233/Asspp/issues/1) 的问题，请使用提供的签名工具。
- 如果安装失败，请确认目标设备已扫描证书二维码并在系统设置中启用信任。
- 如果应用崩溃或退出，请确认您已登录 App Store 账户，并且您的设备系统版本受支持。

### 安装方式对比

| 项目             | 本地安装           | AirDrop 安装                                 |
| ---------------- | ------------------ | -------------------------------------------- |
| 设备要求         | 单台设备           | 两台设备                                     |
| App Store 兼容性 | 无法检测\*         | 兼容                                         |
| 自动更新         | 不支持             | 支持                                         |
| 前提条件         | 手动安装并信任证书 | 目标设备需登录同一账户，且已安装至少一个 App |
| 网络要求         | 需要               | 不需要                                       |

- 此安装方法不会在 App Store 中注册软件，因此无法自动更新。手动更新可以保留数据，但后续安装无法使用本软件，也无法覆盖现有应用。

## 🚀 快速上手

# iPhone

- 前往 [Releases](https://github.com/Lakr233/Asspp/releases) 页面下载最新版本 Asspp.ipa
- 使用签名软件重新签名之后安装
- 或者此[快捷指令](https://www.icloud.com/shortcuts/d3c28f125b724a2da136d560fcf360dc)
  > 复制链接后运行或者在共享页添加后，直接在打开链接时选择 Open In Sidestore

# Mac
- 前往 [Releases](https://github.com/Lakr233/Asspp/releases) 页面下载最新版本 Asspp.zip
- 解压后打开 Asspp.app


### 首次运行与信任应用（推荐步骤）
1. 尝试双击打开应用；若出现“无法打开，因为无法确认开发者”或类似提示：
   - 在 Finder 中定位到 Asspp.app，按住 Control 键并点击应用图标，选择“打开”，在弹窗中再次点击“打开”。此操作会为该应用建立信任记录，通常只需执行一次。
2. 如果 Control+点击无效或仍受阻：
   - 打开 系统设置 -> 隐私与安全（或“系统偏好设置 -> 安全性与隐私”旧版 macOS），在“通用/安全性”区域的底部查找被阻止的应用并点击“仍要打开”或“允许”，可能需要输入管理员密码。
3. 建议从本仓库 Releases 下载并核验发布信息，确保来源可信后再按上述方法信任并打开应用。

> 说明：以上步骤是 macOS Gatekeeper 的标准处理方式，旨在保护系统安全。按照推荐流程操作可以最小化风险并确保应用能正常运行。


## 📋 已构建的包

请查看 [Releases](https://github.com/Lakr233/Asspp/releases) 页面。

## 🧑‍⚖️ 开源许可

自 2.2.16 版本起，本项目采用 [MIT](../../../LICENSE) 许可证。

## 🥰 鸣谢

- [ipatool](https://github.com/majd/ipatool)
- [ipatool-ios](https://github.com/dlevi309/ipatool-ios)
- [localhost.direct](https://get.localhost.direct/)

_`ipatool-ios` 和 `localhost.direct` 已在当前项目中不再使用。_

---

Copyright © 2025 Lakr Aream. All Rights Reserved.
