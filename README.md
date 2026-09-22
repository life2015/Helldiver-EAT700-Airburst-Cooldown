# 火次抛使用空爆弹头并且减CD到标准次抛

火焰次抛改为 RL-77 空爆弹药，保留 Flak / Cluster 双模式，同时把基础 CD 从 140 秒改为 70 秒。
当前 5% 与 10% 舰船升级后约 59.85 秒，菜单取整显示 60 秒。常规 EAT-17 保持原版。

只提供两个渠道，二选一：

- v14 内置加载器：本包必须赢得 Wwise 启动资源优先级。
- v15 需要额外安装加载器：另装官方 Bingus Shared Loader v15 或更新版本。

不要同时启用 EAT700Cooldown 纯冷却版或近炸燃烧版。安装、优先级及验证步骤见 [INSTALL.txt](INSTALL.txt)。
0.2.3 适配 Steam build 25327279；2026-09-23 用户确认空爆版完成并要求打包。
本地使用 v15 渠道；两个渠道均有离线加载测试，v14 实机与联机未单独验证。

## 构建

Windows x64，Python 3，本机游戏 `bin/lua51.dll`。可用 `HD2_GAME_ROOT` 指定游戏目录。

```powershell
python scripts/build.py
python scripts/test.py --entities "C:\your-extraction\generated_entities.dl_bin"
```

构建工具包含在本项目。首次构建下载官方 v14/v15 ZIP 到 `build/` 并校验固定 SHA-256；
也可提前放入 `build/Bingus-Shared-Loader-v14.zip` 和 `build/Bingus-Shared-Loader-v15.zip`。
玩法测试需要从自己匹配版本的游戏中提取 `generated_entities.dl_bin`，通过 `--entities` 指定。
测试先校验两张配置表的大小和 SHA-256，再缓存到被 Git 忽略的 `build/test-fixtures/`；后续可直接运行 `python scripts/test.py`。
可选 `--ffi-reference PATH` 用于与另一模组的 Windows API Lua 工厂做双向加载兼容检查。
这些游戏数据不随仓库分发，构建安装包不依赖它们，也不依赖相邻项目。

打包时离线执行真实发布版加载器，验证 v14 回调和故障隔离、v15 双向 patch 优先级自动发现及缺失模块处理。
两包的玩法实现字节码一致。ZIP 输出在 `releases/`，摘要与哈希在 `build/package-matrix.json`。
构建不会部署文件或访问游戏进程。
