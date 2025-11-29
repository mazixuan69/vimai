# VimAI - Vim智能助手插件

VimAI 是一个为 Vim 编辑器开发的智能助手插件，它将 OpenAI API 集成到 Vim 中，让用户可以在编辑器内直接与 AI 进行交互对话，并通过 AI 控制编辑器的各种功能。

## 🌟 功能特性

### 核心功能
- **🤖 AI对话**: 在 Vim 中与 OpenAI GPT 模型进行自然语言对话
- **🎯 智能API调用**: AI 可以调用 Vim 编辑器的各种功能来帮助你
- **🔒 安全确认**: 所有 AI 发起的操作都需要用户确认
- **📝 系统提示**: 详细的系统提示让 AI 了解 Vim 环境和可用功能

### 支持的AI操作
1. **MakeUserChoose** - 显示确认对话框
2. **AskUser** - 获取用户输入
3. **ExecuteShell** - 执行 shell 命令
4. **ReadFile** - 读取当前文件内容
5. **WriteNewFile** - 写入新文件（覆盖当前内容）
6. **WriteFile** - 在当前位置插入内容
7. **MoveCursor** - 移动光标到指定位置

## 🚀 快速开始

### 安装
1. 将 `ai.vim` 和 `main.vim` 文件复制到你的 Vim 插件目录
2. 或者在 `.vimrc` 中添加插件路径

### 配置
在 Vim 中运行以下命令进行初始化：
```vim
:call Init()
```

系统会提示你输入：
- **ApiKey**: 你的 OpenAI API 密钥
- **BaseUrl**: API 基础 URL（默认：https://api.openai.com/v1/chat/completions）
- **Model**: 使用的模型（默认：gpt-3.5-turbo）

### 基本使用
```vim
" 开始对话
:call ChatWithOpenAI("你好，请帮我列出当前目录的文件")

" 设置自定义 API 密钥
:call SetOpenAIKey("your-api-key-here")

" 设置不同的模型
:call SetOpenAIModel("gpt-4")

" 清空对话历史
:call ClearChatHistory()
```

## 🎯 使用示例

### 示例1：文件操作
```vim
" 让 AI 读取当前文件
:call ChatWithOpenAI("请读取当前文件的内容")

" 让 AI 在文件末尾添加内容
:call ChatWithOpenAI("请在文件末尾添加一行：# 这是新添加的行")
```

### 示例2：系统命令
```vim
" 让 AI 执行 shell 命令
:call ChatWithOpenAI("请显示当前目录下的所有文件")

" 让 AI 显示文件大小
:call ChatWithOpenAI("请显示当前文件的大小")
```

### 示例3：获取用户输入
```vim
" 让 AI 询问用户信息
:call ChatWithOpenAI("请询问用户想要创建什么类型的文件")
```

## 🔧 API 参考

### 核心函数

#### `Init()`
初始化插件，设置 API 密钥、基础 URL 和模型。

#### `ChatWithOpenAI(user_input)`
与 AI 进行对话，支持智能 API 调用。
- **参数**: `user_input` - 用户输入的文本
- **返回**: AI 回复或错误码（1-4）

#### `SetOpenAIKey(api_key)`
设置 OpenAI API 密钥。
- **参数**: `api_key` - API 密钥字符串
- **返回**: 0（成功）

#### `SetOpenAIBaseUrl(base_url)`
设置 API 基础 URL。
- **参数**: `base_url` - 基础 URL 字符串
- **返回**: 0（成功）

#### `SetOpenAIModel(model)`
设置使用的 AI 模型。
- **参数**: `model` - 模型名称（如 "gpt-3.5-turbo"）
- **返回**: 0（成功）

#### `ClearChatHistory()`
清空对话历史记录。
- **返回**: 0（成功）

### 工具函数

#### `Api(ApiType, ApiInfo)`
通用 API 接口，执行各种编辑器操作。
- **参数**:
  - `ApiType` - API 类型（见支持的类型）
  - `ApiInfo` - API 参数信息
- **返回**: 操作结果或错误码

## ⚠️ 安全说明

### 用户确认机制
所有 AI 发起的 API 调用都需要用户确认：
1. AI 返回 JSON 格式的操作请求
2. 系统显示详细的操作信息
3. 用户选择"允许"或"拒绝"
4. 只有用户确认后才会执行操作

### 错误处理
系统使用以下错误码：
- **1**: 参数错误或 API 类型无效
- **2**: 文件读取错误（文件不存在）
- **3**: 位置错误（行号或列号超出范围）
- **4**: 无法解析 API 响应

## 🎨 AI 响应格式

AI 可以通过以下 JSON 格式请求执行操作：
```json
{
  "action": "ExecuteShell",
  "parameters": "ls -la",
  "reason": "显示当前目录所有文件"
}
```

### 必需字段
- **action**: 要执行的 API 操作名称
- **parameters**: 操作参数（字符串格式）
- **reason**: 执行该操作的原因说明

## 🔍 故障排除

### 常见问题

#### API 调用失败
- 检查网络连接
- 确认 API 密钥有效
- 检查 API 基础 URL 是否正确

#### AI 不执行操作
- 确认你使用的是支持的 API 操作类型
- 检查参数格式是否正确
- 查看错误信息了解具体原因

#### 用户确认对话框不显示
- 确保 Vim 支持对话框功能
- 检查是否在支持的终端环境中运行

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个插件。

## 📄 许可证

MIT License - 详见 LICENSE 文件

## 🙏 致谢

- OpenAI 提供强大的 GPT 模型
- Vim 社区的支持和启发