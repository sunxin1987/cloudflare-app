# Cloudflare 账号管理（Android 客户端）

WebView 封装的单文件网页应用（`index.html`），直接调 Cloudflare API v4。

## 功能（v1.1.4）

- 用量统计改用 GraphQL Analytics API：旧版 Zone Analytics REST 接口已下线（报 "Zone Analytics API is sunset"），24 小时用小时分组、7/30 天用天分组，统计与趋势图不变。

- API Token 登录（Token 只存本机 localStorage，不上传任何地方）
- 域名：列出所有 Zone（状态、套餐、NS）
- DNS：按域名查看记录，添加记录（A/AAAA/CNAME/TXT/MX/NS/SRV，TTL、代理开关），删除记录
- Workers：按账号列出脚本（修改时间、用量模式）；**部署 Worker**：粘贴代码直接部署，自动识别 ES Module / Service Worker 格式，可选开通 workers.dev 子域名（需 Workers Scripts · Edit）
- Pages：按账号列出项目（域名、生产分支、最新部署状态），点项目看最近 20 条部署记录，每条可**重新部署**；**新建项目**；**上传单个文件部署**（如 index.html，走 Direct Upload API：取上传凭证 → 传文件 → 建部署 → 轮询上线，需 Pages · Edit；多文件整站请用电脑 Wrangler 或控制台）
- 用量：按域名看请求数、缓存命中率、流量、拦截威胁、页面浏览、独立访客，及请求数趋势图（24 小时 / 7 天 / 30 天）

v1.1.4 只修用量统计：旧版 Zone Analytics REST 接口（/zones/:id/analytics/dashboard）已下线，改用 GraphQL Analytics API（POST /client/v4/graphql，httpRequests1hGroups / httpRequests1dGroups，字段名是 pageViews 不是 pageviews；返回分组不按时间排，画图前先按日期排好序）。v1.1.3 只加一个系统主题：默认浅色/深色跟随手机系统自动切换，右上角按钮可手动切“跟随系统 / 浅色 / 深色”，选择记在本机 localStorage。v1.1.2 只修一个登录 403：登录时 App 曾调 `GET /user` 取邮箱，但该接口要「User · User Details · Read」权限，Token 的 8 项权限里没有，于是 403。改成只调 `GET /user/tokens/verify` 验证，登录后显示「已登录」，不再调 `/user`。现有 Token 不用重建，直接装新版即可。v1.1.1 只修一个启动闪退：v1.1.0 打包时 d8 只收到了 MainActivity.class，匿名内部类 MainActivity$1（文件选择器）没进 dex，启动就报 NoClassDefFoundError。现打包脚本已改成把全部 .class 都传给 d8，并用 dexdump 核对过 dex 里两个类都在。

## 使用

1. 安装 `cloudflare-v1.1.4.apk`（包名 com.sunyazhong.cloudflare）。v1.1.4 与之前版本同一个签名密钥，可直接覆盖安装，不用卸载。
2. 打开 App，粘贴 API Token，点连接。
3. 创建 Token：Cloudflare 控制台 → 头像 → My Profile → API Tokens → Create Token → Create Custom Token，建议权限：Account·Pages·Read、Account·Pages·Edit（部署 Pages 才需要）、Account·Workers Scripts·Read、Account·Workers Scripts·Edit（部署 Workers 才需要）、Account·Account Settings·Read、Zone·Zone·Read、Zone·DNS·Edit、Zone·Analytics·Read。

## 打包

- 源码：`index.html`（网页版）；安卓壳在 `android/`（从 speed-test-app 的壳改来）。
- `./build-apk.sh`：aapt2 + javac + d8 + zipalign + apksigner，产物在 `~/workspace/your_files/cloudflare/cloudflare-v1.1.4.apk`，已用 apksigner verify 与 aapt2 dump badging 验过，并用 dexdump 核对 dex 里 MainActivity 与 MainActivity$1 两个类都在。调试签名密钥固定在 `android/debug.keystore`，以后版本可直接覆盖安装。**d8 必须传全部 .class 文件（glob），只传 MainActivity.class 会丢掉匿名内部类导致启动闪退（v1.1.0 教训，见 AGENTS.md）。**

## 说明

- 已用用户 Token 实测过 `GET /user/tokens/verify` 与 `GET /accounts` 均成功（2026-11-22）。登录不再调 `GET /user`（该接口要「User · User Details · Read」权限，Token 的 8 项权限里没有，见 v1.1.2）。接口报错时 App 内会显示 Cloudflare 返回的错误信息，403 一般是 Token 权限不足。部署功能按官方文档的接口实现：Workers 用 PUT multipart 上传（main_module / body_part 自动识别），Pages 单文件用 Direct Upload 三步流程（upload-token → /pages/assets/upload → 建部署 → 轮询），重试部署用 retry 接口；Pages 官方无回滚接口，故未做回滚。
- iOS 未签名 IPA、GitHub 仓库与 Pages 网页版暂未做，用户要再说。
