/*
    Real-time subtitle translation for PotPlayer using OpenAI ChatGPT API
*/

// 插件信息函数
string GetTitle() {
    return "{$CP949=OpenAI 번역$}{$CP950=OpenAI 翻譯$}{$CP0=OpenAI Translate$}";
}

string GetVersion() {
    return "2.0"; // 插件版本
}

string GetDesc() {
    return "{$CP949=OpenAI ChatGPT를 사용한 실시간 자막 번역$}{$CP950=使用 OpenAI ChatGPT 的實時字幕翻譯$}{$CP0=Real-time subtitle translation using OpenAI ChatGPT$}";
}

string GetLoginTitle() {
    return "{$CP949=OpenAI 모델 및 API 키 구성$}{$CP950=OpenAI 模型與 API 金鑰配置$}{$CP0=OpenAI Model and API Key Configuration$}";
}

string GetLoginDesc() {
    return "{$CP949=모델 이름을 입력하고 API 키를 입력하십시오 (예: gpt-4o-mini).$}{$CP950=請輸入模型名稱並提供 API 金鑰（例如 gpt-4o-mini）。$}{$CP0=Please enter the model name and provide the API Key (e.g., gpt-4o-mini).$}";
}

string GetUserText() {
    return "{$CP949=모델 이름 (현재: " + selected_model + ")$}{$CP950=模型名稱 (目前: " + selected_model + ")$}{$CP0=Model Name (Current: " + selected_model + ")$}";
}

string GetPasswordText() {
    return "{$CP949=API 키:$}{$CP950=API 金鑰:$}{$CP0=API Key:$}";
}

// Global Variables
string api_key = "";
string selected_model = "gpt-4o-mini"; // Default model
string UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)";
string apiUrl = "https://api.openai.com/v1/chat/completions"; // Added apiUrl definition

// 支持的语言列表
array<string> LangTable = {
    "{$CP0=Auto Detect$}", "af", "sq", "am", "ar", "hy", "az", "eu", "be", "bn", "bs", "bg", "ca",
    "ceb", "ny", "zh-CN", "zh-TW", "co", "hr", "cs", "da", "nl", "en", "eo", "et", "tl", "fi", "fr",
    "fy", "gl", "ka", "de", "el", "gu", "ht", "ha", "haw", "he", "hi", "hmn", "hu", "is", "ig", "id", "ga", "it", "ja", "jw", "kn", "kk", "km",
    "ko", "ku", "ky", "lo", "la", "lv", "lt", "lb", "mk", "ms", "mg", "ml", "mt", "mi", "mr", "mn", "my", "ne", "no", "ps", "fa", "pl", "pt",
    "pa", "ro", "ru", "sm", "gd", "sr", "st", "sn", "sd", "si", "sk", "sl", "so", "es", "su", "sw", "sv", "tg", "ta", "te", "th", "tr", "uk",
    "ur", "uz", "vi", "cy", "xh", "yi", "yo", "zu"
};

// 获取源语言列表
array<string> GetSrcLangs() {
    array<string> ret = LangTable;
    return ret;
}

// 获取目标语言列表
array<string> GetDstLangs() {
    array<string> ret = LangTable;
    return ret;
}

// 登录接口：输入模型名称和 API 密钥
string ServerLogin(string User, string Pass) {
    // 去除空白字符
    selected_model = User.Trim();
    api_key = Pass.Trim();

    // 验证模型名称
    if (selected_model.empty()) {
        HostPrintUTF8("{$CP0=未输入模型名称。请输入有效的模型名称。$}\n");
        selected_model = "gpt-4o-mini"; // 默认模型
    }

    // 验证 API 密钥
    if (api_key.empty()) {
        HostPrintUTF8("{$CP0=未配置 API 密钥。请输入有效的 API 密钥。$}\n");
        return "fail";
    }

    // 保存设置到临时存储
    HostSaveString("api_key", api_key);
    HostSaveString("selected_model", selected_model);

    HostPrintUTF8("{$CP0=API 密钥和模型名称已成功配置。$}\n");
    return "200 ok";
}

// 登出接口：清除模型名称和 API 密钥
void ServerLogout() {
    api_key = "";
    selected_model = "gpt-4o-mini";
    HostSaveString("api_key", "");
    HostSaveString("selected_model", selected_model);
    HostPrintUTF8("{$CP0=已成功登出。$}\n");
}

// JSON 转义函数
string JsonEscape(const string &in input) {
    string output = input;
    output.replace("\\", "\\\\"); // 转义反斜杠
    output.replace("\"", "\\\""); // 转义双引号
    output.replace("\n", "\\n");  // 转义换行符
    output.replace("\r", "\\r");  // 转义回车符
    output.replace("\t", "\\t");  // 转义制表符
    return output;
}

// 全局变量：右到左语言的标记
string UNICODE_RLE = "\u202B";

// 估算 Token 数量的函数
int EstimateTokenCount(const string &in text) {
    // 粗略估算：平均 4 个字符对应 1 个 Token
    return int(float(text.length()) / 4);
}

// 获取模型最大上下文 Token 的函数
int GetModelMaxTokens(const string &in modelName) {
    // 定义已知模型的最大 Token 限制
    if (modelName == "gpt-3.5-turbo") {
        return 4096;
    } else if (modelName == "gpt-3.5-turbo-16k") {
        return 16384;
    } else if (modelName == "gpt-4o") {
        return 128000;
    } else if (modelName == "gpt-4o-mini") {
        return 128000;
    } else if (modelName == "Qwen/Qwen2.5-7B-Instruct") {
        return 128000; // Qwen 的上下文 Token 限制
    } else {
        // 默认保守限制
        return 4096;
    }
}

// 翻译函数
string Translate(string Text, string &in SrcLang, string &in DstLang) {
    // 从临时存储中加载 API 密钥和模型名称
    api_key = HostLoadString("api_key", "");
    selected_model = HostLoadString("selected_model", "gpt-4o-mini");

    if (api_key.empty()) {
        HostPrintUTF8("{$CP0=未配置 API 密钥。请在设置菜单中输入。$}\n");
        return "";
    }

    if (DstLang.empty() || DstLang == "{$CP0=Auto Detect$}") {
        HostPrintUTF8("{$CP0=未指定目标语言。请选择目标语言。$}\n");
        return "";
    }

    if (SrcLang.empty() || SrcLang == "{$CP0=Auto Detect$}") {
        SrcLang = "";
    }

    // 获取模型的最大 Token 限制
    int maxTokens = GetModelMaxTokens(selected_model);

    // 估算当前字幕的 Token 数量
    int tokenCount = EstimateTokenCount(Text);

    // 检查是否超出上下文 Token 限制
    if (tokenCount > maxTokens) {
        HostPrintUTF8("{$CP0=输入文本超出模型最大上下文 Token 限制。请缩短输入内容。$}\n");
        return "";
    }

    // 构造提示（Prompt）
    string prompt = "You are a professional translator. Please translate the following subtitle, output only translated results. If content that violates the Terms of Service appears, just output the translation result that complies with safety standards.";
    if (!SrcLang.empty()) {
        prompt += " from " + SrcLang;
    }
    prompt += " to " + DstLang + ".\n";

    // 指示模型使用之前的翻译上下文
    prompt += "Use the context from previous translations to maintain coherence.\n";

    // 添加待翻译的字幕
    prompt += "Subtitle to translate:\n" + Text;

    // JSON 转义
    string escapedPrompt = JsonEscape(prompt);

    // 构建请求数据
    string requestData = "{\"model\":\"" + selected_model + "\",\"messages\":[{\"role\":\"user\",\"content\":\"" + escapedPrompt + "\"}],\"max_tokens\":4096,\"temperature\":0}";

    string headers = "Authorization: Bearer " + api_key + "\nContent-Type: application/json";

    // 发送请求
    string response = HostUrlGetString(apiUrl, UserAgent, headers, requestData);
    if (response.empty()) {
        HostPrintUTF8("{$CP0=翻译请求失败。请检查网络连接或 API 密钥。$}\n");
        return "";
    }

    // 解析响应
    JsonReader Reader;
    JsonValue Root;
    if (!Reader.parse(response, Root)) {
        HostPrintUTF8("{$CP0=解析 API 响应失败。$}\n");
        return "";
    }

    JsonValue choices = Root["choices"];
    if (choices.isArray() && choices[0]["message"]["content"].isString()) {
        string translatedText = choices[0]["message"]["content"].asString();
        if (DstLang == "fa" || DstLang == "ar" || DstLang == "he") {
            translatedText = UNICODE_RLE + translatedText; // 支持从右到左的语言
        }
        SrcLang = "UTF8";
        DstLang = "UTF8";
        return translatedText.Trim(); // 去除多余空白
    }

    // 处理 API 错误
    if (Root["error"]["message"].isString()) {
        string errorMessage = Root["error"]["message"].asString();
        HostPrintUTF8("{$CP0=API 错误：$}" + errorMessage + "\n");
    } else {
        HostPrintUTF8("{$CP0=翻译失败。请检查输入参数或 API 密钥配置。$}\n");
    }

    return "";
}

// 插件初始化
void OnInitialize() {
    HostPrintUTF8("{$CP0=ChatGPT 翻译插件已加载。$}\n");
    // 从临时存储中加载模型名称和 API 密钥（如果保存过）
    api_key = HostLoadString("api_key", "");
    selected_model = HostLoadString("selected_model", "gpt-4o-mini");
    if (!api_key.empty()) {
        HostPrintUTF8("{$CP0=已加载保存的 API 密钥和模型名称。$}\n");
    }
}

// 插件卸载
void OnFinalize() {
    HostPrintUTF8("{$CP0=ChatGPT 翻译插件已卸载。$}\n");
}
