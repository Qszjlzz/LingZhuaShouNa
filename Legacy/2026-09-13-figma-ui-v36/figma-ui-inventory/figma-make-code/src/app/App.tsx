import { useState } from "react";
import { SpatialScreen } from "./components/SpatialScreen";
import { ClassificationScreen } from "./components/ClassificationScreen";
import { CommunityScreen } from "./components/CommunityScreen";
import { MineScreen } from "./components/MineScreen";
import { ShootFlow } from "./components/ShootFlow";
import { BottomNav, type Tab } from "./components/BottomNav";

export default function App() {
  const [tab, setTab] = useState<Tab>("spatial");
  const [shooting, setShooting] = useState(false);

  return (
    <div
      className="size-full"
      style={{ backgroundColor: "#F6F1EB" }}
    >
      <div
        className="relative"
        style={{
          width: "100%",
          height: "100%",
          borderRadius: 0,
          overflow: "hidden",
          boxShadow: "none",
          flexShrink: 0,
        }}
      >
        {tab === "spatial" && <SpatialScreen />}
        {tab === "classification" && <ClassificationScreen />}
        {tab === "community" && <CommunityScreen />}
        {tab === "mine" && <MineScreen />}

        <BottomNav active={tab} onChange={setTab} onCamera={() => setShooting(true)} />

        {shooting && (
          <ShootFlow
            onClose={() => setShooting(false)}
            onFinish={() => {
              setShooting(false);
              setTab("spatial");
            }}
          />
        )}
      </div>
    </div>
  );
}
