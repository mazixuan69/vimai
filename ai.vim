" 全局变量存储对话历史
let s:openai_messages = []
let s:openai_api_key = ''
let s:openai_model = 'gpt-3.5-turbo'
let s:openai_api_url = 'https://api.openai.com/v1/chat/completions'
let s:system_prompt = ''

" 设置 OpenAI API 密钥
function! SetOpenAIKey(api_key)
  let s:openai_api_key = a:api_key
  return 0
endfunction

" 设置 OpenAI API 密钥
function! SetOpenAIBaseUrl(base_url)
  let s:openai_api_url = a:base_url
    return 0
    endfunction

" 设置 OpenAI 模型
function! SetOpenAIModel(model)
  let s:openai_model = a:model
  return 0
endfunction

" 设置系统提示
function! SetSystemPrompt(prompt)
  let s:system_prompt = a:prompt
  return 0
endfunction

" 获取系统提示
function! GetSystemPrompt()
  return s:system_prompt
endfunction

" 清空对话历史
function! ClearChatHistory()
  let s:openai_messages = []
  return 0
endfunction

" 发送消息到 OpenAI API
function! SendToOpenAI(message)
  " 检查 API 密钥是否设置
  if empty(s:openai_api_key)
    return 1
  endif

  " 清空当前对话历史，准备重新构建
  let temp_messages = []

  " 如果有系统提示，首先添加系统消息
  if !empty(s:system_prompt)
    call add(temp_messages, {'role': 'system', 'content': s:system_prompt})
  endif

  " 添加历史消息（不包括之前的系统消息，但保留执行结果）
  for msg in s:openai_messages
    if msg.role != 'system' || (msg.role == 'system' && msg.content =~ '✅ 操作执行成功' || msg.content =~ '❌ 操作执行失败')
      " 保留普通消息和执行结果系统消息，排除纯系统提示
      call add(temp_messages, msg)
    endif
  endfor

  " 添加用户消息到历史
  call add(s:openai_messages, {'role': 'user', 'content': a:message})
  call add(temp_messages, {'role': 'user', 'content': a:message})

  " 构建 API 请求数据
  let request_data = {
        \ 'model': s:openai_model,
        \ 'messages': temp_messages,
        \ 'max_tokens': 1000,
        \ 'temperature': 0.7
        \ }

  " 使用json_decode构建请求（如果可用）
  if exists('*json_encode')
    try
      let json_data = json_encode(request_data)
    catch
      " json_encode失败，回退到手动构建
      let json_data = ""
    endtry
  endif

  " 如果json_encode不可用或失败，手动构建JSON
  if empty(json_data)
    " 手动构建标准JSON格式
    let json_data = "{"
    let json_data .= '"model":"' . s:openai_model . '",'
    let json_data .= '"messages":['

    " 构建messages数组
    for i in range(len(temp_messages))
      if i > 0
        let json_data .= ","
      endif
      let json_data .= '{'
      let json_data .= '"role":"' . temp_messages[i].role . '",'
      let content_escaped = substitute(temp_messages[i].content, '"', '\\"', 'g')
      let content_escaped = substitute(content_escaped, "\n", '\\n', 'g')
      let json_data .= '"content":"' . content_escaped . '"'
      let json_data .= '}'
    endfor

    let json_data .= '],'
    let json_data .= '"max_tokens":1000,'
    let json_data .= '"temperature":0.7'
    let json_data .= "}"
  endif

  " 将JSON数据写入临时文件
  let temp_file = tempname()
  call writefile([json_data], temp_file)

  " 构建 curl 命令 - 使用文件发送JSON数据
  let curl_cmd = 'curl -s -X POST ' .
        \ '"' . s:openai_api_url . '"' .
        \ ' -H "Content-Type: application/json"' .
        \ ' -H "Authorization: Bearer ' . s:openai_api_key . '"' .
        \ ' -d @' . temp_file

  " 调试输出（可选） - 默认关闭
  if get(g:, 'debug_openai', 0)
    echo "请求数据: " . json_data
    echo "curl命令: " . curl_cmd
  endif

  " 执行 curl 命令并获取响应
  let response = system(curl_cmd)

  " 清理临时文件
  call delete(temp_file)

  " 检查是否出错
  if v:shell_error != 0
    if get(g:, 'debug_openai', 0)
      echo "curl执行错误，返回码: " . v:shell_error
      echo "curl输出: " . response
    endif
    return 2
  endif

  " 调试输出原始响应
  if get(g:, 'debug_openai', 0)
    echo "原始响应: " . response
  endif

  " 解析 JSON 响应 - 使用json_decode（如果可用）或改进的正则表达式
  if exists('*json_decode')
    " 使用json_decode解析（推荐方法）
    try
      let parsed_response = json_decode(response)

      " 检查是否有错误信息
      if has_key(parsed_response, 'error')
        let error_msg = get(parsed_response.error, 'message', 'Unknown API error')
        return 3  " API错误码
      endif

      " 提取choices数组中的内容
      if has_key(parsed_response, 'choices') && len(parsed_response.choices) > 0
        let first_choice = parsed_response.choices[0]
        if has_key(first_choice, 'message') && has_key(first_choice.message, 'content')
          let assistant_message = first_choice.message.content

          " 添加到对话历史
          call add(s:openai_messages, {'role': 'assistant', 'content': assistant_message})

          return assistant_message
        endif
      endif

      " 如果无法找到有效内容，返回错误
      return "❌ 无法从响应中提取有效内容"

    catch
      " json_decode失败，降级到正则表达式方法
      echo "⚠️ json_decode解析失败，使用降级方案: " . v:exception
    endtry
  endif

  " 降级方案：使用改进的正则表达式解析
  " 首先尝试查找choices数组中的content
  let choices_pattern = '"choices":\s*\[\s*{[^}]*"message":\s*{[^}]*"content":\s*"\(.*?\)"[^}]*}[^}]*}'
  let choice_block = matchstr(response, choices_pattern)

  if !empty(choice_block)
    " 在choice块中提取content
    let content_match = matchstr(choice_block, '"content":\s*"\(.*?\)"')
    if !empty(content_match)
      " 提取实际内容（保留转义字符，稍后处理）
      let assistant_message = substitute(content_match, '"content":\s*"', '', '')
      let assistant_message = substitute(assistant_message, '"$', '', '')

      " 处理转义字符
      let assistant_message = substitute(assistant_message, '\\n', "\n", 'g')
      let assistant_message = substitute(assistant_message, '\\"', '"', 'g')
      let assistant_message = substitute(assistant_message, '\\t', "\t", 'g')

      " 添加到对话历史
      call add(s:openai_messages, {'role': 'assistant', 'content': assistant_message})

      return assistant_message
    endif
  endif

  " 尝试查找错误信息
  let error_match = matchstr(response, '"error":\s*{[^}]*"message":\s*"\(.*?\)"')
  if !empty(error_match)
    let error_msg = substitute(error_match, '"error":\s*{[^}]*"message":\s*"', '', '')
    let error_msg = substitute(error_msg, '".*', '', '')
    return 3  " API错误码
  endif

  " 检查其他错误格式
  let error_message = matchstr(response, '"message":\s*"\(.*?\)"')
  if !empty(error_message)
    let error_msg = substitute(error_message, '"message":\s*"', '', '')
    let error_msg = substitute(error_msg, '".*', '', '')
    return 3  " API错误码
  endif

  " 完全无法解析响应
  return "❌ 无法解析AI响应"
endfunction

" 测试API连接的函数
function! TestAPIConnection()
  " 检查API密钥
  if empty(s:openai_api_key)
    echo "API密钥未设置"
    return 0
  endif

  " 构建简单的测试请求
  let test_data = '{"model":"' . s:openai_model . '","messages":[{"role":"user","content":"Hello"}],"max_tokens":10}'

  " 将数据写入临时文件
  let temp_file = tempname()
  call writefile([test_data], temp_file)

  " 构建curl命令
  let curl_cmd = 'curl -s -X POST ' .
        \ '"' . s:openai_api_url . '"' .
        \ ' -H "Content-Type: application/json"' .
        \ ' -H "Authorization: Bearer ' . s:openai_api_key . '"' .
        \ ' -d @' . temp_file

  echo "测试请求: " . test_data
  echo "测试命令: " . curl_cmd

  " 执行测试
  let response = system(curl_cmd)
  call delete(temp_file)

  echo "测试响应: " . response[0:min([200, len(response)-1])]

  if v:shell_error != 0
    echo "curl错误码: " . v:shell_error
    return 0
  endif

  return 1
endfunction

" 测试函数：验证echom是否正确工作
function! TestEchom()
  echom "测试：这是通过echom显示的消息"
  echom "测试：ChatWithOpenAI现在应该能正常显示结果了"
endfunction

" 调试函数：显示当前API配置
function! ShowAPIConfig()
  echo "API URL: " . s:openai_api_url
  echo "API Key: " . (empty(s:openai_api_key) ? "未设置" : s:openai_api_key[0:8] . "...")
  echo "Model: " . s:openai_model
  echo "系统提示: " . (empty(s:system_prompt) ? "未设置" : s:system_prompt[0:50] . "...")
endfunction

" 连续对话主函数 - 使用echom显示给用户
function! ChatWithOpenAI(user_input)
  " 检查 API 密钥
  if empty(s:openai_api_key)
    echom "错误：API密钥未设置"
    return
  endif

  let response = SendToOpenAI(a:user_input)

  " 如果响应是错误码，显示错误消息
  if response == 1 || response == 2 || response == 3 || response == 4
    echom GetErrorMessage(response)
    return
  endif

  " 解析并执行AI响应（可能包含API调用）
  if exists('*ParseAndExecuteAIResponse')
    let result = ParseAndExecuteAIResponse(response)
    echom result
  else
    echom response
  endif
endfunction

" 添加系统消息到对话历史
function! AddSystemMessage(content)
  call add(s:openai_messages, {"role": "system", "content": a:content})
endfunction
