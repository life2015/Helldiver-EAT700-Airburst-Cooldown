# 来源

- 配置结构与参考值来自 Filediver，以及工作区 research 的本地数据分析。
- `scripts/archive.py` 来自本地 SentryAimRetention 编码工具，经 EAT700Cooldown 复用。
  上游：https://github.com/CowboyBingus/SentryAimRetention 。本地工作副本未声明仓库级许可证。
- `scripts/lua_host.py` 来自 RoverFireSpread；多渠道包装和离线集成测试复用 EAT700Cooldown 中已验证的实现。
- Bingus Shared Loader：https://github.com/CowboyBingus/BingusSharedLoader 。
  v14 包封装完整官方 v14 Wwise 回调字节码；v15 包不含加载器，需另行安装官方 v15 或更新版。
  固定输入及 SHA-256：
  - v14：https://github.com/CowboyBingus/BingusSharedLoader/releases/download/v14/Bingus-Shared-Loader-v14.zip
    `7FA8AF328AC2C98F68DD5946D94444315DD61B2B3504B0788301700CC9C023B2`
  - v15（仅用于测试）：https://github.com/CowboyBingus/BingusSharedLoader/releases/download/v15/Bingus-Shared-Loader-v15.zip
    `FA766634DFF3F7D1FD9C5C0EBA72B1FBABAD8721710491CAAA4E12A598028CDA`

本包不包含游戏 DLL、完整游戏配置表或进程内存记录。
