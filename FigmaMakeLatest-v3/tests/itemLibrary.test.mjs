import test from "node:test";
import assert from "node:assert/strict";
import { emptyLibrary, parseLibrary, normalizeLibrary, importLibraryItems, createLibraryFolder, moveLibraryItem, renameLibraryFolder, removeLibraryFolder, removeLibraryItem, reorderLibrary, updateLibraryItem, libraryStorageKey } from "../src/app/itemLibrary.ts";
const items = [{id:"book",name:"书",category:"书籍"},{id:"pen",name:"笔",category:"文具"},{id:"cup",name:"杯子",category:"厨房"}];
const seeded = () => importLibraryItems(emptyLibrary(), items);
test("selective import deduplicates stable IDs and retains distinct equal names",()=>{ const state=importLibraryItems(seeded(),[items[0],{id:"book2",name:"书",category:"书籍"}]); assert.equal(state.items.length,4); assert.deepEqual(state.rootOrder,["item:book","item:pen","item:cup","item:book2"]); });
test("cross-category folder creation moves references and does not change source categories",()=>{const state=createLibraryFolder(seeded(),"desk","桌面",["book","pen"]);assert.deepEqual(state.folders[0].itemIDs,["book","pen"]);assert.deepEqual(state.rootOrder,["folder:desk","item:cup"]);assert.deepEqual(state.items,items.map(x=>({...x,image:undefined})));});
test("moving in and out and renaming preserve identity, counts and custom images",()=>{let state=createLibraryFolder(seeded(),"desk","桌面",["book"]);state=moveLibraryItem(state,"pen","desk");state=renameLibraryFolder(state,"desk","随手用品");state=updateLibraryItem(state,"pen",{image:"data:image/png;base64,YQ=="});state=moveLibraryItem(state,"book",null);assert.equal(state.folders[0].name,"随手用品");assert.deepEqual(state.folders[0].itemIDs,["pen"]);assert.equal(state.items.length,3);assert.equal(state.items.find(x=>x.id==="pen").image,"data:image/png;base64,YQ==");assert.equal(state.rootOrder.at(-1),"item:book");});
test("folder dissolution returns all contents without deleting library items",()=>{const state=removeLibraryFolder(createLibraryFolder(seeded(),"desk","桌面",["book","pen"]),"desk");assert.equal(state.items.length,3);assert.deepEqual(state.rootOrder,["item:book","item:pen","item:cup"]);});
test("root and folder reordering persist in a JSON round trip",()=>{let state=reorderLibrary(seeded(),"item:cup","item:book",null);state=createLibraryFolder(state,"desk","桌面",["book","pen"]);state=reorderLibrary(state,"pen","book","desk");assert.deepEqual(state.folders[0].itemIDs,["pen","book"]);assert.deepEqual(parseLibrary(JSON.stringify(state)),state);});
test("deleting a library item clears its folder reference without affecting other items",()=>{const state=removeLibraryItem(createLibraryFolder(seeded(),"desk","桌面",["book","pen"]),"book");assert.equal(state.items.length,2);assert.deepEqual(state.folders[0].itemIDs,["pen"]);});
test("corrupt persistence sanitizes stale or duplicated memberships and dangerous image URLs",()=>{const state=normalizeLibrary({items:[...items,items[0],{id:"bad",name:"X",category:"x",image:"javascript:evil"}],folders:[{id:"a",name:"A",itemIDs:["book","book","gone"]},{id:"b",name:"B",itemIDs:["book","pen"]}],rootOrder:["item:book","item:gone","folder:a","folder:a"]});assert.deepEqual(state.folders.map(x=>x.itemIDs),[["book"],["pen"]]);assert.equal(state.items[3].image,undefined);assert.deepEqual(state.rootOrder,["folder:a","folder:b","item:cup","item:bad"]);assert.deepEqual(parseLibrary("broken"),emptyLibrary());});
test("presentation and personal libraries are isolated",()=>{assert.notEqual(libraryStorageKey(true),libraryStorageKey(false));});

test("move between existing folders keeps a single membership and preserves all references",()=>{let state=createLibraryFolder(createLibraryFolder(seeded(),"a","随手用品",["book","pen"]),"b","厨房",["cup"]);state=moveLibraryItem(state,"pen","b");assert.deepEqual(state.folders.map(x=>x.itemIDs),[["book"],["cup","pen"]]);assert.equal(state.items.length,3);assert.equal(state.rootOrder.filter(x=>x.startsWith("item:")).length,0);assert.deepEqual(moveLibraryItem(state,"pen","missing"),state);});

test("scan candidates share native identities and retain same-name physical instances", async () => {
  const { scanLibraryItems } = await import("../src/app/itemLibrary.ts");
  const scan = [{id:"a",name:"笔",category:"文具"},{id:"b",name:"笔",category:"文具"},{id:"a",name:"笔更新",category:"文具"},{id:"blank",name:"  ",category:""}];
  const original = structuredClone(scan);
  const values = scanLibraryItems(scan,{spaceID:"desk",spaceName:"书桌"});
  assert.deepEqual(values.map(x=>x.id),["native:a","native:b"]);
  assert.deepEqual(values.map(x=>x.sourceID),["a","b"]);
  assert.ok(values.every(x=>x.sourceSpaceID==="desk"&&x.sourceSpaceName==="书桌"));
  assert.deepEqual(scan,original);
  assert.equal(scanLibraryItems([{id:"x",name:"工具",category:"收纳工具"}])[0].category,"工具");
});

test("postcapture partial saves preserve latest folders and do not write empty or duplicate selections", async () => {
  const { saveLibrarySelection, scanLibraryItems } = await import("../src/app/itemLibrary.ts");
  const key=libraryStorageKey(false); const data=new Map(); let writes=0;
  const storage={getItem:key=>data.get(key)??null,setItem:(key,value)=>{writes++;data.set(key,value);}};
  const scan=scanLibraryItems([{id:"a",name:"笔",category:"文具"},{id:"b",name:"笔",category:"文具"},{id:"c",name:"杯子",category:"饮品"}]);
  assert.equal(saveLibrarySelection(storage,false,scan,[]).status,"empty");assert.equal(writes,0);
  assert.equal(saveLibrarySelection(storage,false,scan,["unknown"]).status,"empty");assert.equal(writes,0);
  let result=saveLibrarySelection(storage,false,scan,["native:a","native:b"]); assert.equal(result.status,"saved");assert.equal(result.added,2);assert.equal(writes,1);
  data.set(key,JSON.stringify(createLibraryFolder(result.library,"f","文具",["native:a","native:b"])));
  result=saveLibrarySelection(storage,false,scan,["native:a","native:c"]);assert.equal(result.added,1);assert.equal(result.library.items.length,3);assert.deepEqual(result.library.folders[0].itemIDs,["native:a","native:b"]);
  assert.equal(saveLibrarySelection(storage,false,scan,["native:a"]).added,0);assert.equal(writes,2);
  assert.equal(data.has(libraryStorageKey(true)),false);
});

test("postcapture storage errors do not report success or overwrite unreadable persistence", async () => {
  const { saveLibrarySelection, scanLibraryItems } = await import("../src/app/itemLibrary.ts");
  const scan=scanLibraryItems([{id:"a",name:"笔",category:"文具"}]);let writes=0;
  assert.equal(saveLibrarySelection({getItem(){throw new Error("blocked");},setItem(){writes++;}},false,scan,["native:a"]).status,"unavailable");assert.equal(writes,0);
  assert.equal(saveLibrarySelection({getItem(){return null;},setItem(){throw new Error("quota");}},false,scan,["native:a"]).status,"unavailable");
});
