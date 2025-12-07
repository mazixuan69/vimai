" 读取AI配置文件
function! ReadAIConfig()
  " 构建配置文件路径
  let config_path = expand('~/.vim/ai-config.json')

  " 检查配置文件是否存在且可读
  if !filereadable(config_path)
    return {'status': 0, 'message': '配置文件不存在'}
  endif

  " 读取配置文件内容
  let config_content = readfile(config_path)
  if empty(config_content)
    return {'status': 4, 'message': '配置文件为空'}
  endif

  " 合并所有行（处理多行JSON）
  let json_string = join(config_content, "\n")

  " 使用安全JSON解析
  let parse_result = SafeJsonDecode(json_string)
  if !parse_result.success
    return {'status': 3, 'message': 'JSON格式错误: ' . parse_result.error}
  endif

  let config = parse_result.data

  " 验证配置数据结构
  if type(config) != type({})
    return {'status': 3, 'message': '配置文件必须为JSON对象'}
  endif

  " 检查必需字段
  let required_fields = ['api_key', 'base_url', 'model']
  let missing_fields = []
  let valid_fields = {}

  for field in required_fields
    if has_key(config, field) && !empty(config[field])
      let valid_fields[field] = config[field]
    else
      call add(missing_fields, field)
    endif
  endfor

  " 根据缺失字段情况返回不同状态
  if len(missing_fields) == 0
    return {'status': 1, 'config': valid_fields, 'message': '配置完整有效'}
  elseif len(valid_fields) > 0
    return {'status': 2, 'config': valid_fields, 'missing': missing_fields, 'message': '配置部分缺失'}
  else
    return {'status': 3, 'message': '配置文件缺少所有必需字段'}
  endif
endfunction

" 验证配置数据
function! ValidateConfigData(config)
  if type(a:config) != type({})
    return {'valid': 0, 'error': '配置必须是字典类型'}
  endif

  " 验证api_key格式（基本检查）
  if has_key(a:config, 'api_key')
    let api_key = a:config.api_key
    if len(api_key) < 10
      return {'valid': 0, 'error': 'api_key格式无效（长度不足）'}
    endif
  endif

  " 验证base_url格式（基本检查）
  if has_key(a:config, 'base_url')
    let base_url = a:config.base_url
    if base_url !~ '^https\?://'
      return {'valid': 0, 'error': 'base_url必须是有效的HTTP(S) URL'}
    endif
  endif

  " 验证model格式
  if has_key(a:config, 'model')
    let model = a:config.model
    if empty(model)
      return {'valid': 0, 'error': 'model不能为空'}
    endif
  endif

  return {'valid': 1}
endfunction

function! Init()
  " 使用多种方法确定脚本文件所在目录
  let script_dir = ''

  " 方法1：使用 <sfile>（如果可用）
  try
    let script_dir = expand('<sfile>:p:h')
  catch
    let script_dir = ''
  endtry

  " 方法2：如果<sfile>失败，尝试使用当前文件路径
  if empty(script_dir) || !isdirectory(script_dir)
    " 获取当前打开文件的路径
    let current_file = expand('%:p')
    if !empty(current_file)
      let script_dir = fnamemodify(current_file, ':h')
    endif
  endif

  " 方法3：如果还是失败，使用当前工作目录
  if empty(script_dir) || !isdirectory(script_dir)
    let script_dir = getcwd()
  endif

  " 尝试多个可能的ai.vim位置
  let search_paths = [
    \ script_dir . '/ai.vim',
    \ script_dir . '/vimai/ai.vim',
    \ getcwd() . '/ai.vim',
    \ getcwd() . '/vimai/ai.vim',
    \ expand('~/vimai/ai.vim'),
    \ '/root/workspace/repo/vimai/ai.vim'
    \ ]

  let ai_vim_found = 0
  let ai_vim_path = ''

  " 在搜索路径中查找ai.vim
  for path in search_paths
    if filereadable(path)
      let ai_vim_path = path
      let ai_vim_found = 1
      break
    endif
  endfor

  if ai_vim_found
    execute 'source ' . fnameescape(ai_vim_path)
    " 为了调试，可以显示找到的路径
    " echom "找到ai.vim在: " . ai_vim_path
  else
    echohl ErrorMsg
    echo "错误：无法找到ai.vim文件"
    echo "搜索过的路径："
    for path in search_paths
      echo "  - " . path
    endfor
    echohl None
    return 1
  endif

  " 尝试读取配置文件
  let config_result = ReadAIConfig()

  if config_result.status == 1
    " 配置完整有效，自动设置所有参数
    echom "🔍 检测到配置文件 ~/.vim/ai-config.json"
    echom "✅ 已自动配置：api_key, base_url, model"
    call SetOpenAIKey(config_result.config.api_key)
    call SetOpenAIBaseUrl(config_result.config.base_url)
    call SetOpenAIModel(config_result.config.model)
  elseif config_result.status == 2
    " 配置部分缺失，设置已有参数，询问缺失参数
    echom "🔍 检测到配置文件 ~/.vim/ai-config.json"
    let configured_fields = []
    if has_key(config_result.config, 'api_key')
      call SetOpenAIKey(config_result.config.api_key)
      call add(configured_fields, 'api_key')
    endif
    if has_key(config_result.config, 'base_url')
      call SetOpenAIBaseUrl(config_result.config.base_url)
      call add(configured_fields, 'base_url')
    endif
    if has_key(config_result.config, 'model')
      call SetOpenAIModel(config_result.config.model)
      call add(configured_fields, 'model')
    endif
    echom "✅ 已读取：" . join(configured_fields, ', ')
    echom "❌ 缺少：" . join(config_result.missing, ', ')

    " 询问缺失的参数
    for field in config_result.missing
      if field == 'api_key'
        call SetOpenAIKey(input("ApiKey: "))
      elseif field == 'base_url'
        call SetOpenAIBaseUrl(input("BaseUrl："))
      elseif field == 'model'
        call SetOpenAIModel(input("Model："))
      endif
    endfor
  elseif config_result.status == 3 || config_result.status == 4
    " 配置文件格式错误或为空，显示错误信息并使用原逻辑
    echohl WarningMsg
    echo "⚠️ 配置文件问题：" . config_result.message
    echo "使用交互式配置模式..."
    echohl None
    call SetOpenAIKey(input("ApiKey: "))
    call SetOpenAIBaseUrl(input("BaseUrl："))
    call SetOpenAIModel(input("Model："))
  else
    " 配置文件不存在，使用原逻辑
    call SetOpenAIKey(input("ApiKey: "))
    call SetOpenAIBaseUrl(input("BaseUrl："))
    call SetOpenAIModel(input("Model："))
  endif

  call SetSystemPrompt(GetSystemPromptTemplate())
endfunction

function! Api(ApiType, ApiInfo)
  " 参数验证
  if empty(a:ApiType)
    return 1
  endif
  " 参数验证：只有ReadFile允许空参数，其他操作需要有效参数
  if a:ApiType !=? "ReadFile" && empty(a:ApiInfo)
    return 1
  endif
  let ApiTypeOk = ["MakeUserChoose", "AskUser", "WriteNewFile", "WriteFile", "ReadFile", "ExecuteShell", "MoveCursor"]
  let IfHaveApiType = "null"
  for ApiTypeOkSType in ApiTypeOk
    if a:ApiType ==? ApiTypeOkSType
      let IfHaveApiType = ApiTypeOkSType
    endif
  endfor
  if IfHaveApiType ==# "null"
    return 1
  endif
  if IfHaveApiType ==# "MakeUserChoose"
    let user_choice = confirm(a:ApiInfo, "&Yes\n&No")
    " 将confirm返回值转换为标准格式：1=是，2=否
    let answer = (user_choice == 1) ? "1" : "2"
  elseif IfHaveApiType ==# "AskUser"
    let answer = input(a:ApiInfo)
  elseif IfHaveApiType ==# "ExecuteShell"
    let answer = system(a:ApiInfo)
  elseif IfHaveApiType ==# "ReadFile"
    let file_path = expand('%:p')
      " 检查文件是否存在
    if !filereadable(file_path)
      return 2
    endif
    " 读取文件内容
    let file_content = readfile(file_path)
    let answer = join(file_content, "\n")
    return answer
  elseif IfHaveApiType ==# "WriteNewFile"
    %delete _
    " 将新内容分割成行并写入
    call setline(1, split(a:ApiInfo, '\n'))
    return 0
  elseif IfHaveApiType ==# "MoveCursor"
    " 解析参数字符串 "行号,列号"
    let pos_parts = split(a:ApiInfo, ',')
    if len(pos_parts) != 2
      return 1
    endif
    let line_num = str2nr(pos_parts[0])
    let col_num = str2nr(pos_parts[1])

    " 验证行号和列号
    if line_num < 1 || col_num < 1
        return 3
    endif
    " 获取文件总行数
    let total_lines = line('$')
    " 检查行号是否超出范围
    if line_num > total_lines
        return 3
    endif
    " 移动到指定位置
    call cursor(line_num, col_num)
    return 0
  elseif IfHaveApiType ==# "WriteFile"
    call append(line('.') - 1, split(a:ApiInfo, '\n'))
    return 0
  endif
  return answer
endfunction

" 获取系统提示模板 - 详细版本
function! GetSystemPromptTemplate()
  let template = "【系统身份】\n"
  let template .= "你是一名专业的Vim编辑器AI助手，运行在VimScript环境中。\n"
  let template .= "你的使命是通过VimScript提供的API功能，帮助用户高效地完成编辑任务。\n\n"

  let template .= "【核心能力】\n"
  let template .= "你可以通过JSON格式调用Vim编辑器的7个核心功能来帮助用户。\n"
  let template .= "每次调用都需要用户确认，确保操作安全。\n\n"

  let template .= "【可用API详细说明】\n\n"

  let template .= "1. MakeUserChoose - 显示确认对话框获取用户选择\n"
  let template .= "   用途: 需要用户确认的重要操作\n"
  let template .= "   参数格式: 确认消息文本（字符串）\n"
  let template .= "   成功返回: 1(用户选择'是') 或 2(用户选择'否')\n"
  let template .= "   失败返回: 错误码1\n"
  let template .= "   示例: {\"action\": \"MakeUserChoose\", \"parameters\": \"确定要删除当前行吗？\", \"reason\": \"删除操作需要用户确认\"}\n\n"

  let template .= "2. AskUser - 获取用户文本输入\n"
  let template .= "   用途: 需要用户输入信息或参数\n"
  let template .= "   参数格式: 输入提示文本（字符串）\n"
  let template .= "   成功返回: 用户输入的字符串\n"
  let template .= "   失败返回: 空字符串或错误码1\n"
  let template .= "   示例: {\"action\": \"AskUser\", \"parameters\": \"请输入新文件名:\", \"reason\": \"创建文件需要名称\"}\n\n"

  let template .= "3. ExecuteShell - 执行shell命令\n"
  let template .= "   用途: 执行系统命令和获取系统信息\n"
  let template .= "   参数格式: 完整shell命令字符串\n"
  let template .= "   成功返回: 命令输出结果字符串\n"
  let template .= "   失败返回: 空字符串或错误码1\n"
  let template .= "   警告: 谨慎使用，避免执行危险命令如rm、format等\n"
  let template .= "   示例: {\"action\": \"ExecuteShell\", \"parameters\": \"ls -la\", \"reason\": \"查看当前目录所有文件和详细信息\"}\n\n"

  let template .= "4. ReadFile - 读取当前文件全部内容\n"
  let template .= "   用途: 获取当前编辑文件的全部内容\n"
  let template .= "   参数格式: 空字符串 \"\"\n"
  let template .= "   成功返回: 文件内容字符串\n"
  let template .= "   失败返回: 错误码2(文件不存在或无法读取)\n"
  let template .= "   示例: {\"action\": \"ReadFile\", \"parameters\": \"\", \"reason\": \"需要查看当前文件内容\"}\n\n"

  let template .= "5. WriteNewFile - 覆盖写入新内容到当前文件\n"
  let template .= "   用途: 完全替换当前文件的整个内容\n"
  let template .= "   参数格式: 新文件内容字符串（可包含换行符）\n"
  let template .= "   成功返回: 0\n"
  let template .= "   失败返回: 错误码1\n"
  let template .= "   警告: 此操作会完全删除现有内容，请谨慎使用\n"
  let template .= "   示例: {\"action\": \"WriteNewFile\", \"parameters\": \"#!/bin/bash\\necho Hello World\", \"reason\": \"创建全新的shell脚本\"}\n\n"

  let template .= "6. WriteFile - 在当前光标位置插入内容\n"
  let template .= "   用途: 在当前光标位置插入新内容\n"
  let template .= "   参数格式: 要插入的内容字符串\n"
  let template .= "   成功返回: 0\n"
  let template .= "   失败返回: 错误码1\n"
  let template .= "   示例: {\"action\": \"WriteFile\", \"parameters\": \"// 新添加的注释行\", \"reason\": \"在文件中添加注释\"}\n\n"

  let template .= "7. MoveCursor - 移动光标到指定位置\n"
  let template .= "   用途: 定位光标到特定的行和列\n"
  let template .= "   参数格式: \"行号,列号\" 格式，如 \"10,5\" 表示第10行第5列\n"
  let template .= "   成功返回: 0\n"
  let template .= "   失败返回: 错误码3(位置超出文件范围)\n"
  let template .= "   示例: {\"action\": \"MoveCursor\", \"parameters\": \"1,1\", \"reason\": \"移动到文件开头\"}\n\n"

  let template .= "【响应模式说明 - 严格格式要求】\n"
  let template .= "⚠️  重要警告：你的回复必须是纯JSON或纯文本，严禁混合！\n\n"
  let template .= "模式1: 直接文本回复（默认）\n"
  let template .= "- 用途: 回答问题、提供建议、解释概念、拒绝危险操作\n"
  let template .= "- 格式: 直接输出自然语言文本，绝对不能包含任何JSON格式内容\n"
  let template .= "- 示例: 用户问\"什么是Vim？\"，你直接回答Vim的定义和特点\n"
  let template .= "- ❌ 错误示例: \"这是一个回答，顺便执行操作：{\\"action\\": \\"ReadFile\\"...}\"\n\n"
  let template .= "模式2: API调用（需要执行操作时使用）\n"
  let template .= "- 用途: 需要读取文件、执行命令、修改编辑器等操作\n"
  let template .= "- 格式: 严格按照JSON格式，包含action、parameters、reason三个字段，绝对不能包含任何额外文本\n"
  let template .= "- 触发条件: 用户明确要求执行某个具体操作\n"
  let template .= "- ❌ 错误示例: \"好的，我来帮你执行命令。{\\"action\\": \\"ExecuteShell\\"...}\"\n\n"
  let template .= "【如何选择响应模式】\n"
  let template .= "- 信息查询类: 优先直接回答，除非需要读取文件或执行命令获取信息\n"
  let template .= "- 操作执行类: 使用API调用模式，先请求用户确认\n"
  let template .= "- 危险操作: 直接拒绝并解释原因，不要使用API调用\n\n"
  let template .= "【格式违规处理】\n"
  let template .= "如果你违反格式要求，系统将直接报错并拒绝处理你的回复。\n"
  let template .= "格式违规包括：\n"
  let template .= "1. 文本回复中包含JSON格式内容\n"
  let template .= "2. JSON回复中包含额外的文本说明\n"
  let template .= "3. JSON格式不完整或包含多余字符\n\n"

  let template .= "【JSON响应格式规范】\n"
  let template .= "当需要执行操作时，你必须严格按照以下JSON格式响应，包含三个必需字段：\n"
  let template .= "{\n"
  let template .= "  \"action\": \"API名称\",  // 必须是上述7个API之一\n"
  let template .= "  \"parameters\": \"参数字符串\",  // 必须符合对应API的参数格式\n"
  let template .= "  \"reason\": \"执行原因说明\"  // 详细解释为什么要执行这个操作\n"
  let template .= "}\n\n"

  let template .= "【行为准则】\n"
  let template .= "1. 安全第一: 绝不执行可能损坏数据或系统的危险操作\n"
  let template .= "2. 用户确认: 所有API调用都必须先请求用户明确确认\n"
  let template .= "3. 解释清楚: 详细说明每个操作的目的和预期结果\n"
  let template .= "4. 错误处理: 预见可能的错误并提供解决方案\n"
  let template .= "5. 简洁高效: 避免不必要的复杂操作，直接解决问题\n"
  let template .= "6. 尊重用户: 如果用户拒绝操作，不要重复请求\n"
  let template .= "7. 专业态度: 保持专业、友好、耐心的服务态度\n\n"

  let template .= "【响应模式对比示例】\n\n"
  let template .= "示例1 - 直接文本回复（不需要执行操作）：\n"
  let template .= "用户: \"什么是Vim？\"\n"
  let template .= "你: Vim是一个高度可配置的文本编辑器，被广泛用于程序开发。它具有强大的文本处理能力和丰富的插件生态系统。\n\n"
  let template .= "用户: \"请解释一下这段代码的作用\"\n"
  let template .= "你: 这段代码定义了一个函数，用于计算斐波那契数列。它使用递归算法，时间复杂度为O(2^n)。\n\n"

  let template .= "示例2 - API调用（需要执行操作获取信息）：\n"
  let template .= "用户: \"请显示当前目录的文件\"\n"
  let template .= "你: {\"action\": \"ExecuteShell\", \"parameters\": \"ls -la\", \"reason\": \"显示当前目录所有文件和详细信息，帮助用户了解目录结构\"}\n\n"

  let template .= "用户: \"请读取当前文件内容\"\n"
  let template .= "你: {\"action\": \"ReadFile\", \"parameters\": \"\", \"reason\": \"获取当前编辑文件的全部内容，以便分析或修改\"}\n\n"

  let template .= "用户: \"在文件末尾添加一行注释\"\n"
  let template .= "你: {\"action\": \"WriteFile\", \"parameters\": \"// 用户添加的注释行\", \"reason\": \"在文件末尾添加新行注释，保持代码文档完整性\"}\n\n"

  let template .= "【失败响应示例】\n"
  let template .= "用户: \"删除所有文件\"\n"
  let template .= "你: 我不能执行这个操作，因为这可能会删除重要文件且没有指定具体文件。如果你需要删除特定文件，请告诉我具体的文件名，我会帮你安全地删除。\n\n"

  let template .= "用户: \"执行rm -rf /\"\n"
  let template .= "你: 我不能执行这个极其危险的命令，因为它会删除系统上的所有文件。这是一个系统破坏命令，请提供安全的替代方案或具体说明你想实现什么目标。\n\n"

  let template .= "用户: \"格式化硬盘\"\n"
  let template .= "你: 我不能执行这个操作，因为格式化硬盘会删除所有数据且无法恢复。如果你需要清理磁盘空间或管理文件，我可以帮你使用安全的替代方法。\n\n"

  let template .= "【错误码详细说明】\n"
  let template .= "1: 参数错误或API类型无效 - 检查输入参数格式是否正确\n"
  let template .= "2: 文件读取错误 - 文件不存在、无权限或文件损坏\n"
  let template .= "3: 位置错误 - 行号或列号超出文件实际范围\n"
  let template .= "4: 解析错误 - 无法解析API响应或数据格式错误\n"
  let template .= "5: 格式违规 - AI回复同时包含JSON和文本内容，违反格式要求\n\n"

  let template .= "【安全警告】\n"
  let template .= "⚠️  禁止执行的操作：\n"
  let template .= "- rm, del, format 等删除/格式化命令\n"
  let template .= "- sudo 提权命令\n"
  let template .= "- 系统关键文件修改\n"
  let template .= "- 网络扫描或攻击命令\n"
  let template .= "- 任何可能危害系统安全的操作\n\n"

  let template .= "【重要提醒】\n"
  let template .= "- 你只能使用上述列出的7个API功能，不能执行其他操作\n"
  let template .= "- 参数字符串必须严格符合各API的格式要求\n"
  let template .= "- 如果用户请求超出这些功能范围，礼貌拒绝并解释原因\n"
  let template .= "- 始终以帮助用户提高效率为首要目标\n"
  let template .= "- 记住你是在Vim编辑器环境中工作，不是通用操作系统\n"
  let template .= "- 保持专业、友好、耐心的服务态度\n"
  let template .= "- 对于复杂任务，可以分步骤执行，每步都请求确认\n"

  return template
endfunction

" 缓存JSON支持状态，避免重复检查
let s:has_json_support = -1  " -1表示未初始化

" 检查Vim是否支持json_decode函数（带缓存）
function! CheckJsonSupport()
  if s:has_json_support == -1
    let s:has_json_support = exists('*json_decode')
  endif
  return s:has_json_support
endfunction

" 安全地解析JSON字符串（增强版）
function! SafeJsonDecode(json_string)
  try
    let parsed = json_decode(a:json_string)
    return {'success': 1, 'data': parsed}
  catch /E474:/
    " JSON格式错误
    return {'success': 0, 'error': 'Invalid JSON format: ' . v:exception}
  catch
    " 其他解析错误
    return {'success': 0, 'error': 'JSON parsing error: ' . v:exception}
  endtry
endfunction

" 获取错误码对应的错误消息
function! GetErrorMessage(error_code)
  if a:error_code == 1
    return "❌ 错误：API密钥未设置或参数无效。请先调用SetOpenAIKey()设置API密钥。"
  elseif a:error_code == 2
    return "❌ 错误：网络连接失败或curl命令执行错误。请检查网络连接。"
  elseif a:error_code == 3
    return "❌ 错误：OpenAI API返回错误。可能是API密钥无效或请求格式错误。"
  elseif a:error_code == 4
    return "❌ 错误：无法解析AI响应。响应格式可能不正确。"
  elseif a:error_code == 5
    return "❌ 错误：AI回复格式违规 - 不能同时包含JSON和文本内容。"
  else
    return "❌ 错误：未知错误（错误码：" . a:error_code . "）"
  endif
endfunction

" 使用正则表达式解析JSON（降级方案）
function! ParseWithRegex(response)
  " 简化的JSON解析 - 查找action字段
  let action_match = matchstr(a:response, '"action"\s*:\s*"\([^"]*\)"')

  if empty(action_match)
    " 不是JSON格式，直接返回原响应给用户
    return {'is_json': 0, 'response': a:response}
  endif

  " 提取各个字段（简化处理）
  let action = substitute(action_match, '"action"\s*:\s*"\([^"]*\)"', '\1', '')

  let parameters_match = matchstr(a:response, '"parameters"\s*:\s*"\([^"]*\)"')
  let parameters = empty(parameters_match) ? "" : substitute(parameters_match, '"parameters"\s*:\s*"\([^"]*\)"', '\1', '')

  let reason_match = matchstr(a:response, '"reason"\s*:\s*"\([^"]*\)"')
  let reason = empty(reason_match) ? "" : substitute(reason_match, '"reason"\s*:\s*"\([^"]*\)"', '\1', '')

  " 处理转义字符
  let parameters = substitute(parameters, '\\n', "\n", 'g')
  let parameters = substitute(parameters, '\\"', '"', 'g')
  let reason = substitute(reason, '\\n', "\n", 'g')
  let reason = substitute(reason, '\\"', '"', 'g')

  return {'is_json': 1, 'action': action, 'parameters': parameters, 'reason': reason}
endfunction

" 解析AI响应（主函数）
function! ParseAIResponse(response)
  if !CheckJsonSupport()
    " 使用正则表达式降级方案
    if !exists('s:warned_regex')
      echom "⚠️ 警告：当前Vim版本不支持json_decode，使用正则表达式解析JSON"
      let s:warned_regex = 1
    endif
    return ParseWithRegex(a:response)
  endif

  " 使用json_decode解析
  let result = SafeJsonDecode(a:response)
  if !result.success
    " JSON解析失败，返回原响应
    return {'is_json': 0, 'response': a:response}
  endif

  let parsed = result.data
  if type(parsed) != type({}) || !has_key(parsed, 'action') || !has_key(parsed, 'parameters') || !has_key(parsed, 'reason')
    " 缺少必需字段，返回原响应
    return {'is_json': 0, 'response': a:response}
  endif

  return {'is_json': 1, 'action': parsed.action, 'parameters': parsed.parameters, 'reason': parsed.reason}
endfunction

" 解析AI响应并处理API调用
function! ParseAndExecuteAIResponse(response)
  " 新增：检测混合内容格式违规（简化版逻辑）
  " 使用更简洁的检测方法
  let trimmed_response = substitute(a:response, '^\s*', '', '')
  let trimmed_response = substitute(trimmed_response, '\s*$', '', '')

  " 检测是否为纯JSON格式（以{开头，以}结尾，包含必需的JSON字段）
  let is_pure_json = trimmed_response =~# '^\s*\{\s*"action"' && trimmed_response =~# '}\s*$'

  " 检测是否包含JSON字段但格式不纯
  let has_json_fields = a:response =~# '"action"' || a:response =~# '"parameters"' || a:response =~# '"reason"'

  " 如果发现格式违规：有JSON字段但不是纯JSON格式
  if has_json_fields && !is_pure_json
    echohl ErrorMsg
    echo "❌ 格式违规错误：AI回复不能同时包含JSON和文本内容"
    echo "违规内容: " . a:response[0:min([100, len(a:response)-1])] . "..."
    echohl None
    return GetErrorMessage(5)
  endif

  let parse_result = ParseAIResponse(a:response)

  if !parse_result.is_json
    " 不是有效的JSON格式，直接返回原响应
    return parse_result.response
  endif

  let action = parse_result.action
  let parameters = parse_result.parameters
  let reason = parse_result.reason

  " 验证action是否有效
  let valid_actions = {"MakeUserChoose": 1, "AskUser": 1, "WriteNewFile": 1, "WriteFile": 1, "ReadFile": 1, "ExecuteShell": 1, "MoveCursor": 1}
  if !has_key(valid_actions, action)
    return "错误：未知的API操作 '" . action . "'。可用的操作有：MakeUserChoose, AskUser, WriteNewFile, WriteFile, ReadFile, ExecuteShell, MoveCursor"
  endif

  " 根据操作类型显示不同的确认信息
  let confirm_msg = "🔍 AI助手请求执行操作\n"
  let confirm_msg .= "━━━━━━━━━━━━━━━━━━━━━\n"
  let confirm_msg .= "操作类型: " . action . "\n"

  if action ==? "ExecuteShell"
    let confirm_msg .= "⚠️  命令: " . parameters . "\n"
    let confirm_msg .= "⚠️  警告: 此操作将执行系统命令\n"
  elseif action ==? "WriteNewFile"
    let confirm_msg .= "📝 将覆盖当前文件内容\n"
    let confirm_msg .= "📄 新内容长度: " . len(parameters) . " 字符\n"
  elseif action ==? "WriteFile"
    let confirm_msg .= "📝 插入内容: " . parameters[0:min([50, len(parameters)-1])] . "...\n"
  elseif action ==? "ReadFile"
    let confirm_msg .= "📖 读取当前文件内容\n"
  elseif action ==? "MoveCursor"
    let confirm_msg .= "📍 移动光标到: " . parameters . "\n"
  elseif action ==? "AskUser"
    let confirm_msg .= "💬 提问: " . parameters . "\n"
  elseif action ==? "MakeUserChoose"
    let confirm_msg .= "🤔 选择: " . parameters . "\n"
  endif

  let confirm_msg .= "💡 原因: " . reason . "\n"
  let confirm_msg .= "━━━━━━━━━━━━━━━━━━━━━\n"
  let confirm_msg .= "是否允许AI执行此操作？"

  let user_choice = confirm(confirm_msg, "&Yes\n&No")

  if user_choice != 1 " 用户选择拒绝
    return SendExecutionResultToAI(action, parameters, reason, 0, "用户拒绝了操作请求")
  endif

  " 用户确认，执行API调用
  let result = Api(action, parameters)

  " 处理API返回结果 - 用字符串特征判断，避开VimScript类型系统bug
  " 成功结果：包含文件内容、命令输出等实际数据
  " 错误特征：纯数字1-4，长度=1，内容为单个数字
  let result_str = string(result)
  let is_error_code = 0

  " 检查是否是错误码1-4（纯数字，长度=1，内容匹配）
  if result_str == "1" || result_str == "2" || result_str == "3" || result_str == "4"
    if len(result_str) == 1
      let is_error_code = 1
    endif
  endif

  if is_error_code
    " 数值错误码
    if result == 1
      return SendExecutionResultToAI(action, parameters, reason, 0, "执行失败：参数错误或API类型无效")
    elseif result == 2
      return SendExecutionResultToAI(action, parameters, reason, 0, "执行失败：文件不存在或无法读取")
    elseif result == 3
      return SendExecutionResultToAI(action, parameters, reason, 0, "执行失败：光标位置超出文件范围")
    elseif result == 4
      return SendExecutionResultToAI(action, parameters, reason, 0, "执行失败：无法解析响应")
    endif
  else
    " 字符串内容，操作成功
    if action ==? "ExecuteShell" || action ==? "ReadFile" || action ==? "AskUser"
      return SendExecutionResultToAI(action, parameters, reason, 1, result)
    else
      return SendExecutionResultToAI(action, parameters, reason, 1, "操作执行成功：" . action)
    endif
  endif
endfunction

" 将执行结果发送给AI进行后续处理
function! SendExecutionResultToAI(action, parameters, reason, success, result_details)
  " 构建执行结果消息
  if a:success
    let result_message = "✅ 操作执行成功\n"
    let result_message .= "操作类型: " . a:action . "\n"
    let result_message .= "执行原因: " . a:reason . "\n"
    if a:action ==? "ReadFile" || a:action ==? "ExecuteShell" || a:action ==? "AskUser"
      let result_message .= "执行结果:\n" . a:result_details
    else
      let result_message .= "执行结果: " . a:result_details
    endif
  else
    let result_message = "❌ 操作执行失败\n"
    let result_message .= "操作类型: " . a:action . "\n"
    let result_message .= "执行原因: " . a:reason . "\n"
    let result_message .= "失败原因: " . a:result_details
  endif

  " 将执行结果添加到对话历史中，让AI了解发生了什么
  if exists('*AddSystemMessage')
    call AddSystemMessage(result_message)
  endif

  " 让AI基于执行结果生成回复给用户
  let ai_response = SendToOpenAI("基于上述操作结果，请为用户提供帮助或回答他们的问题")

  return ai_response
endfunction

" 测试JSON解析函数
function! TestJSONParsing()
  " 显示JSON支持状态
  let json_support = CheckJsonSupport()
  echom "JSON支持状态: " . (json_support ? "✅ 支持" : "❌ 不支持")
  echom "==========================="

  " 测试用例1：正确的JSON格式
  let test_json1 = '{"action": "ReadFile", "parameters": "", "reason": "获取当前编辑文件的全部内容，以便查看和分析文件主要内容"}'
  let result1 = ParseAndExecuteAIResponse(test_json1)
  echom "测试1输入: " . test_json1
  echom "测试1结果: " . result1
  echom "---"

  " 测试用例2：非JSON格式
  let test_json2 = "普通文本回复"
  let result2 = ParseAndExecuteAIResponse(test_json2)
  echom "测试2输入: " . test_json2
  echom "测试2结果: " . result2
  echom "---"

  " 测试用例3：提取字段值
  let test_json3 = '{"action": "ExecuteShell", "parameters": "ls -la", "reason": "查看文件"}'
  let result3 = ParseAndExecuteAIResponse(test_json3)
  echom "测试3输入: " . test_json3
  echom "测试3结果: " . result3
  echom "---"

  " 测试用例4：缺少必需字段
  let test_json4 = '{"action": "ReadFile", "reason": "缺少parameters字段"}'
  let result4 = ParseAndExecuteAIResponse(test_json4)
  echom "测试4输入: " . test_json4
  echom "测试4结果: " . result4
  echom "---"

  " 测试用例5：无效的JSON格式
  let test_json5 = '{"action": "ReadFile", "parameters": "", "reason": "无效JSON"'
  let result5 = ParseAndExecuteAIResponse(test_json5)
  echom "测试5输入: " . test_json5
  echom "测试5结果: " . result5
  echom "---"

  " 测试用例6：包含转义字符的JSON
  let test_json6 = '{"action": "WriteFile", "parameters": "// 新添加的注释行\\n// 第二行注释", "reason": "添加多行注释"}'
  let result6 = ParseAndExecuteAIResponse(test_json6)
  echom "测试6输入: " . test_json6
  echom "测试6结果: " . result6
  echom "---"

  " 测试用例7：格式违规 - 文本中包含JSON
  let test_json7 = "好的，我来帮你执行命令。{\"action\": \"ExecuteShell\", \"parameters\": \"ls -la\", \"reason\": \"显示文件列表\"}"
  let result7 = ParseAndExecuteAIResponse(test_json7)
  echom "测试7输入: " . test_json7
  echom "测试7结果: " . result7
  echom "---"

  " 测试用例8：格式违规 - JSON前后有额外文本
  let test_json8 = "我来帮你读取文件。{\"action\": \"ReadFile\", \"parameters\": \"\", \"reason\": \"获取文件内容\"} 执行完毕。"
  let result8 = ParseAndExecuteAIResponse(test_json8)
  echom "测试8输入: " . test_json8
  echom "测试8结果: " . result8
  echom "---"

  " 测试用例9：格式违规 - JSON中间有文本
  let test_json9 = '{"action": "ReadFile"} 这是一个违规的混合回复 {"parameters": "", "reason": "获取文件内容"}'
  let result9 = ParseAndExecuteAIResponse(test_json9)
  echom "测试9输入: " . test_json9
  echom "测试9结果: " . result9
endfunction

" 显示详细的系统信息
function! ShowDetailedVersionInfo()
  echom "=== Vim AI助手系统信息 ==="
  echom "Vim版本: " . v:version . "." . v:patchlevel
  echom "JSON支持: " . (CheckJsonSupport() ? "✅ 支持" : "❌ 不支持")
  if CheckJsonSupport()
    echom "JSON解析方式: 内置json_decode"
  else
    echom "JSON解析方式: 正则表达式（兼容模式）"
  endif
  echom "API功能数量: 7个"
  echom "最后更新: JSON解析重构完成"
  echom "========================"
endfunction

" 显示系统信息（简版）
function! ShowSystemInfo()
  echom "=== Vim AI助手系统信息 ==="
  echom "Vim版本: " . v:version
  echom "JSON支持: " . (CheckJsonSupport() ? "✅ 支持" : "❌ 不支持")
  echom "========================"
endfunction