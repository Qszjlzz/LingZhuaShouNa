import { useEffect, useState } from "react";
import { SpatialScreen } from "./components/SpatialScreen";
import { ClassificationScreen } from "./components/ClassificationScreen";
import { CommunityScreen } from "./components/CommunityScreen";
import { MineScreen } from "./components/MineScreen";
import { ShootFlow, RelightFlow } from "./components/ShootFlow";
import { BottomNav, type Tab } from "./components/BottomNav";
import { getNativeState, nativeRequest, type NativeState } from "./nativeBridge";

export default function App() {
  const [tab, setTab] = useState<Tab>("spatial");
  const [shooting, setShooting] = useState(false);
  const [scanDone, setScanDone] = useState(false);
  const [relightSpace, setRelightSpace] = useState<{ id: string; name: string; vivid: string } | null>(null);
  const [relitSpaceId, setRelitSpaceId] = useState<string | null>(null);
  const [nativeState, setNativeState] = useState<NativeState | null>(null);
  const refresh = () => getNativeState().then(setNativeState).catch(() => undefined);

  // 点下去的这一刻就让原生把摄像头加电，别等 React 把拍摄页渲染完才开工 ——
  // 相机硬件启动和页面渲染并行跑，页面挂好时画面通常已经在了。
  const openShoot = () => {
    void nativeRequest("camera.preview.warm", {}).catch(() => undefined);
    setShooting(true);
  };

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
            onReshoot={openShoot}
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
        {tab === "mine" && <MineScreen nativeState={nativeState} onNativeChange={refresh} />}

        <BottomNav active={tab} onChange={setTab} onCamera={openShoot} />

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
