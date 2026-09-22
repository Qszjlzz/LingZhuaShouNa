import { useEffect, useState } from "react";
import { SpatialScreen } from "./components/SpatialScreen";
import { ClassificationScreen } from "./components/ClassificationScreen";
import { CommunityScreen } from "./components/CommunityScreen";
import { MineScreen } from "./components/MineScreen";
import { ShootFlow, RelightFlow } from "./components/ShootFlow";
import { BottomNav, type Tab } from "./components/BottomNav";
import { getNativeState, type NativeState } from "./nativeBridge";

export default function App() {
  const [tab, setTab] = useState<Tab>("spatial");
  const [shooting, setShooting] = useState(false);
  const [scanDone, setScanDone] = useState(false);
  const [relightSpace, setRelightSpace] = useState<{ id: string; name: string; vivid: string } | null>(null);
  const [relitSpaceId, setRelitSpaceId] = useState<string | null>(null);
  const [nativeState, setNativeState] = useState<NativeState | null>(null);
  const refresh = () => getNativeState().then(setNativeState).catch(() => undefined);

  useEffect(() => { void refresh(); }, []);
  useEffect(() => { void refresh(); }, [tab]);

  return (
    <div
      className="relative size-full overflow-hidden"
      style={{ backgroundColor: "#EDE5DA" }}
    >
      <div className="relative size-full overflow-hidden">
        {tab === "spatial" && (
          <SpatialScreen
            nativeSpaces={nativeState?.spaces}
            selectedSpaceID={nativeState?.selectedSpaceID}
            onNativeChange={refresh}
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
        {tab === "classification" && <ClassificationScreen nativeState={nativeState} onNativeChange={refresh} />}
        {tab === "community" && <CommunityScreen nativeState={nativeState} onNativeChange={refresh} />}
        {tab === "mine" && <MineScreen nativeState={nativeState} />}

        <BottomNav active={tab} onChange={setTab} onCamera={() => setShooting(true)} />

        {shooting && (
          <ShootFlow
            onClose={() => setShooting(false)}
            onFinish={() => {
              setShooting(false);
              setTab("spatial");
              setScanDone(true);
              void refresh();
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
