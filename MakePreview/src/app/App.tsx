import { useState } from "react";
import { SpatialScreen } from "./components/SpatialScreen";
import { ClassificationScreen } from "./components/ClassificationScreen";
import { CommunityScreen } from "./components/CommunityScreen";
import { MineScreen } from "./components/MineScreen";
import { ShootFlow, RelightFlow } from "./components/ShootFlow";
import { BottomNav, type Tab } from "./components/BottomNav";

export default function App() {
  const [tab, setTab] = useState<Tab>("spatial");
  const [shooting, setShooting] = useState(false);
  const [scanDone, setScanDone] = useState(false);
  const [relightSpace, setRelightSpace] = useState<{ id: string; name: string; vivid: string } | null>(null);
  const [relitSpaceId, setRelitSpaceId] = useState<string | null>(null);

  return (
    <div
      className="size-full flex items-center justify-center p-6"
      style={{ backgroundColor: "#EDE5DA" }}
    >
      <div
        className="relative"
        style={{
          width: 390,
          height: 844,
          borderRadius: 48,
          overflow: "hidden",
          boxShadow: "0 30px 80px rgba(123,92,72,0.18), 0 0 0 10px #2a201a",
          flexShrink: 0,
        }}
      >
        {tab === "spatial" && (
          <SpatialScreen
            onReshoot={() => setShooting(true)}
            scanDone={scanDone}
            onScanAck={() => setScanDone(false)}
            onRelightRequest={(id, name, vivid) => {
              setRelightSpace({ id, name, vivid });
              setTab("spatial");
            }}
            relitSpaceId={relitSpaceId}
            onRelitAck={() => setRelitSpaceId(null)}
          />
        )}
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
              setScanDone(true);
            }}
          />
        )}

        {relightSpace && (
          <RelightFlow
            spaceId={relightSpace.id}
            spaceName={relightSpace.name}
            spaceVivid={relightSpace.vivid}
            onClose={() => setRelightSpace(null)}
            onComplete={(id) => {
              setRelightSpace(null);
              setTab("spatial");
              setRelitSpaceId(id);
            }}
          />
        )}
      </div>
    </div>
  );
}
