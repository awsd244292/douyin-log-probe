# DouyinLogProbe（抖音日志探针）

独立抖音 iOS 注入插件：全量抓取 App 内"大小事"事件 + 类名探针（找出所有类名对应什么），日志按 AI 可读格式输出（内容全、字符少），服务于"改造抖音功能时找海底捞针"。

设计来源：DYYY 2.3-0（监听器模式）、CrashLogger 1.4.9（抓捕基础设施与卸载链）、aweJ 1.2.0（持久化思路）三份逆向报告。

## 模块（7 个，DCLOrchestrator 骨架）

| 模块 | 职责 |
|---|---|
| DLPOrchestrator | 总控：applyCurrentProfile / shutdownAll，总开关前置 |
| DLPClassProbe | 类名探针：runtime 全量枚举 → 按 image/前缀聚类 → 落盘 `classmap.json`，交叉标注三插件已知 hook 类 |
| DLPEventTracer | 大小事：页面跳转 / sendEvent 全量 / 网络请求 / AVPlayer 6 方法 / TTVideoEngine 5 方法 / 登录监听 2 点 + 绕过登录 6 点（AWEAccountManager-isLogin/hasLogin、AWEUserAccount-isLogin、三个登录VC） / NSBundle / 数据落盘嗅探 |
| DLPPerfProbe | FPS（CADisplayLink）/ 内存（task_info 15s）/ 主线程卡顿看门狗（observer+独立线程双路） |
| DLPCrashCatcher | 12 信号 sigaction + 备用栈 + 未捕获异常 + 60s 自愈定时器 |
| DLPBypassCatcher | 绕过登录专用捕捉器：三开关 key + 官方 isLogin/userID 轮询（变化才记）、present/dismiss 追踪、3s 未 dismiss 告警、开关 ON→OFF 翻转告警（疑似 DYYY 自动禁用） |
| DLPLogHub | 日志中枢：`ts\|K\|domain\|class\|event\|detail`；NSLog + 内存 2000 行 + 落盘 `Documents/DLPLogs/` 按日轮转（保留 7 天） |
| DLPSettings | 设置页注入 `AWESettingsViewModel.sectionDataArray` → 「日志探针」分区，开关热切换 |

## 日志格式（AI 可读）

```
1739500000|K|login|AWEUserServiceListener|didFinishLoginWithUid:|
1739500001|D|net|NSURLSession|dataTaskWithRequest:|GET https://...
```

- `ts`=秒级时间戳；`K`=关键常驻，`D`=细节（需开"细节日志"开关）
- `domain` ∈ login player page net perf crash ui data sys probe plugin
- detail 清洗：`|`→`/`、换行→空格、超 220 字符截断

## 开关（NSUserDefaults，默认）

- DLPEnabled=YES（总开关；关则全部模块卸载）
- DLPModuleClassProbe/EventTracer/PerfProbe/CrashCatcher=YES
- DLPDetailEnabled=YES（全量默认开：D 级细节与 K 级关键同步输出）
- DLPLogToFile=YES，DLPLogKeepDays=7
- DLPStderrCapture=YES（收其他插件日志；若同装 CrashLogger，后装的生效）

## Hook 规范

- 只用运行时 `method_setImplementation`（DLPRouter），无 Logos/fishhook
- 类名全部 `NSClassFromString` 动态解析，不存在 → 静默跳过
- 幂等安装；卸载时比对当前 IMP 仍是 hook 才还原
- 参数读取规则：无参/公开 API 可读参数；私有**多参方法只记类名+selector**（如 `broadcastLoginSuccess:platform:reason:`），防调用约定踩雷
- 标量参数 hook（`setRate:`/`setCurrentPlaybackTime:`/`setPlaybackSpeed:`/`setImageScaleType:`）走 `DLPHookInstallChecked`：运行时校验参数类型编码，对不上就跳过安装并记 K 级日志，宁可少抓一条也不崩

## 已知局限（诚实边界）

1. `TTAccountHttpRequest::setURLString:` 是 C++ 方法，ObjC runtime 够不着，v1 未覆盖
2. 网络"耗时"需要 delegate 级 hook，v1 只记 URL+方法+resume 时机
3. 卡顿只记时长不抓栈（抓栈需 thread_get_state + 符号化，后续项）
4. stderr 重定向恢复需宿主重启（fd 级别）
5. 本地构建为 arm64 未签名；真机双架构 + 签名走 CI/重签渠道

## 构建

```bash
bash tools/syntaxcheck.sh   # 语法检查（clang 缺失时 loud fail）
bash tools/build_dylib.sh   # 交叉编译 → build/DouyinLogProbe.dylib（含 Mach-O 自检）
```

push / 打包等外部动作永远等用户确认。
