import { useEffect, useRef, useState } from "react";
import { SpatialScreen } from "./components/SpatialScreen";
import { ClassificationScreen } from "./components/ClassificationScreen";
import { MineScreen } from "./components/MineScreen";
import { MyPlansScreen } from "./components/MyPlansScreen";
import { ShootFlow, RelightFlow } from "./components/ShootFlow";
import { BottomNav, type Tab } from "./components/BottomNav";
import { getNativeState, nativeRequest, type NativeState } from "./nativeBridge";

export default function App() {
  const [tab, setTab] = useState<Tab>("spatial");
  const [shooting, setShooting] = useState(false);
  const [reusePlan, setReusePlan] = useState(false);
  const [scanDone, setScanDone] = useState(false);
  const [relightSpace, setRelightSpace] = useState<{ id: string; name: string; vivid: string } | null>(null);
  // dev/演示：?flow=plandeck|zones|arguide|reward 直接挂载拍摄主线到指定屏（浏览器无相机也能看）
  const [demoFlow, setDemoFlow] = useState<string | null>(
    new URLSearchParams(location.search).get("flow"),
  );
  const [relitSpaceId, setRelitSpaceId] = useState<string | null>(null);
  const [nativeState, setNativeState] = useState<NativeState | null>(null);
  const stateRequestVersion = useRef(0);
  const changingDataScope = useRef(false);
  const isBrowserPreview = !window.webkit?.messageHandlers?.smartpaw;
  const isPresentationMode = nativeState?.isPresentationMode ?? isBrowserPreview;
  const dataScope = nativeState ? isPresentationMode ? "presentation" : "personal" : isBrowserPreview ? "browser-preview" : "loading";
  const refresh = async () => {
    if (changingDataScope.current) return;
    const version = ++stateRequestVersion.current;
    try {
      const state = await getNativeState();
      if (version === stateRequestVersion.current) setNativeState(state);
    } catch { /* Browser previews keep their local sample data. */ }
  };

  const changePresentationMode = async (enabled: boolean) => {
    if (changingDataScope.current) return;
    changingDataScope.current = true;
    const version = ++stateRequestVersion.current;
    try {
      const state = isBrowserPreview ? enabled ? null : {
        isPresentationMode: false, spaces: [], scannedItems: [], achievements: [],
        communityCases: [], comments: {}, liked: [], favorites: [], followedAuthors: [], schedules: [],
      } satisfies NativeState : await nativeRequest<NativeState>("presentation.mode.set", { enabled });
      if (version !== stateRequestVersion.current) return;
      setShooting(false);
      setReusePlan(false);
      setScanDone(false);
      setDemoFlow(null);
      setRelightSpace(null);
      setRelitSpaceId(null);
      setNativeState(state);
    } finally { changingDataScope.current = false; }
  };

  // dev/演示：?relight=choice|tune|proof|complete 直接挂载点亮链路（不带参数不影响正常流程）
  useEffect(() => {
    const s = new URLSearchParams(location.search).get("relight");
    if (s) setRelightSpace({ id: "p3", name: "厨房", vivid: "#A9B486" });
  }, []);

  // 相机在 App 前台期间一直跑着（画面层已铺好、只是透明不可见），
  // 这里只剩"把画面显示出来"一步，不等硬件、不建图层 —— 点下去就是相机。
  const openShoot = () => {
    setReusePlan(false);
    void nativeRequest("camera.preview.show", {}).catch(() => undefined);
    setShooting(true);
  };

  // 从空间卡进「重新点亮」同样是先拍照：相机画面要在页面透明处透出来，
  // 所以跟主线一样先把画面叫起来，再卸载首页整层（否则会盖住取景画面）。
  const openRelight = (id: string, name: string, vivid: string) => {
    void nativeRequest("camera.preview.show", {}).catch(() => undefined);
    setRelightSpace({ id, name, vivid });
  };

  useEffect(() => { void refresh(); }, []);
  useEffect(() => { void refresh(); }, [tab]);

  return (
    <div
      className={
        shooting || relightSpace || demoFlow          ? // 全屏覆盖页（拍摄/焕新）用 fixed 定位：不依赖祖先高度，
            // 否则没有全局 height:100% 时 size-full 容器会塌成 0 高。
            "fixed inset-0 overflow-hidden"
          : "relative size-full overflow-hidden"
      }
      style={{ backgroundColor: shooting || relightSpace ? "transparent" : "#EDE5DA" }}
    >
      <div key={dataScope} className="relative size-full overflow-hidden">
        {/* 拍摄时把首页整层卸载：拍摄页的取景靠"页面透明 + 原生相机画面从底下透出"，
            首页若还挂在底下，会不透明地盖住相机画面（截图里透出空间地图就是这个原因）。 */}
        {!shooting && !relightSpace && !demoFlow && (
          <>
            {tab === "spatial" && (
              <SpatialScreen
                nativeSpaces={nativeState?.spaces}
                isPresentationMode={isPresentationMode}
                selectedSpaceID={nativeState?.selectedSpaceID}
                onNativeChange={refresh}
                onReshoot={(mode, space) => {
                  if (mode === "compare" && space) {
                    openRelight(space.id, space.name, space.vivid);
                  } else {
                    openShoot();
                    setReusePlan(mode === "same");
                  }
                }}
                scanDone={scanDone}
                onScanAck={() => setScanDone(false)}
                onRelightRequest={(id, name, vivid) => {
                  openRelight(id, name, vivid);
                  setTab("spatial");
                }}
                relitSpaceId={relitSpaceId}
                onRelitAck={() => setRelitSpaceId(null)}
              />
            )}
            {tab === "classification" && <ClassificationScreen nativeState={nativeState} onNativeChange={refresh} onCamera={openShoot} />}
            {tab === "project" && <MyPlansScreen nativeState={nativeState} onNativeChange={refresh} onBack={() => setTab("mine")} isTabRoot onAddPlan={openShoot} />}
            {tab === "mine" && <MineScreen nativeState={nativeState} onNativeChange={refresh} onOpenProjects={() => setTab("project")} onPresentationModeChange={changePresentationMode} onBrowseFlow={() => setDemoFlow("plandeck")} />}

            <BottomNav active={tab} onChange={setTab} onCamera={openShoot} />
          </>
        )}

        {shooting && (
          <ShootFlow
            reusePlan={reusePlan}
            onClose={() => setShooting(false)}
            onFinish={() => {
              setShooting(false);
              setTab("spatial");
              setScanDone(true);
              void refresh();
            }}
          />
        )}

        {demoFlow && (
          <ShootFlow
            onClose={() => setDemoFlow(null)}
            onFinish={() => {
              setDemoFlow(null);
              setTab("spatial");
              setScanDone(true);
              void refresh();
            }}
            demoStep={demoFlow as never}
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
              void refresh();
            }}
          />
        )}
      </div>
    </div>
  );
}
