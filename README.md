# OCS DeepSeek 本地接口

将 DeepSeek API 接入 OCS 网课助手的本地 HTTP 服务。支持单选、多选、判断和填空题，提供 Windows 启动脚本与可直接导入的 OCS 题库配置。

本项目基于 [TheTianQiong/OCS_AI_API](https://github.com/TheTianQiong/OCS_AI_API) 修改，保留原作者 MIT 许可证；部署方案亦参考 [lkd6666/ocs-ai-answerer](https://github.com/lkd6666/ocs-ai-answerer)。这不是 OCS 或 DeepSeek 官方项目。

## 快速开始（Windows）

1. 安装 [Node.js](https://nodejs.org/) 22 或更新的 LTS 版本。
2. 下载本仓库 ZIP 并完整解压，或执行 `git clone https://github.com/shuaitianzuo/ocs-deepseek.git`。
3. 双击 `start.cmd`（或 `启动.cmd`）。首次运行自动安装依赖、创建本地 `.env`，随后提示输入 DeepSeek API Key。
4. 输入 Key 后按回车。输入内容不会显示；Key 仅保存到本地 `.env`，调用接口时发送给配置的 API 服务商。
5. 将 [OCS题库配置.json](./OCS题库配置.json) 的全部内容复制到 OCS 自定义题库配置并保存。
6. 如油猴提示连接权限，允许脚本连接 `127.0.0.1`。用一道练习题查询并人工核对结果。

服务仅监听 `127.0.0.1:3000`，OCS 和本服务需在同一台电脑运行。关机后需重新启动。运行成功后关闭启动窗口，后台服务会继续运行。

DeepSeek API 需要可用额度，网页版会员不等于 API 额度。默认模型为 `deepseek-chat`，可根据服务商实际支持的模型修改。

## 手动启动 / macOS / Linux

```sh
npm ci --ignore-scripts
cp .env.example .env
# 编辑 .env，填写 DEEPSEEK_API_KEY
npm start
```

手动启动时，按 Ctrl+C 停止。Windows 后台启动可运行 `stop.cmd` 停止该服务。

## 配置

编辑本地 `.env`，修改后重启服务：

| 变量 | 默认值 | 作用 |
| --- | --- | --- |
| `DEEPSEEK_API_KEY` | 空 | 必填，自己的 API Key |
| `DEEPSEEK_BASE_URL` | `https://api.deepseek.com/v1` | API 基址，不含 `/chat/completions` |
| `DEEPSEEK_MODEL` | `deepseek-chat` | 服务商支持的模型名 |
| `OCS_PORT` | `3000` | 端口；修改后同步修改 OCS JSON 中的 URL |
| `OCS_TIMEOUT` | `120000` | 单次 API 请求超时，毫秒 |
| `OCS_DEBUG` | `false` | 详细日志，会包含题目和答案 |
| `OCS_DATA_DIR` | 项目下 `data` | 题目存档目录 |
| `OCS_LOG_DIR` | Windows 启动脚本自动选择 | 启动日志目录 |

底层保留了上游的 OpenAI 兼容、Claude、Gemini 适配器，可在 `config.js` 中查看对应环境变量；本项目主要验证 DeepSeek 的兼容接口流程。暂未增加图片题、多模型路由或图形化配置页。

## 接口

- `GET /`：本地服务状态。
- `GET /info`：当前服务商、模型和 API 基址，不返回 Key。
- `GET /search` 或 `POST /search`：接收 `title`、`type` 和 `options`；POST 使用 JSON。
- `GET /archive`：浏览本地题目存档。

```json
{
  "title": "1+1等于几？",
  "type": "single",
  "options": "A. 1\nB. 2\nC. 3"
}
```

成功返回 `{"code":1,"question":"题干","answer":"答案"}`；失败返回 `{"code":0,"msg":"错误说明"}`。题型为 `single`、`multiple`、`judgement`、`completion`。提示词要求多个答案用 `#` 分隔，但模型输出仍需核对。

## 数据与隐私

- `.env`、`data/`、数据库、日志和 `node_modules/` 已加入 `.gitignore`，不要上传含真实 Key 的配置文件。
- 查询时题目与选项会发送给配置的模型服务商，并可能产生 API 费用。
- 题目和答案保存在本地 `data/questions.db`。Windows 启动日志优先使用 `D:\CodexData\Logs\ocs-deepseek`；没有 D 盘则使用项目下的 `logs/`，也可通过 `OCS_LOG_DIR` 指定。
- 本地接口无访问认证。保持仅本机监听，不要直接开放到公网。

## 验证

```sh
npm test
npm audit
```

测试使用本地模拟 API、临时端口和临时数据库，不需要真实 Key，也不会产生费用。覆盖健康检查、配置不返回 Key、缺少题干、多种题型请求和上游错误。模拟测试不能证明真实服务商可用性或答案准确率。

## 来源与许可证

基于 MIT 许可的 [TheTianQiong/OCS_AI_API](https://github.com/TheTianQiong/OCS_AI_API)，上游原文件版本截至 2026-11-01。原作者版权声明见 [LICENSE](./LICENSE)。参考项目为 [lkd6666/ocs-ai-answerer](https://github.com/lkd6666/ocs-ai-answerer)，未复制其实现代码。

主要修改：Windows 启动兼容、首次配置与依赖安装、仅本机监听、请求超时、多答案分隔提示、依赖更新以及无真实 Key 的模拟联通测试。代码经 AI 辅助整理与修改。

用于学习和练习，使用者应遵守课程及平台规则；模型可能答错，本项目不会代替使用者判断答案，也不设置 OCS 的自动提交选项。
