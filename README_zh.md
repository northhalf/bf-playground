<div align="center">
  <div style="width:200px">
    <a href="https://github.com/northhalf/bf-playground">
      <img src="assets/icon.png" alt="bf_playground" width="200">
    </a>
  </div>

<h1>bf_playground</h1>

![Status](https://img.shields.io/badge/status-active-brightgreen) ![CI](https://github.com/northhalf/bf-playground/actions/workflows/deploy.yml/badge.svg) ![Release](https://img.shields.io/github/v/release/northhalf/bf-playground) ![Downloads](https://img.shields.io/github/downloads/northhalf/bf-playground/total) ![License](https://img.shields.io/badge/license-MIT-blue)

<p align="center"><a href="./README.md">English</a> | 中文</p>

<h5>用 Flutter 编写的 Brainfuck 实时预览 playground。</h5>

浏览器直接运行,另有 Windows / macOS / Android 安装包。

[![GitHub Pages 在线体验](https://img.shields.io/badge/GitHub%20Pages-%E5%9C%A8%E7%BA%BF%E4%BD%93%E9%AA%8C-222222?style=for-the-badge&logo=github&logoColor=white)](https://northhalf.github.io/bf-playground/)

</div>

## 演示

<p align="center">
  <img src="assets/demo.webp" alt="桌面布局:Hello World 程序在纸带网格上实时预览" width="800"><br>
  <em>桌面端:Hello World 程序执行中——代码框内高亮当前指令,纸带网格换行排布并跟随指针。</em>
</p>
<p align="center">
  <img src="assets/demo-mobile.webp" alt="手机竖屏布局:纸带在上,输入面板在下" width="280"><br>
  <em>手机端:同一会话的竖排布局——纸带网格在上,按键、控制与代码框在下。</em>
</p>

## 特性

- **实时预览** —— 在代码框末尾追加的运算符会立即带动画逐条执行;未闭合的 `[` 进入 pending 状态,等 `]` 配平后续跑
- **计算器式按键** —— 8 个 Brainfuck 指令一键输入
- **代码视图** —— 手写语法高亮:指令按类别着色(指针 / 增减 / 输入输出),嵌套括号按深度彩虹分色,注释淡灰;当前指令在编辑器和下方指令条中同步高亮
- **纸带网格** —— 单元格到右边界自动换行并以连线相接,视图跟随指针滚动,数值变化时闪烁
- **预置输入 / 实时输出** —— 输入耗尽时暂停并提示,补充输入后继续执行
- **播放控制** —— 单步、播放/暂停、重置,速度可调(步/秒)

## 本地运行

```bash
flutter pub get
flutter run -d web-server   # 用任意浏览器打开输出的地址
```

## 测试与 lint

```bash
flutter test
flutter analyze
```

## 技术栈

- Flutter Web(Dart 3)
- [brainfxxk](https://pub.dev/packages/brainfxxk) —— 唯一运行时依赖:解析器、`Stepper`、`Tape`
- 不引入状态管理 / 语法高亮包;UI 统一监听单个 `ChangeNotifier`(`VmController`)
