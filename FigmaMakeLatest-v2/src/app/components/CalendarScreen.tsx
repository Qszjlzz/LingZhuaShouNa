import { useState } from "react";
import { ArrowLeft, ChevronLeft, ChevronRight, Clock, Plus, MapPin, Trash2 } from "lucide-react";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";
import { nativeRequest, type NativeState } from "../nativeBridge";

type ScheduleEvent = {
  id: string;
  date: Date;
  time: string;
  title: string;
  space: string;
  note: string;
  status: "scheduled" | "done";
};

const months = ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"];
const dayLabels = ["日", "一", "二", "三", "四", "五", "六"];

const pad = (value: number) => String(value).padStart(2, "0");
const timeText = (date: Date) => `${pad(date.getHours())}:${pad(date.getMinutes())}`;
const dateTimeValue = (date: Date) =>
  `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;

export function CalendarScreen({
  onBack,
  nativeState,
  onNativeChange,
}: {
  onBack: () => void;
  nativeState?: NativeState | null;
  onNativeChange?: () => void;
}) {
  const now = new Date();
  const [monthIdx, setMonthIdx] = useState(now.getMonth());
  const [year, setYear] = useState(now.getFullYear());
  const [selected, setSelected] = useState(now.getDate());
  const [adding, setAdding] = useState(false);
  const [title, setTitle] = useState("");
  const [dueAt, setDueAt] = useState(dateTimeValue(now));
  const [note, setNote] = useState("");

  // 日程来自原生 AppViewModel.scheduleItems，勾选/删除/新增都会写入设备存储
  const events: ScheduleEvent[] = (nativeState?.schedules ?? []).map((item) => {
    const date = new Date(item.dueDate);
    return {
      id: item.id,
      date,
      time: Number.isNaN(date.getTime()) ? "--:--" : timeText(date),
      title: item.title,
      space: item.spaceName,
      note: item.note ?? "",
      status: item.isDone ? "done" : "scheduled",
    };
  });

  const inMonth = (event: ScheduleEvent) =>
    event.date.getFullYear() === year && event.date.getMonth() === monthIdx;
  const monthEvents = events.filter(inMonth);

  const firstDay = new Date(year, monthIdx, 1).getDay();
  const daysInMonth = new Date(year, monthIdx + 1, 0).getDate();
  const cells: (number | null)[] = [];
  for (let i = 0; i < firstDay; i++) cells.push(null);
  for (let d = 1; d <= daysInMonth; d++) cells.push(d);
  while (cells.length % 7 !== 0) cells.push(null);

  const isCurrentMonth = year === now.getFullYear() && monthIdx === now.getMonth();
  const dayEvents = events.filter((e) => inMonth(e) && e.date.getDate() === selected);
  const upcoming = events
    .filter((e) => e.date.getTime() >= now.getTime() && e.date.getTime() <= now.getTime() + 7 * 86400000)
    .sort((a, b) => a.date.getTime() - b.date.getTime());

  const mutate = (command: string, payload: Record<string, unknown>) => {
    void nativeRequest(command, payload)
      .then(() => onNativeChange?.())
      .catch(() => undefined);
  };

  const submit = () => {
    const trimmed = title.trim();
    if (!trimmed) return;
    mutate("schedule.add", { title: trimmed, dueText: dueAt.replace("T", " "), note });
    setTitle("");
    setNote("");
    setAdding(false);
  };

  return (
    <div className="h-full w-full overflow-y-auto pb-10" style={{ backgroundColor: LINEN }}>
      <div className="px-6 pt-14 pb-2 flex items-center justify-between">
        <button
          onClick={onBack}
          className="h-11 w-11 rounded-full flex items-center justify-center"
          style={{ backgroundColor: WHITE }}
        >
          <ArrowLeft size={20} color={COFFEE} />
        </button>
        <p style={{ color: COFFEE, fontSize: 17, fontWeight: 600 }}>日程</p>
        <button
          onClick={() => setAdding((value) => !value)}
          className="h-11 w-11 rounded-full flex items-center justify-center"
          style={{ backgroundColor: ORANGE, boxShadow: "0 6px 16px rgba(250,136,58,0.3)" }}
        >
          <Plus size={20} color={WHITE} />
        </button>
      </div>

      {/* Summary card */}
      <div className="px-6 mt-4">
        <div
          className="p-5"
          style={{
            background: `linear-gradient(135deg, ${COFFEE} 0%, #5d4334 100%)`,
            borderRadius: 24,
          }}
        >
          <p style={{ color: WHITE, opacity: 0.7, fontSize: 11 }}>本月安排</p>
          <div className="flex items-end justify-between mt-1">
            <div>
              <p style={{ color: WHITE, fontSize: 26, fontWeight: 600 }}>
                {monthEvents.length} 项日程
              </p>
              <p style={{ color: WHITE, opacity: 0.7, fontSize: 12, marginTop: 2 }}>
                {monthEvents.filter((e) => e.status === "done").length} 项已完成 · 共 {events.length} 项
              </p>
            </div>
            <div className="flex gap-1.5">
              {[ORANGE, BLUE, "#7BB28F", "#A88370"].map((c, i) => (
                <div
                  key={i}
                  style={{ width: 6, height: 24 + i * 6, backgroundColor: c, borderRadius: 3, opacity: 0.9 }}
                />
              ))}
            </div>
          </div>
        </div>
      </div>

      {adding && (
        <div className="px-6 mt-4">
          <div className="p-4 space-y-3" style={{ backgroundColor: WHITE, borderRadius: 18 }}>
            <input
              value={title}
              onChange={(event) => setTitle(event.target.value)}
              placeholder="日程标题，例如：桌面复盘"
              className="w-full px-3 py-2.5 outline-none"
              style={{ backgroundColor: LINEN, borderRadius: 12, color: COFFEE, fontSize: 13 }}
            />
            <input
              type="datetime-local"
              value={dueAt}
              onChange={(event) => setDueAt(event.target.value)}
              className="w-full px-3 py-2.5 outline-none"
              style={{ backgroundColor: LINEN, borderRadius: 12, color: COFFEE, fontSize: 13 }}
            />
            <input
              value={note}
              onChange={(event) => setNote(event.target.value)}
              placeholder="备注（可选）"
              className="w-full px-3 py-2.5 outline-none"
              style={{ backgroundColor: LINEN, borderRadius: 12, color: COFFEE, fontSize: 13 }}
            />
            <button
              onClick={submit}
              className="w-full py-3"
              style={{ backgroundColor: ORANGE, color: WHITE, borderRadius: 999, fontSize: 13, fontWeight: 600 }}
            >
              添加到日程
            </button>
          </div>
        </div>
      )}

      {/* Month switcher */}
      <div className="px-6 mt-5 flex items-center justify-between">
        <button
          onClick={() => {
            if (monthIdx === 0) {
              setMonthIdx(11);
              setYear(year - 1);
            } else setMonthIdx(monthIdx - 1);
          }}
          className="h-9 w-9 rounded-full flex items-center justify-center"
          style={{ backgroundColor: WHITE }}
        >
          <ChevronLeft size={16} color={COFFEE} />
        </button>
        <p style={{ color: COFFEE, fontSize: 16, fontWeight: 600 }}>
          {year} 年 {months[monthIdx]}
        </p>
        <button
          onClick={() => {
            if (monthIdx === 11) {
              setMonthIdx(0);
              setYear(year + 1);
            } else setMonthIdx(monthIdx + 1);
          }}
          className="h-9 w-9 rounded-full flex items-center justify-center"
          style={{ backgroundColor: WHITE }}
        >
          <ChevronRight size={16} color={COFFEE} />
        </button>
      </div>

      {/* Calendar grid */}
      <div className="px-6 mt-4">
        <div
          className="p-4"
          style={{ backgroundColor: WHITE, borderRadius: 22, boxShadow: "0 4px 18px rgba(123,92,72,0.05)" }}
        >
          <div className="grid grid-cols-7 gap-1 mb-2">
            {dayLabels.map((d, i) => (
              <div
                key={i}
                className="text-center"
                style={{ color: COFFEE, opacity: 0.5, fontSize: 11, fontWeight: 600 }}
              >
                {d}
              </div>
            ))}
          </div>
          <div className="grid grid-cols-7 gap-1">
            {cells.map((d, i) => {
              if (d === null) return <div key={i} />;
              const dayEv = events.filter((e) => inMonth(e) && e.date.getDate() === d);
              const isToday = isCurrentMonth && d === now.getDate();
              const isSel = d === selected;
              return (
                <button
                  key={i}
                  onClick={() => setSelected(d)}
                  className="aspect-square rounded-xl flex flex-col items-center justify-center relative"
                  style={{
                    backgroundColor: isSel ? COFFEE : isToday ? LINEN : "transparent",
                    color: isSel ? WHITE : COFFEE,
                  }}
                >
                  <span
                    style={{
                      fontSize: 13,
                      fontWeight: isToday || isSel ? 600 : 500,
                      opacity: isSel ? 1 : 0.85,
                    }}
                  >
                    {d}
                  </span>
                  {dayEv.length > 0 && (
                    <div className="flex gap-0.5 mt-0.5">
                      {dayEv.slice(0, 3).map((e, idx) => (
                        <div
                          key={idx}
                          className="rounded-full"
                          style={{
                            width: 4,
                            height: 4,
                            backgroundColor: isSel ? WHITE : e.status === "done" ? "#7BB28F" : BLUE,
                          }}
                        />
                      ))}
                    </div>
                  )}
                </button>
              );
            })}
          </div>
        </div>
      </div>

      {/* Legend */}
      <div className="px-6 mt-4 flex flex-wrap gap-3">
        {[
          { c: BLUE, l: "待完成" },
          { c: "#7BB28F", l: "已完成" },
        ].map((x) => (
          <div key={x.l} className="flex items-center gap-1.5">
            <div className="h-2 w-2 rounded-full" style={{ backgroundColor: x.c }} />
            <span style={{ color: COFFEE, opacity: 0.65, fontSize: 11 }}>{x.l}</span>
          </div>
        ))}
      </div>

      {/* Selected day timeline */}
      <div className="px-6 mt-6 mb-3 flex items-center justify-between">
        <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>
          {months[monthIdx]} {selected} 日 · {dayEvents.length} 项
        </p>
      </div>

      <div className="px-6 space-y-2">
        {dayEvents.length === 0 && (
          <div className="p-6 text-center" style={{ backgroundColor: WHITE, borderRadius: 18 }}>
            <p style={{ color: COFFEE, opacity: 0.5, fontSize: 12 }}>
              当天没有日程，点右上角 + 添加
            </p>
          </div>
        )}
        {dayEvents.map((e) => (
          <div
            key={e.id}
            className="flex gap-3"
            style={{
              backgroundColor: WHITE,
              borderRadius: 18,
              padding: 14,
              boxShadow: "0 3px 12px rgba(123,92,72,0.04)",
            }}
          >
            <div
              className="flex-shrink-0"
              style={{ width: 4, borderRadius: 4, backgroundColor: e.status === "done" ? "#7BB28F" : BLUE }}
            />
            <button
              onClick={() => mutate("schedule.toggle", { id: e.id })}
              className="flex-1 min-w-0 text-left"
            >
              <div className="flex items-center gap-2 mb-1">
                <Clock size={11} color={COFFEE} opacity={0.55} />
                <span style={{ color: COFFEE, opacity: 0.6, fontSize: 11 }}>{e.time}</span>
              </div>
              <p
                style={{
                  color: COFFEE,
                  fontSize: 13,
                  fontWeight: 600,
                  textDecoration: e.status === "done" ? "line-through" : "none",
                  opacity: e.status === "done" ? 0.5 : 1,
                }}
              >
                {e.title}
              </p>
              {e.note && (
                <p style={{ color: COFFEE, opacity: 0.45, fontSize: 10, marginTop: 2 }}>{e.note}</p>
              )}
              <div className="flex items-center gap-1 mt-1">
                <MapPin size={10} color={COFFEE} opacity={0.5} />
                <span style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>{e.space}</span>
              </div>
            </button>
            <div className="flex flex-col items-center gap-2">
              <span
                className="self-start px-2 py-0.5"
                style={{
                  backgroundColor: e.status === "done" ? "#7BB28F" : BLUE,
                  color: WHITE,
                  borderRadius: 999,
                  fontSize: 9,
                  fontWeight: 600,
                }}
              >
                {e.status === "done" ? "已完成" : "待办"}
              </span>
              <button
                onClick={() => mutate("schedule.delete", { id: e.id })}
                aria-label={`删除日程${e.title}`}
                className="h-7 w-7 rounded-full flex items-center justify-center"
                style={{ backgroundColor: LINEN }}
              >
                <Trash2 size={13} color={COFFEE} />
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* Upcoming this week */}
      <div className="px-6 mt-7 mb-3">
        <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>未来 7 天</p>
      </div>
      <div className="px-6 space-y-2">
        {upcoming.length === 0 && (
          <div className="p-5 text-center" style={{ backgroundColor: WHITE, borderRadius: 16 }}>
            <p style={{ color: COFFEE, opacity: 0.5, fontSize: 12 }}>暂无待办日程</p>
          </div>
        )}
        {upcoming.map((e) => (
          <button
            key={e.id}
            onClick={() => {
              setYear(e.date.getFullYear());
              setMonthIdx(e.date.getMonth());
              setSelected(e.date.getDate());
            }}
            className="w-full flex items-center gap-3 p-3"
            style={{ backgroundColor: WHITE, borderRadius: 16 }}
          >
            <div
              className="h-12 w-12 rounded-xl flex flex-col items-center justify-center flex-shrink-0"
              style={{ backgroundColor: LINEN }}
            >
              <span style={{ color: COFFEE, opacity: 0.55, fontSize: 9, fontWeight: 600 }}>
                {e.date.getMonth() + 1}月
              </span>
              <span style={{ color: COFFEE, fontSize: 16, fontWeight: 600, lineHeight: 1 }}>
                {e.date.getDate()}
              </span>
            </div>
            <div className="flex-1 text-left min-w-0">
              <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>{e.title}</p>
              <p style={{ color: COFFEE, opacity: 0.55, fontSize: 11, marginTop: 1 }}>
                {e.time} · {e.space}
              </p>
            </div>
            <div
              className="h-2 w-2 rounded-full"
              style={{ backgroundColor: e.status === "done" ? "#7BB28F" : BLUE }}
            />
          </button>
        ))}
      </div>
    </div>
  );
}
