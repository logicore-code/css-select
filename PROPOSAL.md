# css-select 项目申报书

## 基本信息

- 项目名称：css-select —— MoonBit CSS 选择器解析与匹配引擎
- 参赛者：蒋泽宇（logicore-code）
- GitHub 仓库：https://github.com/logicore-code/css-select
- 项目方向：MoonBit 基础库 / 文档处理与 WASM 前端工具链
- 是否为移植/参考项目：参考已有开源项目重新实现（非逐行移植）

## 项目简介

css-select 是一个用 MoonBit 从零实现的 CSS 选择器解析器与节点匹配引擎，遵循 W3C Selectors Level 3 标准。输入一个选择器字符串（如 `div#nav > li.item:nth-child(2n+1)`）和一棵节点树，输出哪些节点命中。解析器是手写递归下降，不依赖任何库；匹配器通过 `SelectableNode` trait 泛型化，可以对接任意文档树结构——包括本仓库内置的参考 DOM、用户自己的 HTML 解析器 AST，或 WASM 端的浏览器 DOM 包装。

选这个题的原因很直接：MoonBit 生态目前有 TOML、URL、CommonMark 等格式解析库，但没有 CSS 选择器引擎。而只要 MoonBit 想做 HTML 解析、服务器端渲染、WASM 端的轻量 DOM 查询，就绕不开这个组件。

## 通用性说明

本项目定位为底层基础库，不绑定具体 DOM 实现。`SelectableNode` trait 只要求 6 个方法（取标签名、取属性、取父节点、取子节点、兄弟索引、同标签兄弟索引），任何树形结构实现这 6 个方法后即可使用同一套匹配逻辑。CLI 和内置 `DomNode` 只是参考实现和测试夹具，不构成对使用方式的约束。

## 预期使用场景

1. **MoonBit HTML 解析器配套查询层**：后续若有人用 MoonBit 写一个 HTML5 解析器（类似 html5ever），css-select 可以直接作为其 `querySelectorAll` 后端，不需要另写匹配逻辑。
2. **WASM 端轻量 DOM 处理**：在浏览器里用 MoonBit 写工具时，可以把一个 JSON 描述的 DOM 灌进 `DomNode`，用选择器做批量筛选，避免直接调用浏览器 API 的序列化开销。
3. **服务器端模板/静态站点生成器**：MoonBit 做 SSG 时，需要在生成的 HTML 树上做后处理（给所有外链加 `rel`、给代码块加 class），选择器是最自然的查询语言。
4. **测试断言工具**：框架测试里断言"渲染出的树中存在 `.error` 节点且嵌套在 `form` 内"，比遍历树写断言可读性高很多。

## 核心功能范围

- 手写字节级 tokenizer（ident / number / quoted string / 空白），返回带位置的 `ParseError`；
- 递归下降解析器，支持：类型选择器、通配符、ID、class、属性选择器（`=`/`!=`/`^=`/`$=`/`*=`/`~=`/`|=` 七种操作符 + `i` 大小写不敏感标志）、`:nth-child(an+b)`（含 `odd`/`even`/`-n+3` 等）、`:nth-of-type`、`:first-child`、`:last-child`、`:root`、`:empty`、`:not()`、`:is()`、`:lang()`；
- 四种组合符：后代、子节点、相邻兄弟、通用兄弟；逗号分隔选择器列表；
- 泛型匹配引擎 `matches_list` / `matches` / `query_all`，从 subject 出发沿祖先链短路匹配；
- 内置 `DomNode` 参考实现 + 命令行工具（选择器和树均从命令行参数读入）；
- 23 个测试用例，覆盖解析错误、组合符、属性操作符、nth-child 算术和伪类。

## 参考项目说明

本项目参考了以下已有实现的接口设计和语义，但代码为 MoonBit 原生重写，未翻译任何源码：

- **原项目名称**：nwsapi（JS 生态最广泛使用的 CSS 选择器引擎，被 jsdom、Cheerio 等依赖）
- **原项目链接**：https://github.com/dperini/nwsapi
- **原项目许可证**：MIT
- **另参考**：goquery 内部的 css-select（https://github.com/andybalholm/cascadia，BSD-2-Clause），主要对照其 trait 抽象方式和 nth-child 算术。
- **本项目许可证**：Apache-2.0

与参考实现相比，本项目不追求完整覆盖 Selectors Level 4 全部伪类，而是先把 Level 3 最常用的子集做扎实；不内置 HTML 解析器，只暴露 trait，由上层库对接。
