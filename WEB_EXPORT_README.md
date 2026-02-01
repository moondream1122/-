# 極光連線 - 多平台導出指南

## 支援平台

- 🌐 **網頁版** (HTML5)
- 📱 **Android** (APK)
- 🍎 **iOS** (Xcode項目)

## 移動設備特性

### 觸摸控制
- 觸摸螢幕任意位置控制擋板方向
- 快速滑動觸發精準格擋
- 自適應觸摸靈敏度

### 優化設置
- 調整精準格擋閾值以適應觸摸輸入
- 支援各種螢幕尺寸和方向
- 優化UI佈局

## 網頁版本導出

## 如何導出網頁版本

### 方法1：使用Godot編輯器（推薦）

1. 打開Godot編輯器
2. 載入項目（project.godot）
3. 點擊菜單 **項目(Project) > 導出(Export)**
4. 在導出窗口中選擇 **HTML5** 預設
5. 設置導出路徑（例如：`../web_build`）
6. 點擊 **導出項目(Export Project)**

### 方法2：命令行導出

```bash
# Windows
godot --export "HTML5" ../web_build

# 或指定完整路徑
godot --path . --export "HTML5" "C:/path/to/web_build"
```

## 網頁版本特點

- 完全在瀏覽器中運行
- 支持滑鼠控制（桌面設備）
- 支持觸摸控制（移動設備）
- 自適應畫面大小
- 優化的載入畫面和說明

## 移動設備版本導出

### Android APK導出

1. 確保已安裝Android SDK和JDK
2. 在Godot中：**項目 → 導出 → Android**
3. 配置keystore（用於簽名）
4. 導出APK文件
5. 安裝到Android設備測試

### iOS應用導出

1. 需要macOS和Xcode
2. 在Godot中：**項目 → 導出 → iOS**
3. 打開Xcode項目
4. 配置開發者帳號和provisioning profile
5. 構建並安裝到iOS設備

### 快速導出工具

使用提供的批處理文件快速導出：

- `export_web.bat` - 網頁版本
- `export_mobile.bat` - 移動設備版本（Android/iOS）

## 平台差異