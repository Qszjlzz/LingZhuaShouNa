import { useState } from "react";
import { ArrowLeft, ChevronLeft, ChevronRight, Clock, Plus, MapPin } from "lucide-react";
import { COFFEE, ORANGE, LINEN, BLUE, WHITE, SOFT } from "./theme";

type Event = {
  id: string;
  date: number;
  time: string;
  title: string;
  space: string;
  duration: string;
  color: string;
  status: "active" | "scheduled" | "done";
};

const events: Event[] = [
  { id: "e1", date: 2, time: "10:00", title: "小公寓衣柜整理", space: "卧室", duration: "1h 12m", color: ORANGE, status: "active" },
  { id: "e2", date: 4, time: "08:30", title: "5分钟厨房复位", space: "厨房", duration: "30 min", color: BLUE, status: "scheduled" },
  { id: "e3", date: 9, time: "10:00", title: "周末办公区复位", space: "家庭办公区", duration: "45 min", color: "#A88370", status: "scheduled" },
  { id: "e4", date: 9, time: "15:00", title: "书架归类", space: "客厅", duration: "1h", color: BLUE, status: "scheduled" },
  { id: "e5", date: 12, time: "09:00", title: "储藏室深度清洁", space: "Kitchen", duration: "1h 30m", color: "#7BB28F", status: "done" },
  { id: "e6", date: 16, time: "11:00", title: "衣柜第二轮筛选", space: "卧室", duration: "50 min", color: ORANGE, status: "scheduled" },
  { id: "e7", date: 23, time: "14:00", title: "储物间焕新", space: "储物间", duration: "2h", color: "#A88370", status: "scheduled" },
];

const months = ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"];
const dayLabels = ["日", "一", "二", "三", "四", "五", "六"];

export function CalendarScreen({ onBack }: { onBack: () => void }) {
  // May 2026 — May 1 2026 is a Friday
  const [monthIdx, setMonthIdx] = useState(4); // May
  const [year] = useState(2026);
  const [selected, setSelected] = useState(3); // today (Sun May 3)

  const firstDay = new Date(year, monthIdx, 1).getDay();
  const daysInMonth = new Date(year, monthIdx + 1, 0).getDate();

  const cells: (number | null)[] = [];
  for (let i = 0; i < firstDay; i++) cells.push(null);
  for (let d = 1; d <= daysInMonth; d++) cells.push(d);
  while (cells.length % 7 !== 0) cells.push(null);

  const today = 3;
  const dayEvents = events.filter((e) => e.date === selected);

  // Stats
  const totalEvents = events.length;
  const totalMinutes = events.reduce((sum, e) => {
    const m = e.duration.match(/(\d+)h/);
    const mm = e.duration.match(/(\d+)\s*min/);
    return sum + (m ? parseInt(m[1]) * 60 : 0) + (mm ? parseInt(mm[1]) : 0);
  }, 0);

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
                {totalEvents} sessions
              </p>
              <p style={{ color: WHITE, opacity: 0.7, fontSize: 12, marginTop: 2 }}>
                {Math.floor(totalMinutes / 60)}h {totalMinutes % 60}m scheduled
              </p>
            </div>
            <div className="flex gap-1.5">
              {[ORANGE, BLUE, "#7BB28F", "#A88370"].map((c, i) => (
                <div
                  key={i}
                  style={{
                    width: 6,
                    height: 24 + i * 6,
                    backgroundColor: c,
                    borderRadius: 3,
                    opacity: 0.9,
                  }}
                />
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Month switcher */}
      <div className="px-6 mt-5 flex items-center justify-between">
        <button
          onClick={() => setMonthIdx((m) => Math.max(0, m - 1))}
          className="h-9 w-9 rounded-full flex items-center justify-center"
          style={{ backgroundColor: WHITE }}
        >
          <ChevronLeft size={16} color={COFFEE} />
        </button>
        <p style={{ color: COFFEE, fontSize: 16, fontWeight: 600 }}>
          {months[monthIdx]} {year}
        </p>
        <button
          onClick={() => setMonthIdx((m) => Math.min(11, m + 1))}
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
          style={{
            backgroundColor: WHITE,
            borderRadius: 22,
            boxShadow: "0 4px 18px rgba(123,92,72,0.05)",
          }}
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
              const dayEv = events.filter((e) => e.date === d);
              const isToday = d === today && monthIdx === 4;
              const isSel = d === selected && monthIdx === 4;
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
                            backgroundColor: isSel ? WHITE : e.color,
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
          { c: ORANGE, l: "进行中" },
          { c: BLUE, l: "已计划" },
          { c: "#7BB28F", l: "已完成" },
          { c: "#A88370", l: "其他" },
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
          {months[monthIdx]} {selected} · {dayEvents.length} {dayEvents.length === 1 ? "session" : "sessions"}
        </p>
      </div>

      <div className="px-6 space-y-2">
        {dayEvents.length === 0 && (
          <div
            className="p-6 text-center"
            style={{ backgroundColor: WHITE, borderRadius: 18 }}
          >
            <p style={{ color: COFFEE, opacity: 0.5, fontSize: 12 }}>
              No sessions this day. Tap + to schedule.
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
              style={{
                width: 4,
                borderRadius: 4,
                backgroundColor: e.color,
              }}
            />
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 mb-1">
                <Clock size={11} color={COFFEE} opacity={0.55} />
                <span style={{ color: COFFEE, opacity: 0.6, fontSize: 11 }}>
                  {e.time} · {e.duration}
                </span>
              </div>
              <p style={{ color: COFFEE, fontSize: 13, fontWeight: 600 }}>{e.title}</p>
              <div className="flex items-center gap-1 mt-1">
                <MapPin size={10} color={COFFEE} opacity={0.5} />
                <span style={{ color: COFFEE, opacity: 0.55, fontSize: 11 }}>{e.space}</span>
              </div>
            </div>
            <span
              className="self-start px-2 py-0.5"
              style={{
                backgroundColor: e.color,
                color: WHITE,
                borderRadius: 999,
                fontSize: 9,
                fontWeight: 600,
              }}
            >
              {e.status.toUpperCase()}
            </span>
          </div>
        ))}
      </div>

      {/* Upcoming this week */}
      <div className="px-6 mt-7 mb-3">
        <p style={{ color: COFFEE, fontSize: 14, fontWeight: 600 }}>未来安排</p>
      </div>
      <div className="px-6 space-y-2">
        {events
          .filter((e) => e.date >= today && e.date <= today + 7)
          .sort((a, b) => a.date - b.date)
          .map((e) => (
            <button
              key={e.id}
              onClick={() => setSelected(e.date)}
              className="w-full flex items-center gap-3 p-3"
              style={{ backgroundColor: WHITE, borderRadius: 16 }}
            >
              <div
                className="h-12 w-12 rounded-xl flex flex-col items-center justify-center flex-shrink-0"
                style={{ backgroundColor: LINEN }}
              >
                <span style={{ color: COFFEE, opacity: 0.55, fontSize: 9, fontWeight: 600 }}>
                  {months[monthIdx].toUpperCase()}
                </span>
                <span style={{ color: COFFEE, fontSize: 16, fontWeight: 600, lineHeight: 1 }}>
                  {e.date}
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
                style={{ backgroundColor: e.color }}
              />
            </button>
          ))}
      </div>
    </div>
  );
}
