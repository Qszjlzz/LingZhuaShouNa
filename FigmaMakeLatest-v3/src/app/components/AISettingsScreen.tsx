import { useEffect, useState } from "react";
import { ArrowLeft, Check, Loader2 } from "lucide-react";
import { nativeRequest } from "../nativeBridge";
import { COFFEE, ORANGE, LINEN, WHITE, SOFT } from "./theme";

type SettingsResponse = {
  isEnabled: boolean;
  endpoint: string;
  model: string;
  visionEndpoint: string;
  visionModel: string;
  hasAPIKey: boolean;
};

const PRESETS: { name: string; endpoint: string; model: string }[] = [
  { name: "阿里云百炼 · 通义千问 VL", endpoint: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions", model: "qwen-vl-max" },
  { name: "OpenAI · GPT-4o mini", endpoint: "https://api.openai.com/v1/chat/completions", model: "gpt-4o-mini" },
  { name: "智谱 · GLM-4V", endpoint: "https://open.bigmodel.cn/api/paas/v4/chat/completions", model: "glm-4v-flash" },
  { name: "硅基流动 · Qwen2.5-VL", endpoint: "https://api.siliconflow.cn/v1/chat/completions", model: "Qwen/Qwen2.5-VL-32B-Instruct" },
];

function Field({
  label,
  value,
  placeholder,
  hint,
  secret,
  onChange,
}: {
  label: string;
  value: string;
  placeholder?: string;
  hint?: string;
  secret?: boolean;
  onChange: (value: string) => void;
}) {
  return (
    <div className="mb-4">
      <p style={{ color: COFFEE, fontSize: 12.5, fontWeight: 600, marginBottom: 6 }}>{label}</p>
      <input
        value={value}
        placeholder={placeholder}
        type={secret ? "password" : "text"}
        onChange={(e) => onChange(e.target.value)}
        className="w-full px-3.5 py-2.5 outline-none"
        style={{
          backgroundColor: LINEN,
          color: COFFEE,
          borderRadius: 12,
          fontSize: 13,
          border: `1px solid ${SOFT}`,
        }}
      />
      {hint && (
        <p style={{ color: COFFEE, opacity: 0.5, fontSize: 11, marginTop: 5, lineHeight: 1.6 }}>{hint}</p>
      )}
    </div>
  );
}

export function AISettingsScreen({ onBack }: { onBack: () => void }) {
  const [enabled, setEnabled] = useState(false);
  const [endpoint, setEndpoint] = useState("");
  const [model, setModel] = useState("");
  const [visionEndpoint, setVisionEndpoint] = useState("");
  const [visionModel, setVisionModel] = useState("");
  const [apiKey, setApiKey] = useState("");
  const [hasKey, setHasKey] = useState(false);
  const [testing, setTesting] = useState(false);
  const [note, setNote] = useState("");

  useEffect(() => {
    void (async () => {
      try {
        const data = await nativeRequest<SettingsResponse>("llm.settings.get", {});
        setEnabled(!!data?.isEnabled);
        setEndpoint(data?.endpoint ?? "");
        setModel(data?.model ?? "");
        setVisionEndpoint(data?.visionEndpoint ?? "");
        setVisionModel(data?.visionModel ?? "");
        setHasKey(!!data?.hasAPIKey);
      } catch {
        /* 取不到就用空表单 */
      }
    })();
  }, []);

  const save = async () => {
    try {
      await nativeRequest("llm.settings.save", {
        isEnabled: enabled,
        endpoint,
        model,
        visionEndpoint,
        visionModel,
        apiKey,
      });
      setNote("已保存。拍照识别与方案生成都会用这套配置。");
    } catch (e) {
      setNote(`保存失败：${(e as Error)?.message ?? "未知错误"}`);
    }
  };

  const test = async () => {
    setTesting(true);
    setNote("正在测试连接…");
    try {
      await nativeRequest("llm.test", { endpoint, model, apiKey });
      setNote("连接测试完成，结果见上方提示。");
    } catch (e) {
      setNote(`测试失败：${(e as Error)?.message ?? "未知错误"}`);
    } finally {
      setTesting(false);
    }
  };

  return (
    <div className="h-full w-full overflow-y-auto pb-10" style={{ backgroundColor: WHITE }}>
      <div className="px-6 pt-14 pb-3 flex items-center gap-3">
        <button
          onClick={onBack}
          className="h-10 w-10 rounded-full flex items-center justify-center"
          style={{ backgroundColor: LINEN }}
        >
          <ArrowLeft size={18} color={COFFEE} />
        </button>
        <p style={{ color: COFFEE, fontSize: 18, fontWeight: 600 }}>AI 设置</p>
      </div>

      <div className="px-6 mt-3">
        <div
          className="p-4 mb-5"
          style={{ backgroundColor: "rgba(250,136,58,0.08)", borderRadius: 16 }}
        >
          <p style={{ color: COFFEE, fontSize: 12.5, lineHeight: 1.7 }}>
            打开后，拍照识别会先走云端多模态模型（认得更准、名字是中文），本地模型继续负责轮廓与
            AR 叠加；不打开也能用，只是完全依赖本地小模型。
          </p>
        </div>

        <button
          onClick={() => setEnabled((v) => !v)}
          className="w-full flex items-center justify-between px-3.5 py-3 mb-5"
          style={{ backgroundColor: LINEN, borderRadius: 12 }}
        >
          <span style={{ color: COFFEE, fontSize: 13.5, fontWeight: 600 }}>启用云端 AI</span>
          <span
            className="w-11 h-6 rounded-full flex items-center px-0.5"
            style={{ backgroundColor: enabled ? ORANGE : SOFT, justifyContent: enabled ? "flex-end" : "flex-start" }}
          >
            <span className="w-5 h-5 rounded-full" style={{ backgroundColor: WHITE }} />
          </span>
        </button>

        <p style={{ color: COFFEE, fontSize: 12.5, fontWeight: 600, marginBottom: 8 }}>常用服务（点一下直接填）</p>
        <div className="flex flex-wrap gap-2 mb-5">
          {PRESETS.map((p) => (
            <button
              key={p.name}
              onClick={() => {
                setEndpoint(p.endpoint);
                setModel(p.model);
                setVisionEndpoint("");
                setVisionModel("");
                setEnabled(true);
              }}
              className="px-3 py-1.5"
              style={{ backgroundColor: LINEN, color: COFFEE, borderRadius: 999, fontSize: 11.5 }}
            >
              {p.name}
            </button>
          ))}
        </div>

        <Field
          label="接口地址"
          value={endpoint}
          placeholder="https://.../v1/chat/completions"
          hint="支持 OpenAI 兼容的 /chat/completions，也支持 OpenAI 官方 /responses。"
          onChange={setEndpoint}
        />
        <Field
          label="模型"
          value={model}
          placeholder="例如 qwen-vl-max"
          hint="拍照识别必须使用带视觉能力的多模态模型，纯文本模型识别不了照片。"
          onChange={setModel}
        />
        <Field
          label="API Key"
          value={apiKey}
          secret
          placeholder={hasKey ? "已保存过 Key，留空表示不修改" : "粘贴你的 Key"}
          onChange={setApiKey}
        />
        <Field
          label="视觉识别接口（选填）"
          value={visionEndpoint}
          placeholder="留空则用上面的接口地址"
          onChange={setVisionEndpoint}
        />
        <Field
          label="视觉识别模型（选填）"
          value={visionModel}
          placeholder="留空则用上面的模型"
          hint="想让规划和识别用不同模型时才填。"
          onChange={setVisionModel}
        />

        <div className="flex gap-3 mt-2">
          <button
            onClick={() => void save()}
            className="flex-1 py-3 flex items-center justify-center gap-1.5"
            style={{ backgroundColor: ORANGE, color: WHITE, borderRadius: 999, fontSize: 14, fontWeight: 600 }}
          >
            <Check size={15} /> 保存
          </button>
          <button
            onClick={() => void test()}
            disabled={testing}
            className="flex-1 py-3 flex items-center justify-center gap-1.5"
            style={{ backgroundColor: LINEN, color: COFFEE, borderRadius: 999, fontSize: 14, fontWeight: 600 }}
          >
            {testing ? <Loader2 size={15} className="animate-spin" /> : null} 测试连接
          </button>
        </div>

        {note && (
          <p style={{ color: COFFEE, opacity: 0.65, fontSize: 12, marginTop: 12, lineHeight: 1.7 }}>{note}</p>
        )}
      </div>
    </div>
  );
}
