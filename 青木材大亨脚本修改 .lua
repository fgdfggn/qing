local SRC_MAIN = [====[

local gs=function(service)
return game:GetService(service)
end

local lp=gs("Players").LocalPlayer
local ws=workspace
local rep=game:GetService("ReplicatedStorage")
local mouse=lp:GetMouse()

local defaultDragAttempts=50
local defaultDragInterval=0.01
 dragAttempts=defaultDragAttempts
 dragInterval=defaultDragInterval

local CONFIG_FILE="拖拽配置文件.txt"
local function loadDragConfig()
if writefile then
local ok,data=pcall(readfile,CONFIG_FILE)
if ok and data then
local att,inter=data:match("(%d+):([%d.]+)")
if att and inter then
dragAttempts=tonumber(att)or defaultDragAttempts
dragInterval=tonumber(inter)or defaultDragInterval
end
end
end
end
loadDragConfig()
local duckCycleIndex={}
math.randomseed(os.time()+tick())

local bai={
awaysday=false,awaysdnight=false,nofog=false,playernamedied="",autodropae=false,autopick=false,
moneyaoumt=1000,moneytoplayername="",dropdown={},soltnumber="1",walkspeed=16,JumpPower=50,
zlwjia=lp.Name,zix=3,zlz=3,noclipEnabled=false,noclipConn=nil,noclipCharConn=nil,
cuttreeselect="Generic",cachedSawmill=nil,cachedSawmillPos=nil,
selectSameOwnerOn=false,selectSameOwnerConn=nil,dragIDCounter=0,
}

local voidSaplingRunning=false
 duckOutlineEnabled=false
 duckHighlights={}
 duckAddedConn=nil
 duckRemovingConn=nil
 duckRefreshTask=nil

 voidCrateOutlineEnabled=false
 voidCrateHighlights={}
 voidCrateAddedConn=nil
 voidCrateRemovingConn=nil
 voidCrateRefreshTask=nil
 duckStopFlag=false

local function shuaxinlb(zji)
bai.dropdown={}
if zji==true then
for p,I in next,game.Players:GetChildren()do
table.insert(bai.dropdown,I.Name)
end
else
for p,I in next,game.Players:GetChildren()do
if I~=lp then
table.insert(bai.dropdown,I.Name)
end
end
end
end
shuaxinlb(true)

notify=function(title,desc,duration)
pcall(function()
game:GetService("StarterGui"):SetCore("SendNotification",{
Title=tostring(title or"通知"),
Text=tostring(desc or""),
Duration=tonumber(duration)or 3,
})
end)
end

local function uprightCFrame(hrp,cf)
local pos=cf.Position
local yRot=hrp and hrp.Orientation.Y or 0
return CFrame.new(pos)*CFrame.Angles(0,math.rad(yRot),0)
end

local function safeTeleport(cf)
local hrp=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
if hrp then
hrp.CFrame=uprightCFrame(hrp,cf)
task.wait(0.05)
if hrp.Position.Y<-100 then hrp.CFrame=uprightCFrame(hrp,cf)+Vector3.new(0,10,0)end
end
end

 lockPlayerConn=nil
local function unlockPlayer()
if lockPlayerConn then
lockPlayerConn:Disconnect()
lockPlayerConn=nil
end
end
local function lockPlayerAt(cf)
unlockPlayer()
local function hold()
local hrp=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
if hrp then
hrp.CFrame=uprightCFrame(hrp,cf)
hrp.Velocity=Vector3.new(0,0,0)
hrp.RotVelocity=Vector3.new(0,0,0)
end
end
hold()
lockPlayerConn=game:GetService("RunService").Heartbeat:Connect(hold)
end

local function carTeleport(cf)
if game.Players.LocalPlayer.Character then
local Character=game.Players.LocalPlayer.Character
if Character.Humanoid.SeatPart~=nil then
local Car=Character.Humanoid.SeatPart.Parent
spawn(function()
for i=1,5 do
wait()
Car:SetPrimaryPartCFrame(cf*CFrame.Angles(math.rad(Character.HumanoidRootPart.Orientation.x),math.rad(Character.HumanoidRootPart.Orientation.y),0))
game.ReplicatedStorage.Interaction.ClientRequestOwnership:FireServer(Car.Main)
game.ReplicatedStorage.Interaction.ClientIsDragging:FireServer(Car.Main)
end
end)
end
end
end

local function tp(pos)
local pos=pos or lp:GetMouse().Hit+Vector3.new(0,lp.Character.HumanoidRootPart.Size.Y,0)
if typeof(pos)=="CFrame"then
lp.Character:SetPrimaryPartCFrame(pos)
elseif typeof(pos)=="Vector3"then
lp.Character:MoveTo(pos)
end
end
local function droptool(cframe)
local tool=lp.Character:FindFirstChildOfClass("Tool")
if tool then tool.Parent=workspace;tool:SetPrimaryPartCFrame(cframe)end
end

local function saveDragConfig()
if writefile then
local content=tostring(dragAttempts)..":"..tostring(dragInterval)
local ok,err=pcall(writefile,CONFIG_FILE,content)
if ok then notify("雪糕","配置已保存",2)else notify("雪糕","保存失败: "..tostring(err),3)end
else
notify("雪糕","当前环境不支持保存配置",3)
end
end

-- ============================================================
-- 树木列表: 从 workspace.Stores.PlanterStore["Planter Spawner"].Amounts 自动读取
--
-- 原来这里是写死的一张中英对照表, 只有 66 条, 游戏后来新增的树就选不到了。
-- 现在改成运行时读取:
--   1) Amounts 里每个 NumberValue 的名字就是 TreeClass, 值是持有数量;
--   2) 里面混着 ChangeWood / Script 这两个 Script 实例, 必须过滤掉
--      (筛选条件就是"只要值类型的子节点", Script 不在其中);
--   3) 有中文译名的显示中文, 没译的直接显示英文原名, 照样能选;
--   4) 读不到时退回旧表, 保证列表不为空。
-- 实测该游戏 Amounts 里有 103 种, 比 ReplicatedStorage.Woods 的 90 种更全
-- (多出 BlueFlame / Bone / Crystal / Ethereal / Flame / Infernal 等)。
-- ============================================================
local TREE_CN={
Generic="普通树",GenericDead="枯木",GenericFall="落叶树",GenericGold="金树",GenericPrime="原始树",
GenericSpecial="特殊树",GoldSwampy="沼泽黄金",GreenSwampy="沼泽青",Cherry="樱花树",
CaveCrawler="蓝木",Cavern="洞窟紫木",CavernCrawler="洞窟爬虫",GrottoCrawler="洞穴爬虫",
TunnelCrawler="隧道爬虫",Frost="冰木",Volcano="火山木",Oak="橡木",Walnut="巧克力木",
Birch="白桦木",Aspen="白洋木",Koa="大巧克力树",Palm="椰子树",Pine="雪地松",Fir="冷杉木",
Maple="枫木",SnowGlow="黄金木",Snow="雪木",Ice="冰晶木",LoneCave="幻影木",
Spooky="幽灵木",SpookyNeon="南瓜木",SpookyGhoul="幽灵食尸者",CandycaneGhoul="拐杖糖幽灵木",
CandycaneHalloween="万圣节拐杖糖木",CandycaneNeonSpook="霓虹万圣节木",
Hell="地狱木",Infernal="炼狱木",Radioactive="辐射木",Magma="岩浆树",Skittles="糖果岩浆树",
Ember="余烬木",Celestial="裂纹木",Void="虚空木",Spirit="星空木",Star="星星木",Shine="红颜树",
Sky="天堂木",Rainbow="彩虹木",NeonRainbow="霓虹彩虹木",Electric="雷电木",Glass="玻璃木",
Taco="墨西哥木",Diamond="钻石木",Ruby="红宝石木",Copper="铜木",Silver="银木",Gold="金子木",
Stone="石头木",Marble="大理石木",Brick="砖头木",BrickDark="深色砖木",BrickAlternative="异形砖木",
CobbleStone="鹅卵石木",Cookie="曲奇木",Candy="糖果树",CandyNeon="霓虹糖果木",
CandycaneGreen="绿拐杖糖木",CandycaneRed="红拐杖糖木",CandyAlternitive="异界糖果木",
Cartoony="卡通木",CartoonyRainbow="彩虹卡通木",Dog="狗木",Lollipop="棒棒糖木",LollipopHead="棒棒糖头木",
Bush="灌木木",PotBush="花盆灌木",Potato="土豆木",Grass1="草木",Lavender="薰衣草木",
GlowShroom="发光蘑菇木",MuckySewer="下水道木",SewageTree="污水木",Blah="神秘木",Sign="告示牌木",
Thread="线轴木",Random="随机木",REEE="尖叫木",Test="测试木",Bone="骨头木",Crystal="水晶木",
Flame="火焰木",BlueFlame="蓝色火焰木",RainbowFlame="彩色火焰木",CrackedLava="裂隙岩浆木",
Ethereal="以太木",GreatOak="生命古橡",AppleWood="苹果木",Dry="干枯木",DryNeon="霓虹干枯木",
Sand="沙滩木",Virtual="虚拟木",Waffer="华夫木",PotBush2="花盆灌木2",
}

-- 旧版写死的对照表, 只在读不到 Amounts 时兜底
local TREE_FALLBACK={
["普通树"]="Generic",["沼泽黄金"]="GoldSwampy",["樱花"]="Cherry",["蓝木"]="CaveCrawler",
["冰木"]="Frost",["火山木"]="Volcano",["橡木"]="Oak",["巧克力木"]="Walnut",["白桦木"]="Birch",
["黄金木"]="SnowGlow",["雪地松"]="Pine",["僵尸木"]="GreenSwampy",["大巧克力树"]="Koa",
["椰子树"]="Palm",["幽灵木"]="Spooky",["南瓜木"]="SpookyNeon",["大理石木"]="Marble",
["天堂木"]="Sky",["虚拟木"]="Virtual",["玻璃木"]="Taco",["糖果树"]="CandycaneGreen",
["积木树"]="CandycaneRed",["发光红色糖果木"]="CandyNeon",["彩虹树"]="Rainbow",["雷电木"]="Electric",
["煤炭木"]="GenericDead",["岩浆树"]="Skittles",["紫木"]="Cavern",["下水道木"]="MuckySewer",
["辐射木"]="Radioactive",["地狱木"]="Hell",["沙滩木"]="Sand",["白洋木"]="Aspen",
["发光彩虹木"]="NeonRainbow",["狗木"]="Dog",["幻影木"]="LoneCave",["红颜树"]="Shine",
["石头木"]="Magma",["玻璃冰木"]="Ice",["砖头木"]="Blah",["卡通树"]="CobbleStone",
["曲奇树"]="Cookie",["生命树"]="GreatOak",["虚空木"]="Void",["裂纹木"]="Celestial",
["幽灵食尸者"]="SpookyGhoul",["生锈木"]="SewageTree",["金子木"]="Gold",["星空木"]="Spirit",
["火焰木"]="Flame",["蓝色火焰木"]="BlueFlame",["彩色火焰木"]="RainbowFlame",["星星木"]="Star",
["雪木"]="Snow",["冷杉木"]="Fir",
}

local function readTreeClasses()
local list={}
-- 首选: 花盆商店的 Amounts(最全, 103 种)
local amounts=ws:FindFirstChild("Stores")
and ws.Stores:FindFirstChild("PlanterStore")
and ws.Stores.PlanterStore:FindFirstChild("Planter Spawner")
and ws.Stores.PlanterStore["Planter Spawner"]:FindFirstChild("Amounts")
if amounts then
for _,c in ipairs(amounts:GetChildren())do
-- 只要值类型; 这里面混着 ChangeWood / Script 两个 Script 实例, 会被这行挡掉
if c:IsA("NumberValue")or c:IsA("IntValue")or c:IsA("StringValue")then
table.insert(list,tostring(c.Name))
end
end
end
-- 读不到或结果为空时, 退回 Woods
if #list==0 then
local W=rep:FindFirstChild("Woods")
if W then for _,c in ipairs(W:GetChildren())do table.insert(list,tostring(c.Name))end end
end
return list
end

local treeMapping={}
for _,cls in ipairs(readTreeClasses())do
-- 没写译名的直接用英文原名, 保证每个都选得到
treeMapping[TREE_CN[cls]or cls]=cls
end
if next(treeMapping)==nil then
for cn,cls in pairs(TREE_FALLBACK)do treeMapping[cn]=cls end
end
-- 兜底补两个最常用的, 防止下拉框里连普通树都没有
treeMapping["普通树"]=treeMapping["普通树"]or"Generic"
treeMapping["幻影木"]=treeMapping["幻影木"]or"LoneCave"

-- 这四种固定排在列表最前面, 其余按名称排序
local TREE_PRIORITY={"火焰木","石头木","蓝色火焰木","彩色火焰木"}

local function sortTreeNames(list)
local prio={}
for i,n in ipairs(TREE_PRIORITY)do prio[n]=i end
table.sort(list,function(a,b)
local pa,pb=prio[a],prio[b]
if pa and pb then return pa<pb end
if pa then return true end
if pb then return false end
return a<b
end)
end

local treeNames={}
for name in pairs(treeMapping)do table.insert(treeNames,name)end
sortTreeNames(treeNames)

local function getNextDragID()
bai.dragIDCounter=bai.dragIDCounter+1
return bai.dragIDCounter
end

local DRAG_TOTAL=60
local DRAG_SET_START=28
local DRAG_SET_COUNT=2
local DRAG_SET_INTERVAL=0.01
local DRAG_REFRESH_INTERVAL=0.01
local DRAG_AFTER_WAIT=0.01

local function dragToPosition(model,targetCF,callback,waitFinish)
if not model or not model.Parent then
if callback then callback()end
return
end
local primary=model.PrimaryPart or model:FindFirstChild("WoodSection")or model:FindFirstChild("Main")or model:FindFirstChildWhichIsA("BasePart")
if not primary then
if callback then callback()end
return
end
if not model.PrimaryPart then model.PrimaryPart=primary end

-- 【拖拽加固】开拖之前先把人锁在物品旁边。
-- 之前这里直接就 Begin, 假设调用方已经把人放到位。可一旦调用方漏了或中途被打断,
-- 客户端就拿不到网络所有权, 服务器会用权威位置覆盖客户端的位移 ——
-- 表现出来就是"东西有概率飞到其他地方", 或者压根拖不动。
-- lockPlayerAt 用 Heartbeat 每帧把人钉回原位, 是持续锁定而不是传送一下就完事。
-- 拖完函数自己解锁, 不影响调用方后面的 lockPlayerAt。
lockPlayerAt(primary.CFrame+Vector3.new(0,3,0))

local dragID=getNextDragID()
local remote=rep.Interaction.ClientIsDragging

pcall(function()rep.Interaction.ClientRequestOwnership:FireServer(primary)end)
pcall(function()remote:FireServer("Begin",model,dragID)end)

local lastSet=DRAG_SET_START+DRAG_SET_COUNT-1
for i=1,lastSet do
if not model.Parent or not model.PrimaryPart then
pcall(function()remote:FireServer("End",model,dragID)end)
if callback then callback()end
return
end
local shouldSet=(i>=DRAG_SET_START)
pcall(function()
remote:FireServer("Refresh",model,dragID)
if shouldSet then
rep.Interaction.ClientRequestOwnership:FireServer(primary)
model:SetPrimaryPartCFrame(targetCF)
end
end)
if i<lastSet then
if shouldSet then
task.wait(DRAG_SET_INTERVAL)
else
task.wait(DRAG_REFRESH_INTERVAL)
end
end
end

task.wait(DRAG_AFTER_WAIT)

local dragEnded=false
task.spawn(function()
for i=lastSet+1,DRAG_TOTAL do
if not model.Parent or not model.PrimaryPart then break end
pcall(function()remote:FireServer("Refresh",model,dragID)end)
if i<DRAG_TOTAL then
task.wait(DRAG_REFRESH_INTERVAL)
end
end
pcall(function()remote:FireServer("End",model,dragID)end)
dragEnded=true
end)

if waitFinish then
local w=0
while w<1.5 and not dragEnded do
task.wait(0.05)
w=w+0.05
end
for retry=1,3 do
if not model.Parent or not model.PrimaryPart then break end
local d=(model.PrimaryPart.Position-targetCF.Position).Magnitude
if d<=3 then break end
pcall(function()remote:FireServer("Refresh",model,dragID)end)
end
end

-- 【拖拽加固】到位校验。
-- 上面那段只在 waitFinish 为真时才跑, 而多数调用方传的是 false/nil。
-- 这里统一兜底: 等拖拽线程收尾后看东西是否真的落到目标附近,
-- 差得远说明这次没拖住(所有权没拿到 / 被服务器位置覆盖), 重新锁回物品旁补一次。
-- 这正是"东西有概率飞到其他地方"最直接的补救。
task.wait(0.4)
local verify=0
while model.Parent and model.PrimaryPart and verify<2 do
local dist=(model.PrimaryPart.Position-targetCF.Position).Magnitude
if dist<=3 then break end
verify=verify+1
lockPlayerAt(primary.CFrame+Vector3.new(0,3,0))
task.wait(0.15)
local retryID=getNextDragID()
pcall(function()rep.Interaction.ClientRequestOwnership:FireServer(primary)end)
pcall(function()remote:FireServer("Begin",model,retryID)end)
for _=1,10 do
if not model.Parent then break end
pcall(function()rep.Interaction.ClientRequestOwnership:FireServer(primary)end)
pcall(function()remote:FireServer("Refresh",model,retryID)end)
pcall(function()model:SetPrimaryPartCFrame(targetCF)end)
task.wait(0.05)
end
pcall(function()remote:FireServer("End",model,retryID)end)
task.wait(0.15)
end

-- 解锁, 交还给调用方(比如购买流程会在之后 lockPlayerAt 到柜台)
unlockPlayer()

if callback then callback()end
end

-- ============================================================
-- 卖木头 / 卖木板
-- 卖点坐标用的是原版伐木大亨的卖货区(WoodRUs 熔炉滚筒旁), 实测该位置有效。
-- 搬运完全走本脚本自己的 dragToPosition, 不另外造轮子。
-- ============================================================
local SELL_CF=CFrame.new(314.508514,-0.303692758,86.5952911,0.999575555,-2.51872869e-08,
-0.0291328784,2.55842831e-08,1,1.32543034e-08,0.0291328784,-1.39940219e-08,0.999575555)

local sellStopFlag=false

-- 是不是我自己的原木(地上散落的 Loose_ 木头)
local function isMyLog(m)
if not m or not m:IsA("Model")then return false end
local owner=m:FindFirstChild("Owner")
if not owner or owner.Value~=lp then return false end
local tc=m:FindFirstChild("TreeClass")
return tc~=nil
end

-- 是不是我自己的木板。这个 mod 没有 PlankModels 文件夹, 木板是购买后生成在
-- PlayerModels 里的普通物品, 所以按 Type/名字判断, 不写死路径。
local function isMyPlank(m)
if not m or not m:IsA("Model")then return false end
local owner=m:FindFirstChild("Owner")
if not owner or owner.Value~=lp then return false end
local ty=m:FindFirstChild("Type")
if ty and string.lower(tostring(ty.Value))=="plank"then return true end
local pn=m:FindFirstChild("PurchasedBoxItemName")or m:FindFirstChild("ItemName")
if pn and string.find(string.lower(tostring(pn.Value)),"plank")then return true end
return string.find(string.lower(m.Name),"plank")~=nil
end

-- 收集要卖的模型
local function collectSellTargets(kind)
local list={}
local seen={}
local function push(m)
if m and not seen[m]then seen[m]=true table.insert(list,m)end
end
if kind=="wood"then
local lm=ws:FindFirstChild("LogModels")
if lm then for _,m in pairs(lm:GetChildren())do if isMyLog(m)then push(m)end end end
else
local pm=ws:FindFirstChild("PlayerModels")
if pm then for _,m in pairs(pm:GetChildren())do if isMyPlank(m)then push(m)end end end
end
return list
end

-- 把一个模型拖到卖点并等它被卖掉
local function sellOne(m)
local primary=m.PrimaryPart or m:FindFirstChild("WoodSection")or m:FindFirstChild("Main")
or m:FindFirstChildWhichIsA("BasePart",true)
if not primary then return false end
if not m.PrimaryPart then m.PrimaryPart=primary end

-- 1) 锁在物品上方, 而且要"一直锁"而不是传送一下就完事。
--    safeTeleport 是一次性的, 人一走动就丢掉网络所有权, 服务器不再跟随,
--    模型就再也拖不回来。lockPlayerAt 用 Heartbeat 每帧把人钉回原位, 全程不能解锁。
lockPlayerAt(primary.CFrame+Vector3.new(0,3,0))
task.wait(0.2)
if sellStopFlag then unlockPlayer() return false end

-- 2) 保持锁定的前提下开始拖。
--    waitFinish 必须传 false: 传 true 时 dragToPosition 会在发出 "End" 之后
--    再额外做 3 轮 Refresh + SetPrimaryPartCFrame, 视觉上就是"拖了两次",
--    而且那些 Refresh 发生在 End 之后, 服务端可能当成又开了一次新拖拽。
--    不传时主循环本身已经把模型稳定送到落点(第 28 帧起持续 Set)。
local target=SELL_CF+Vector3.new(0,1.5,0)
dragToPosition(m,target,nil,false)

-- 3) dragToPosition 结束时会自己解锁, 这里把锁挪到卖点:
--    成交要在卖点附近才判定, 和购买流程"拖完锁到柜台"是同一个道理
lockPlayerAt(SELL_CF+Vector3.new(0,3,0))
task.wait(1)
local deadline=os.clock()+2
repeat
if not m.Parent then return true end
task.wait(0.1)
until os.clock()>=deadline
unlockPlayer()
return m.Parent==nil
end

local function sellKind(kind,label)
if sellStopFlag then return 0 end
local list=collectSellTargets(kind)
if #list==0 then notify("雪糕","没有可卖的"..label,3) return 0 end
notify("雪糕","开始卖"..label.." 共"..#list.."个",3)

-- 记下原来的位置, 卖完送回去(和"传送物品"一样)
local hrp=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
local originalPos=hrp and hrp.CFrame

local sold=0
for i,m in ipairs(list)do
if sellStopFlag then break end
if m.Parent then
-- pcall 的第一个返回值是"有没有报错", 不是 sellOne 的返回值。
-- 原来直接 if ok then 当成卖出成功, 等于把"报错"算成"卖掉了", 计数一直是错的。
local callOk,success=pcall(sellOne,m)
if callOk and success then sold=sold+1 end
end
task.wait(0.1)
end

unlockPlayer()
if originalPos and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")then
pcall(function()safeTeleport(originalPos)end)
end
notify("雪糕","卖出"..label.." "..sold.."/"..#list,3)
return sold
end

function sellAllWood() sellStopFlag=false return sellKind("wood","木头")end
function sellAllPlanks() sellStopFlag=false return sellKind("plank","木板")end
function sellWoodAndPlanks() sellStopFlag=false
sellKind("wood","木头")
sellKind("plank","木板")
end
function stopSelling() sellStopFlag=true unlockPlayer()end

-- 3829 行那个按钮引用的函数全文没有定义, 点一下就报错, 这里补上
function bringAllMyLogsToFeet()
local list=collectSellTargets("wood")
if #list==0 then notify("雪糕","你身上没有木头",3) return end
local hrp=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
local originalPos=hrp and hrp.CFrame
notify("雪糕","正在把"..#list.."根木头拉过来",3)
for _,m in ipairs(list)do
local p=m.PrimaryPart or m:FindFirstChild("WoodSection")
if p then
-- 同样必须全程锁定, 人一跑掉就拿不到网络所有权, 木头拖不动回来
lockPlayerAt(p.CFrame+Vector3.new(0,3,0))
task.wait(0.15)
dragToPosition(m,(hrp and hrp.CFrame or p.CFrame)+Vector3.new(0,2,0),nil,false)
end
task.wait(0.05)
end
unlockPlayer()
if originalPos and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")then
pcall(function()safeTeleport(originalPos)end)
end
notify("雪糕","已拉过来",3)
end

local function findUncutTree(treeClass)
local playerPos=lp.Character and lp.Character.HumanoidRootPart.Position
if not playerPos then return nil end
local nearestDist,nearestWood,nearestTree=math.huge,nil,nil
for _,region in pairs(ws:GetChildren())do
if region.Name=="TreeRegion"then
for _,tree in pairs(region:GetChildren())do
if tree:IsA("Model")and tree:FindFirstChild("TreeClass")and tree.TreeClass.Value==treeClass then
local woodSections={}
for _,child in pairs(tree:GetChildren())do
if child.Name=="WoodSection"and child:IsA("BasePart")then table.insert(woodSections,child)end
end
if#woodSections>=2 then
local dist=(woodSections[1].Position-playerPos).Magnitude
if dist<nearestDist then nearestDist,nearestWood,nearestTree=dist,woodSections[1],tree end
end
end
end
end
end
return nearestWood,nearestTree
end

local axeConfigCache={}

local function loadWeaponConfig(weaponName)
if axeConfigCache[weaponName]~=nil then
return axeConfigCache[weaponName]
end

if weaponName=="OlReliable"or weaponName=="OIReliable"then
local playerName=lp.Name
local override=nil

local wsTool=workspace:FindFirstChild(playerName)
if wsTool then
wsTool=wsTool:FindFirstChild("Tool")
if wsTool then
local toolName=wsTool:FindFirstChild("ToolName")
if toolName then
local val=tostring(toolName.Value)
if val=="OlReliable"or val=="OIReliable"then
override=wsTool:FindFirstChild("AxeClassDamageOverride")
end
end
end
end

if not override then
local backpack=lp:FindFirstChild("Backpack")
if backpack then
for _,tool in pairs(backpack:GetChildren())do
if tool:IsA("Tool")then
local toolName=tool:FindFirstChild("ToolName")
if toolName then
local val=tostring(toolName.Value)
if val=="OlReliable"or val=="OIReliable"then
override=tool:FindFirstChild("AxeClassDamageOverride")
if override then
break
end
end
end
end
end
end
end

if override then
local config={
Damage=nil,
SwingCooldown=nil,
Range=nil,
SpecialTrees={},
}

local attrs=override:GetAttributes()
for key,value in pairs(attrs)do
if key=="Damage"then
config.Damage=value
elseif key=="SwingCooldown"then
config.SwingCooldown=value
elseif key=="Range"then
config.Range=value
else
config.SpecialTrees[key]={Damage=value}
end
end

for _,child in pairs(override:GetChildren())do
if child:IsA("NumberValue")or child:IsA("IntValue")then
if child.Name=="Damage"then
config.Damage=child.Value
elseif child.Name=="SwingCooldown"then
config.SwingCooldown=child.Value
elseif child.Name=="Range"then
config.Range=child.Value
else
config.SpecialTrees[child.Name]={Damage=child.Value}
end
end
end

if config.Damage or config.SwingCooldown or next(config.SpecialTrees)then
axeConfigCache[weaponName]=config
return config
end
end
end

-- ============================================================
-- 斧头数值: 全部从游戏自己的模块源码里解析, 不再依赖任何硬编码
--
-- 为什么必须这样: ModuleScript.Source 在客户端恒为空(实测全部为 0),
-- 而 require(AxeClass_*) 会因为 "Cannot require a RobloxScript module from a
-- non RobloxScript context" 失败(loadstring 出来的 chunk 属于非 RobloxScript 上下文)。
-- 真正能读到源码的是执行器提供的 decompile —— Dex++ 的"查看脚本"用的也是它。
-- 所以这里: 反编译 -> 正则解析 Damage / Range / SwingCooldown / SpecialTrees。
-- 游戏改了数值, 脚本自动跟上, 不用改代码。
-- ============================================================
local function decompileSafe(script)
if not script then return nil end
if type(decompile)=="function" then
local ok,src=pcall(decompile,script)
if ok and type(src)=="string" and #src>0 then return src end
end
if type(getscriptbytecode)=="function" then
-- 没有 decompile 时只能拿字节码, 至少保证不是静默失败
local ok,bc=pcall(getscriptbytecode,script)
if ok and type(bc)=="string" then return bc end
end
return nil
end

-- 解析 "v3.Damage = 1.45" / "Damage = 1.45" 这类赋值, 支持负数
local function parseNum(src,key)
local v=src:match("[%w_%.]+%.?"..key.."%s*=%s*([%-]?[%d%.]+)")
if not v then v=src:match(key.."%s*=%s*([%-]?[%d%.]+)") end
return tonumber(v)
end

-- 解析 SpecialTrees: 支持 {A={Damage=1, SwingCooldown=2}} 和 [\"A\"]={...} 两种写法
local function parseSpecialTrees(src)
local out={}
for treeName,treeBody in src:gmatch("SpecialTrees%.([%w_]+)%s*=%s*{(.-)}")do
local cfg={}
cfg.Damage=tonumber(treeBody:match("Damage%s*=%s*([%-]?[%d%.]+)"))
cfg.SwingCooldown=tonumber(treeBody:match("SwingCooldown%s*=%s*([%-]?[%d%.]+)"))
if cfg.Damage then out[treeName]=cfg end
end
return out
end

-- 在全游戏已加载的模块 + LoadedAssets 里找 <weaponName>AxeClass
local function findAxeModule(weaponName)
local want=weaponName.."AxeClass"
local la=game:GetService("ReplicatedStorage"):FindFirstChild("LoadedAssets")
if la then
local m=la:FindFirstChild(want)
if m then return m end
end
if type(getloadedmodules)=="function" then
for _,m in ipairs(getloadedmodules())do
if m:IsA("ModuleScript") and (m.Name==want or m:GetFullName():sub(-#want)==want)then
return m
end
end
end
-- 兜底: 扫 AxeModules 之类的文件夹
for _,root in ipairs({game:GetService("ReplicatedStorage")})do
for _,d in ipairs(root:GetChildren())do
if d:IsA("Folder")or d:IsA("Model")then
local m=d:FindFirstChild(want,true)
if m then return m end
end
end
end
return nil
end

-- 向服务器请求斧头资源(不同版本远程名字不一样, 都试一遍, 失败无所谓)
local function requestAxeAsset(weaponName)
local rs=game:GetService("ReplicatedStorage")
local tries={
{rs:FindFirstChild("RemoteEvents"),"AssetRequests","RequestAssetInfo"},
{rs:FindFirstChild("RemoteEvents"),"AssetRequests","RequestAxeClass"},
{rs, "LoadedAssets","RequestAssetInfo"},
}
for _,t in ipairs(tries)do
local root,folder,fn=t[1],t[2],t[3]
if root then
local f=root:FindFirstChild(folder)
local rf=f and f:FindFirstChild(fn)
if rf then
pcall(function() rf:InvokeServer(weaponName,"Tools","AxeClass",nil) end)
pcall(function() rf:FireServer(weaponName,"Tools","AxeClass") end)
return true
end
end
end
return false
end

local function readWeaponConfig(weaponName)
-- 1) 直接找模块
local module=findAxeModule(weaponName)
-- 2) 没有就请求一次, 服务器异步克隆, 轮询等待
if not module then
requestAxeAsset(weaponName)
local deadline=os.clock()+3
repeat
module=findAxeModule(weaponName)
if module then break end
task.wait(0.15)
until os.clock()>=deadline
end
if not module then return nil end

local src=decompileSafe(module)
if not src then return nil end

local cfg={
Damage=parseNum(src,"Damage"),
SwingCooldown=parseNum(src,"SwingCooldown"),
Range=parseNum(src,"Range"),
SpecialTrees=parseSpecialTrees(src),
}
if not cfg.Damage or not cfg.SwingCooldown then return nil end
cfg.Range=cfg.Range or 10
return cfg
end

local config=readWeaponConfig(weaponName)
if not config then
axeConfigCache[weaponName]=nil
return nil
end

axeConfigCache[weaponName]=config
return config
end

local function selectBestWeapon(treeClass)
local toolFolder=lp:FindFirstChild("ToolFolder")
if not toolFolder then return nil,nil,"未找到 ToolFolder"end
local bestWeapon,bestDamage,bestConfig=nil,-1,nil
for _,child in pairs(toolFolder:GetChildren())do
local config=loadWeaponConfig(child.Name)
if config then
local damage=(config.SpecialTrees[treeClass]and config.SpecialTrees[treeClass].Damage)or config.Damage
if damage>bestDamage then bestWeapon,bestDamage,bestConfig=child.Name,damage,config end
end
end
return bestWeapon,bestConfig,bestDamage
end
local function getTreeTopCFrame(treeModel)
local topY=-math.huge
local topCF=nil
for _,child in pairs(treeModel:GetChildren())do
if child:IsA("BasePart")then
local top=child.Position.Y+child.Size.Y/2
if top>topY then
topY=top
topCF=CFrame.new(child.Position.X,top+2,child.Position.Z)
end
end
end
if not topCF then
topCF=treeModel:GetPivot()+Vector3.new(0,2,0)
end
return topCF
end

local function bringTreeRemote(treeClass)
local weaponName,weaponConfig,damage=selectBestWeapon(treeClass)
if not weaponName then notify("雪糕","自动选武器失败",3)return false end

local req={
Flame=200000,
BlueFlame=200000,
Celestial=200000,
Void=200000,
Ice=200000,
Magma=200000,
RainbowFlame=200000,
Radioactive=200000,
Shine=200000,
LoneCave=200000,
Spirit=200000,
}
if req[treeClass]and damage<req[treeClass]then
notify("雪糕",string.format("伤害不足！需要至少 %.0f",req[treeClass]),4)
return false
end
local cooldown=(weaponConfig.SpecialTrees[treeClass]and weaponConfig.SpecialTrees[treeClass].SwingCooldown)or weaponConfig.SwingCooldown

local woodSec,tree=findUncutTree(treeClass)
if not woodSec then notify("雪糕","附近没有可砍的树",3)return false end

local minX,maxX=-543,-27.8
local minY,maxY=-196.7,-148.2
local minZ,maxZ=-2961.7,-2668.7

local treePos=woodSec.Position
if treePos.X>=minX and treePos.X<=maxX and
treePos.Y>=minY and treePos.Y<=maxY and
treePos.Z>=minZ and treePos.Z<=maxZ then
notify("雪糕","树在危险区域内，已删除",5)
if tree and tree.Parent then
tree:Destroy()
end
return false
end

local tool=lp.Character and lp.Character:FindFirstChildOfClass("Tool")
if not tool then
local toolFolder=lp:FindFirstChild("ToolFolder")
if toolFolder then
local weaponObj=toolFolder:FindFirstChild(weaponName)
tool=weaponObj and(weaponObj:IsA("Tool")and weaponObj or weaponObj.Value)or nil
end
end
if not tool then notify("雪糕","未找到工具: "..weaponName,3)return false end

local cutEvent=tree:FindFirstChild("CutEvent")
if not cutEvent then notify("雪糕","无法获取CutEvent",3)return false end
local remote=rep:WaitForChild("Interaction"):WaitForChild("RemoteProxy")

local playerOriginalCF=lp.Character and lp.Character.HumanoidRootPart.CFrame
if not playerOriginalCF then notify("雪糕","无法获取玩家位置",3)return false end

local platformPos=woodSec.CFrame+Vector3.new(8,2.5,0)
local platformPos=woodSec.Position+Vector3.new(8,2.5,0)
local tempPart=Instance.new("Part")
tempPart.Name="TempMarker"
tempPart.Anchored=true
tempPart.CanCollide=true
tempPart.Shape=Enum.PartType.Block
tempPart.Size=Vector3.new(0.001,0.0001,0.0001)
tempPart.Color=Color3.fromRGB(255,0,0)
tempPart.Material=Enum.Material.Neon
tempPart.CFrame=CFrame.new(platformPos)
tempPart.Parent=workspace

task.wait(0.02)

lockPlayerAt(getTreeTopCFrame(tree))

local fallenLog,existingLogs=nil,{}
for _,log in pairs(ws.LogModels:GetChildren())do existingLogs[log]=true end
local treeCenter=woodSec.Position
local stopCutting,timeoutReached=false,false

local sendTask=task.spawn(function()
while not stopCutting do
pcall(remote.FireServer,remote,cutEvent,{height=0.3,faceVector=Vector3.new(-1,0,0),cooldown=cooldown,sectionId=1,hitPoints=damage,tool=tool,cuttingClass="Axe"})
task.wait(0.0001)
end
end)

local timeoutTask=task.spawn(function()
task.wait(15)
if not stopCutting then timeoutReached=true;stopCutting=true end
end)

while not fallenLog and not stopCutting do
for _,log in pairs(ws.LogModels:GetChildren())do
if not existingLogs[log]and log:FindFirstChild("Owner")and log.Owner.Value==lp and log:FindFirstChild("TreeClass")and log.TreeClass.Value==treeClass then
if(log:GetPivot().Position-treeCenter).Magnitude<100 then
fallenLog=log;break
end
end
end
task.wait(0.01)
end

stopCutting=true;task.cancel(sendTask);task.cancel(timeoutTask)

if timeoutReached or not fallenLog then
unlockPlayer()
notify("雪糕","砍树超时或木头未掉落",3)
if tempPart and tempPart.Parent then tempPart:Destroy()end
safeTeleport(playerOriginalCF)
return false
end

local primary=fallenLog.PrimaryPart or fallenLog:FindFirstChild("WoodSection")or fallenLog:FindFirstChild("Main")or fallenLog:FindFirstChildWhichIsA("BasePart")
if not primary then
unlockPlayer()
notify("雪糕","无法定位木头",3)
if tempPart and tempPart.Parent then tempPart:Destroy()end
safeTeleport(playerOriginalCF)
return false
end

local logPos=primary.Position
if logPos.X>=minX and logPos.X<=maxX and
logPos.Y>=minY and logPos.Y<=maxY and
logPos.Z>=minZ and logPos.Z<=maxZ then
unlockPlayer()
notify("雪糕","木头掉落在危险区域，已删除",5)
if fallenLog and fallenLog.Parent then
fallenLog:Destroy()
end
if tempPart and tempPart.Parent then tempPart:Destroy()end
safeTeleport(playerOriginalCF)
return false
end

if not fallenLog.PrimaryPart then fallenLog.PrimaryPart=primary end

lockPlayerAt(primary.CFrame+Vector3.new(0,3,0))

local done=false
dragToPosition(
fallenLog,
playerOriginalCF,
function()
unlockPlayer()
safeTeleport(playerOriginalCF)
if tempPart and tempPart.Parent then tempPart:Destroy()end
done=true
end,
10,
nil
)

while not done do
task.wait(0.01)
end

return true
end

 selectedTree=nil
 selectedSawmill=nil
 sawPos=nil
 isDecomposeActive=false
 decomposeConn=nil

local function safeTeleportNoWait(cf)
local hrp=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
if hrp then
hrp.CFrame=uprightCFrame(hrp,cf)
if hrp.Position.Y<-100 then
hrp.CFrame=uprightCFrame(hrp,cf)+Vector3.new(0,10,0)
end
end
end

local function getBestAxeData(treeClass)
local toolFolder=lp:FindFirstChild("ToolFolder")
if not toolFolder then
return nil,nil,"未找到 ToolFolder"
end
local bestWeaponName,bestDamage,bestConfig=nil,-1,nil
for _,child in pairs(toolFolder:GetChildren())do
local config=loadWeaponConfig(child.Name)
if config then
local damage=config.Damage or 0
if treeClass and config.SpecialTrees and config.SpecialTrees[treeClass]then
damage=config.SpecialTrees[treeClass].Damage or damage
end
if damage>bestDamage then
bestDamage=damage
bestWeaponName=child.Name
bestConfig=config
end
end
end
if not bestWeaponName then
return nil,nil,"未找到可用的斧头配置"
end
local toolObj=toolFolder:FindFirstChild(bestWeaponName)
local tool=toolObj and(toolObj:IsA("Tool")and toolObj or toolObj.Value)
if not tool then
return nil,nil,"无法获取工具实例"
end
return tool,bestConfig,nil
end

local function getTreeClassFromModel(treeModel)
local tc=treeModel:FindFirstChild("TreeClass")
if tc then return tc.Value end
local name=treeModel.Name
for _,suffix in ipairs({"SpookyNeon","Spooky","GoldSwampy","Cherry","CaveCrawler","MuckySewer"})do
if name:find(suffix)then return suffix end
end
return"Generic"
end
local function forceDragUntilProcessed(model,targetCF,timeout)
timeout=timeout or 3
if not model or not model.Parent then return false end
local primary=model.PrimaryPart or model:FindFirstChild("WoodSection")or model:FindFirstChild("Main")or model:FindFirstChildWhichIsA("BasePart")
if not primary then return false end
if not model.PrimaryPart then model.PrimaryPart=primary end

local done=false
dragToPosition(model,targetCF,function()
done=true
end)

local startTime=tick()
while not done and tick()-startTime<timeout do
task.wait(0.01)
end
return done
end

local function decomposeAndProcess(treeModel,sawmill,sawmillPos)

if not sawmillPos then
notify("雪糕","锯木机位置无效，请重新选择锯木机",3)
return
end
_G.stopDrag=false

local sections={}
local rootSection=nil
for _,child in pairs(treeModel:GetChildren())do
if child.Name=="WoodSection"and child:IsA("BasePart")and child:FindFirstChild("ID")then
local id=child.ID.Value
if id>=2 then
table.insert(sections,{id=id,part=child})
elseif id==1 then
rootSection=child
end
end
end
if#sections==0 then
notify("雪糕","该树没有可分解的部分（ID≥2）",3)
return
end
table.sort(sections,function(a,b)return a.id>b.id end)

local cutEvent=treeModel:FindFirstChild("CutEvent")
if not cutEvent then
notify("雪糕","该模型没有 CutEvent",3)
return
end

local treeClass=getTreeClassFromModel(treeModel)
local weaponName,weaponConfig,err=selectBestWeapon(treeClass)
if not weaponName then
notify("雪糕","自动选武器失败: "..(err or""),3)
return
end

local tool=lp.Character and lp.Character:FindFirstChildOfClass("Tool")
if not tool then
local toolFolder=lp:FindFirstChild("ToolFolder")
if toolFolder then
local weaponObj=toolFolder:FindFirstChild(weaponName)
tool=weaponObj and(weaponObj:IsA("Tool")and weaponObj or weaponObj.Value)or nil
end
end
if not tool then
notify("雪糕","未找到工具: "..weaponName,3)
return
end

local damage=weaponConfig and weaponConfig.Damage or 10000
local cooldown=weaponConfig and weaponConfig.SwingCooldown or 0.3
if weaponConfig and weaponConfig.SpecialTrees and weaponConfig.SpecialTrees[treeClass]then
damage=weaponConfig.SpecialTrees[treeClass].Damage or damage
cooldown=weaponConfig.SpecialTrees[treeClass].SwingCooldown or cooldown
end

local req={
Flame=200000,BlueFlame=200000,Celestial=200000,Void=200000,
Ice=200000,Magma=200000,RainbowFlame=200000,Radioactive=200000,
Shine=200000,LoneCave=200000,Spirit=200000,
}
if req[treeClass]and damage<req[treeClass]then
notify("雪糕",string.format("伤害不足！需要至少 %.0f，当前 %.0f",req[treeClass],damage),4)
return
end

local remote=rep:WaitForChild("Interaction"):WaitForChild("RemoteProxy")
local playerOriginalCF=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart").CFrame
if not playerOriginalCF then
notify("雪糕","无法获取玩家位置",3)
return
end

local initialLogs={}
for _,log in pairs(ws.LogModels:GetChildren())do
initialLogs[log]=true
end

local tasks={}
notify("雪糕",string.format("开始分解 %d 个部分",#sections),2)

for _,sec in ipairs(sections)do
local part=sec.part
local sectionId=sec.id
local stopFlag=false
local taskId=task.spawn(function()
while not stopFlag do
pcall(remote.FireServer,remote,cutEvent,{
height=0.11,
faceVector=Vector3.new(-1,0,0),
cooldown=cooldown,
sectionId=sectionId,
hitPoints=damage,
tool=tool,
cuttingClass="Axe"
})
task.wait(0.01)
if not part or not part.Parent then
break
end
end
end)
tasks[taskId]=true
end

local function hasHighIDSections()
for _,child in pairs(treeModel:GetChildren())do
if child.Name=="WoodSection"and child:FindFirstChild("ID")then
local id=child.ID.Value
if id>=2 then return true end
end
end
return false
end

local startTime=tick()
while hasHighIDSections()and tick()-startTime<10 do
task.wait(0.01)
end
for taskId in pairs(tasks)do
task.cancel(taskId)
end

if hasHighIDSections()then
notify("雪糕","砍树超时",3)
return
end

local allLogs={}
for _,log in pairs(ws.LogModels:GetChildren())do
if not initialLogs[log]and log:FindFirstChild("Owner")and log.Owner.Value==lp then
table.insert(allLogs,log)
end
end
if#allLogs==0 then
notify("雪糕","未找到木头",3)
return
end

local pos=sawmillPos.p+sawmillPos:VectorToWorldSpace(Vector3.new(0.7,0,0))

local targetPos=CFrame.new(pos)*(sawmillPos-sawmillPos.p)*CFrame.Angles(math.rad(-90),math.rad(90),0)
local allModels={}
for _,log in ipairs(allLogs)do
if log and log.Parent then table.insert(allModels,log)end
end
for _,entry in ipairs(allRootEntries or{})do
if entry.model and entry.model.Parent then
if not entry.model.PrimaryPart then entry.model.PrimaryPart=entry.root end
table.insert(allModels,entry.model)
end
end
if rootSection and rootSection.Parent then
if not treeModel.PrimaryPart then
treeModel.PrimaryPart=rootSection
end
table.insert(allModels,treeModel)
end

for _,model in ipairs(allModels)do
if model and model.Parent then
local primary=model.PrimaryPart or model:FindFirstChild("WoodSection")or model:FindFirstChild("Main")or model:FindFirstChildWhichIsA("BasePart")
if primary then
if not model.PrimaryPart then
model.PrimaryPart=primary
end
safeTeleport(primary.CFrame+Vector3.new(0,2,0))
task.wait(0.06)
dragToPosition(model,targetPos)
end
end
end

notify("雪糕","所有木头和树根已拖拽完成",3)
end

local function startDecomposeSelection()
if isDecomposeActive then
notify("雪糕","分解选择已激活，请先完成或取消",2)
return
end

if not bai.cachedSawmill or not bai.cachedSawmill.Parent then
notify("雪糕","请先使用 '选择锯木机' 按钮设置一个锯木机",3)
return
end
if not bai.cachedSawmillPos then
notify("雪糕","锯木机位置无效，请重新选择",3)
return
end

isDecomposeActive=true
selectedTree=nil
selectedSawmill=nil
sawPos=nil

notify("雪糕","请点击一棵树（将使用已记忆的锯木机）",3)

decomposeConn=mouse.Button1Down:Connect(function()
local target=mouse.Target
if not target then
notify("雪糕","未选中任何物体",2)
return
end

local model=target:FindFirstAncestorOfClass("Model")
if not model then
notify("雪糕","请点击树的树干",2)
return
end

local isTree=false
local hasWood=false
for _,child in pairs(model:GetChildren())do
if child.Name=="WoodSection"then
hasWood=true
end
end
if hasWood and model:FindFirstChild("CutEvent")then
isTree=true
end

if not isTree then
notify("雪糕","这不是一棵树，请点击树干",2)
return
end

selectedTree=model
selectedSawmill=bai.cachedSawmill
sawPos=bai.cachedSawmillPos
if decomposeConn then
decomposeConn:Disconnect()
decomposeConn=nil
end
isDecomposeActive=false
notify("雪糕","已选中树，开始分解...",3)
task.spawn(function()
decomposeAndProcess(selectedTree,selectedSawmill,sawPos)
selectedTree=nil
selectedSawmill=nil
sawPos=nil
end)
end)
end

 autoDeleteRunning=false
 autoDeleteTask=nil

local function deleteLavaObjectsOnce(silent)
local count=0
local target1=workspace:FindFirstChild("HLArea")and workspace.HLArea:FindFirstChild("Model")and workspace.HLArea.Model:FindFirstChild("LavaKillingPart")
if target1 then pcall(function()target1:Destroy()end);count=count+1 end
local plainsMaze=workspace:FindFirstChild("PlainsMaze")
if plainsMaze then
local function searchAndDestroy(parent)
for _,child in pairs(parent:GetChildren())do
local lavaScript=child:FindFirstChild("Lava")
if lavaScript and(lavaScript:IsA("Script")or lavaScript:IsA("LocalScript"))then
pcall(function()child:Destroy()end);count=count+1
else
if child:IsA("Model")or child:IsA("Folder")or child:IsA("BasePart")then searchAndDestroy(child)end
end
end
end
searchAndDestroy(plainsMaze)
end
if count>0 and not silent then notify("雪糕","已删除 "..count.." 个岩浆对象",2)end
return count
end

local function startAutoDelete(interval)
if autoDeleteRunning then return end
autoDeleteRunning=true
autoDeleteTask=task.spawn(function()
while autoDeleteRunning do deleteLavaObjectsOnce(true);task.wait(interval)end
end)
notify("雪糕","已开启自动删除（每 "..(interval).." 秒检查一次）",3)
end

local function stopAutoDelete()
if not autoDeleteRunning then return end
autoDeleteRunning=false
if autoDeleteTask then task.cancel(autoDeleteTask);autoDeleteTask=nil end
notify("雪糕","已关闭自动删除",3)
end

local function executeSequenceAndReturn()
local char=lp.Character
local hrp=char and char:FindFirstChild("HumanoidRootPart")

if not hrp then
return
end

local oldCF=hrp.CFrame

notify("雪糕","执行天使序列...",4)

safeTeleport(CFrame.new(184,12,-2666))

task.wait(0.2)

local controller=ws
:WaitForChild("Stores")
:WaitForChild("PlantomicsChoice")
:WaitForChild("Parts")
:WaitForChild("Controller")
:WaitForChild("yes")

local sequence={
"Up",
"Up",
"Down",
"Down",
"Left",
"Right",
"Left",
"Right",
"B",
"A",
"Start"
}

for _,name in ipairs(sequence)do

local part=controller:FindFirstChild(name)

if not part then
continue
end

local click=part:FindFirstChildOfClass("ClickDetector")

if not click then
continue
end

fireclickdetector(click,1)

task.wait(0.2)
end

safeTeleport(oldCF)

notify("雪糕","序列完成",3)
end
local function bringDuck(duckName,ownOnly,mode)

local ducks={}
for _,model in pairs(ws.PlayerModels:GetChildren())do
if model:IsA("Model")and model.Name==duckName then
local owner=model:FindFirstChild("Owner")
if(ownOnly and owner and owner.Value==lp)or(not ownOnly and(not owner or owner.Value==nil))then
table.insert(ducks,model)
end
end
end
if#ducks==0 then
notify("雪糕",ownOnly and"你没有该鸭子"or"没有无归属的该鸭子",3)
return
end

local selected
if mode=="random"then
selected=ducks[math.random(#ducks)]
else
if not duckCycleIndex[duckName]then duckCycleIndex[duckName]=1 end
selected=ducks[duckCycleIndex[duckName]]
duckCycleIndex[duckName]=duckCycleIndex[duckName]%#ducks+1
end

local originalPos=lp.Character and lp.Character.HumanoidRootPart.CFrame
if not originalPos then return end
local primary=selected.PrimaryPart or selected:FindFirstChild("Main")or selected:FindFirstChildWhichIsA("BasePart")
if not primary then notify("雪糕","无法定位鸭子",3)return end
if not selected.PrimaryPart then selected.PrimaryPart=primary end
safeTeleport(primary.CFrame+Vector3.new(0,2,0));notify("雪糕","正在带回...",2)
dragToPosition(selected,originalPos,nil,true)
safeTeleport(originalPos);notify("雪糕","鸭子已带回",3)
end

local function bringDuckc(duckName,ownOnly,mode)

local ducks={}
for _,model in pairs(ws.PlayerModels:GetChildren())do
if model:IsA("Model")and model.Name==duckName then
local owner=model:FindFirstChild("Owner")
if(ownOnly and owner and owner.Value==lp)or(not ownOnly and(not owner or owner.Value==nil))then
table.insert(ducks,model)
end
end
end
if#ducks==0 then
notify("雪糕",ownOnly and"你没有该鸭子"or"没有无归属的该鸭子",3)
return
end

local selected
if mode=="random"then
selected=ducks[math.random(#ducks)]
else
if not duckCycleIndex[duckName]or duckCycleIndex[duckName]>#ducks then duckCycleIndex[duckName]=1 end
selected=ducks[duckCycleIndex[duckName]]
duckCycleIndex[duckName]=(duckCycleIndex[duckName]%#ducks)+1
end

local originalPos=lp.Character and lp.Character.HumanoidRootPart.CFrame
if not originalPos then return end
local primary=selected.PrimaryPart or selected:FindFirstChild("Main")or selected:FindFirstChildWhichIsA("BasePart")
if not primary then notify("雪糕","无法定位鸭子",3)return end
if not selected.PrimaryPart then selected.PrimaryPart=primary end
safeTeleport(primary.CFrame+Vector3.new(0,2,0));notify("雪糕","正在带回...",2)
dragToPosition(selected,originalPos,nil,true)
end

local function translateEvilNotes()
local stoneRUs=ws:FindFirstChild("Stores")and ws.Stores:FindFirstChild("StoneRUs")
if not stoneRUs then
return{"错误：未找到 StoneRUs 商店"}
end

local parts=stoneRUs:FindFirstChild("Parts")
if not parts then
return{"错误：未找到 Parts"}
end

local notes={}
for i=1,3 do
notes[i]=parts:FindFirstChild("Note"..i)
end

if not notes[1]and not notes[2]and not notes[3]then
return{"未找到任何笔记"}
end

local morse={
[".-"]="A",["-..."]="B",["-.-."]="C",["-.."]="D",
["."]="E",["..-."]="F",["--."]="G",["...."]="H",
[".."]="I",[".---"]="J",["-.-"]="K",[".-.."]="L",
["--"]="M",["-."]="N",["---"]="O",[".--."]="P",
["--.-"]="Q",[".-."]="R",["..."]="S",["-"]="T",
["..-"]="U",["...-"]="V",[".--"]="W",["-..-"]="X",
["-.--"]="Y",["--.."]="Z",
["-----"]="0",[".----"]="1",["..---"]="2",["...--"]="3",
["....-"]="4",["....."]="5",["-...."]="6",["--..."]="7",
["---.."]="8",["----."]="9"
}

local function translate(str)
local words={}
for w in str:gmatch("[^/]+")do
local letters={}
for l in w:gmatch("%S+")do
letters[#letters+1]=morse[l]or"?"
end
words[#words+1]=table.concat(letters)
end
return table.concat(words," ")
end

local map={
["I CANT SEE"]="老虎眼",
["HATCHES INTO SOMETHING GREAT"]="蛋",
["KEEP ME WARM"]="热可可",
["GRANT ME LIGHT"]="灯泡",
["QUACK QUACK"]="鸭子",
["GRANT MY WISH"]="神灯",
["GREAT WITH COOKIES"]="牛奶",
["CHEAT CODE"]="游戏机",
["GIVE ME POWER"]="电池",
["IM THIRSTY"]="BLOXY可乐",
["CLAIMS TO BE HAPPY"]="快乐球"
}

local result={}
for i=3,1,-1 do
local note=notes[i]
if note then
local gui=note:FindFirstChildOfClass("SurfaceGui")
local raw=""
if gui then
for _,obj in pairs(gui:GetDescendants())do
if obj:IsA("TextLabel")then
raw=obj.Text
break
end
end
end
if raw~=""then
local decoded=translate(raw)
local meaning=map[decoded]or decoded
result[#result+1]=string.format("Note%d: %s",i,meaning)
else
result[#result+1]=string.format("Note%d: 内容为空",i)
end
else
result[#result+1]=string.format("Note%d: 未找到",i)
end
end
return result
end

-- ===== 恶魔鸭材料：Note 英文谜语 -> 服务器 ShopItems 实际物品名 =====
local evilNoteItemMap={
["I CANT SEE"]="Eye3",
["HATCHES INTO SOMETHING GREAT"]="Egg",
["KEEP ME WARM"]="Cocoa",
["GRANT ME LIGHT"]="LightBulb",
["QUACK QUACK"]="Duck",
["GRANT MY WISH"]="MagicLamp",
["GREAT WITH COOKIES"]="Milk",
["CHEAT CODE"]="NESController",
["GIVE ME POWER"]="Battery",
["IM THIRSTY"]="BloxyCola",
["CLAIMS TO BE HAPPY"]="HappyBall",
}

local function getEvilMaterialNames()
local stoneRUs=ws:FindFirstChild("Stores")and ws.Stores:FindFirstChild("StoneRUs")
if not stoneRUs then return nil,"未找到 StoneRUs 商店"end
local parts=stoneRUs:FindFirstChild("Parts")
if not parts then return nil,"未找到 Parts"end
local morse={
[".-"]="A",["-..."]="B",["-.-."]="C",["-.."]="D",
["."]="E",["..-."]="F",["--."]="G",["...."]="H",
[".."]="I",[".---"]="J",["-.-"]="K",[".-.."]="L",
["--"]="M",["-."]="N",["---"]="O",[".--."]="P",
["--.-"]="Q",[".-."]="R",["..."]="S",["-"]="T",
["..-"]="U",["...-"]="V",[".--"]="W",["-..-"]="X",
["-.--"]="Y",["--.."]="Z",
["-----"]="0",[".----"]="1",["..---"]="2",["...--"]="3",
["....-"]="4",["....."]="5",["-...."]="6",["--..."]="7",
["---.."]="8",["----."]="9"
}
local function decode(str)
local words={}
for w in str:gmatch("[^/]+")do
local letters={}
for l in w:gmatch("%S+")do
letters[#letters+1]=morse[l]or"?"
end
words[#words+1]=table.concat(letters)
end
return table.concat(words," ")
end
local names={}
for i=1,3 do
local note=parts:FindFirstChild("Note"..i)
local raw=""
if note then
local gui=note:FindFirstChildOfClass("SurfaceGui")
if gui then
for _,obj in pairs(gui:GetDescendants())do
if obj:IsA("TextLabel")then raw=obj.Text break end
end
end
end
if raw==""then
names[i]={item=nil,display="内容为空"}
else
local decoded=decode(raw)
local itemName=evilNoteItemMap[decoded]
names[i]={item=itemName,display=decoded.." → "..tostring(itemName or"未映射")}
end
end
return names,nil
end

local function craftRevengeSword()
local evil,angel
for _,m in pairs(ws.PlayerModels:GetChildren())do
if m:IsA("Model")and m:FindFirstChild("Owner")and m.Owner.Value==lp then
if m.Name=="DuckEvil"then
evil=m
elseif m.Name=="DuckAngel"then
angel=m
end
end
end
if not evil or not angel then
notify("雪糕","缺少恶魔鸭或天堂鸭",3)
return
end

local function ensurePart(m)
if not m.PrimaryPart then
local p=m:FindFirstChild("Main")or m:FindFirstChildWhichIsA("BasePart")
if p then
m.PrimaryPart=p
else
return false
end
end
return true
end
if not ensurePart(evil)or not ensurePart(angel)then
return
end

local originalPos=lp.Character and lp.Character.HumanoidRootPart.CFrame
if not originalPos then
notify("雪糕","无法获取玩家位置",3)
return
end

local evilPrimary=evil.PrimaryPart
if evilPrimary then
safeTeleport(evilPrimary.CFrame+Vector3.new(0,2,0))
task.wait(0.1)
dragToPosition(evil,CFrame.new(6486,-89,-4551))
task.wait(0.1)
end

local angelPrimary=angel.PrimaryPart
if angelPrimary then
safeTeleport(angelPrimary.CFrame+Vector3.new(0,2,0))
task.wait(0.1)
dragToPosition(angel,CFrame.new(6447,-90,-4523))
task.wait(0.1)
end

safeTeleport(CFrame.new(6466,-95,-4546))
notify("雪糕","鸭子已移动，位置已就绪",3)
end

local function craftLunarDuck()
local evil,angel,normal
for _,m in pairs(ws.PlayerModels:GetChildren())do
if m:IsA("Model")and m:FindFirstChild("Owner")and m.Owner.Value==lp then
if m.Name=="DuckEvil"then
evil=m
elseif m.Name=="DuckAngel"then
angel=m
elseif m.Name=="Duck"then
normal=m
end
end
end
if not evil or not angel or not normal then
notify("雪糕","缺少所需鸭子",3)
return
end

local function ensurePart(m)
if not m.PrimaryPart then
local p=m:FindFirstChild("Main")or m:FindFirstChildWhichIsA("BasePart")
if p then
m.PrimaryPart=p
else
return false
end
end
return true
end
if not ensurePart(evil)or not ensurePart(angel)or not ensurePart(normal)then
return
end

local originalPos=lp.Character and lp.Character.HumanoidRootPart.CFrame
if not originalPos then
notify("雪糕","无法获取玩家位置",3)
return
end

local evilPrimary=evil.PrimaryPart
if evilPrimary then
safeTeleport(evilPrimary.CFrame+Vector3.new(0,2,0))
task.wait(0.1)
dragToPosition(evil,CFrame.new(-7092.01,391,4890.51))
task.wait(0.1)
end

local normalPrimary=normal.PrimaryPart
if normalPrimary then
safeTeleport(normalPrimary.CFrame+Vector3.new(0,2,0))
task.wait(0.1)
dragToPosition(normal,CFrame.new(-7066.70,391,4898.07))
task.wait(0.1)
end

local angelPrimary=angel.PrimaryPart
if angelPrimary then
safeTeleport(angelPrimary.CFrame+Vector3.new(0,2,0))
task.wait(0.1)
dragToPosition(angel,CFrame.new(-7041.83,391,4906.09))
task.wait(0.1)
end

safeTeleport(CFrame.new(-7059,390,4881))
end

local function refreshPrivateServer()
notify("雪糕","断开重连...",3);for i=3,1,-1 do task.wait(1)end;lp:Kick("重连");task.wait(5);game:GetService("TeleportService"):Teleport(game.PlaceId,lp)
end

 dragEnhanceConnection=nil
local function setDragEnhance(state)
if dragEnhanceConnection then dragEnhanceConnection:Disconnect()end
dragEnhanceConnection=workspace.ChildAdded:Connect(function(Dragger)
if tostring(Dragger)=="Dragger"then
local BodyGyro=Dragger:WaitForChild("BodyGyro")
local BodyPosition=Dragger:WaitForChild("BodyPosition")
repeat task.wait()until workspace:FindFirstChild("Dragger")
if state then
BodyPosition.P=120000
BodyPosition.D=1000
BodyPosition.maxForce=Vector3.new(1,1,1)*1000000
BodyGyro.maxTorque=Vector3.new(1,1,1)*200
BodyGyro.P=1200
BodyGyro.D=140
else
BodyPosition.P=10000
BodyPosition.D=800
BodyPosition.maxForce=Vector3.new(17000,17000,17000)
BodyGyro.maxTorque=Vector3.new(200,200,200)
BodyGyro.P=1200
BodyGyro.D=140
end
end
end)
end
setDragEnhance(false)

local function applyNoClip(state)
if state then
if bai.noclipConn then bai.noclipConn:Disconnect()end
bai.noclipConn=game:GetService("RunService").Stepped:Connect(function()
if lp.Character then
for _,v in pairs(lp.Character:GetChildren())do if v:IsA("BasePart")then v.CanCollide=false end end
end
end)
if bai.noclipCharConn then bai.noclipCharConn:Disconnect()end
bai.noclipCharConn=lp.CharacterAdded:Connect(function()
if bai.noclipEnabled then
task.wait(0.1)
for _,v in pairs(lp.Character:GetChildren())do if v:IsA("BasePart")then v.CanCollide=false end end
end
end)
else
if bai.noclipConn then bai.noclipConn:Disconnect();bai.noclipConn=nil end
if bai.noclipCharConn then bai.noclipCharConn:Disconnect();bai.noclipCharConn=nil end
if lp.Character then for _,v in pairs(lp.Character:GetChildren())do if v:IsA("BasePart")then v.CanCollide=true end end end
end
bai.noclipEnabled=state
end

local function addHighlightToModel(model,highlightTable)
if not highlightTable then return end
if highlightTable[model]then return end
local hl=Instance.new("Highlight")
hl.Parent=model
hl.FillColor=Color3.fromRGB(0,150,255)
hl.FillTransparency=0.7
hl.OutlineColor=Color3.fromRGB(0,100,200)
hl.OutlineTransparency=0.3
hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
hl.Enabled=true
highlightTable[model]=hl
end

local function removeHighlightFromModel(model,highlightTable)
if not highlightTable then return end
local hl=highlightTable[model]
if hl then
pcall(function()hl:Destroy()end)
highlightTable[model]=nil
end
end

local function addDuckOutline(duckModel)
if not duckOutlineEnabled then return end
if duckHighlights[duckModel]then return end
local hl=Instance.new("Highlight")
hl.Parent=duckModel
hl.FillColor=Color3.fromRGB(0,150,255)
hl.FillTransparency=0.7
hl.OutlineColor=Color3.fromRGB(0,100,200)
hl.OutlineTransparency=0.3
hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
hl.Enabled=true
duckHighlights[duckModel]=hl
end

local function removeDuckOutline(duckModel)
local hl=duckHighlights[duckModel]
if hl then
pcall(function()hl:Destroy()end)
duckHighlights[duckModel]=nil
end
end

local function syncDuckHighlights()
if not duckOutlineEnabled then return end
local currentDucks={}
for _,model in pairs(workspace.PlayerModels:GetChildren())do
if model:IsA("Model")and model.Name=="2018CGift_Duck"then
currentDucks[model]=true
if not duckHighlights[model]then
addDuckOutline(model)
end
end
end
for model,_ in pairs(duckHighlights)do
if not currentDucks[model]then
removeDuckOutline(model)
end
end
end

local function enableDuckOutline()
if duckOutlineEnabled then return end
duckOutlineEnabled=true
if type(duckHighlights)~="table"then duckHighlights={}end

syncDuckHighlights()

if duckRefreshTask then task.cancel(duckRefreshTask)end
duckRefreshTask=task.spawn(function()
while duckOutlineEnabled do
syncDuckHighlights()
task.wait(2)
end
end)

if duckAddedConn then duckAddedConn:Disconnect()end
duckAddedConn=workspace.PlayerModels.ChildAdded:Connect(function(child)
if duckOutlineEnabled and child:IsA("Model")and child.Name=="2018CGift_Duck"then
addDuckOutline(child)
end
end)
if duckRemovingConn then duckRemovingConn:Disconnect()end
duckRemovingConn=workspace.PlayerModels.ChildRemoved:Connect(function(child)
if child:IsA("Model")and child.Name=="2018CGift_Duck"then
removeDuckOutline(child)
end
end)

notify("雪糕","🔵 礼物鸭蓝色轮廓已开启（实时刷新）",2)
end

local function disableDuckOutline()
if not duckOutlineEnabled then return end
duckOutlineEnabled=false

if duckRefreshTask then task.cancel(duckRefreshTask);duckRefreshTask=nil end
if duckAddedConn then duckAddedConn:Disconnect();duckAddedConn=nil end
if duckRemovingConn then duckRemovingConn:Disconnect();duckRemovingConn=nil end

for _,hl in pairs(duckHighlights)do pcall(function()hl:Destroy()end)end
duckHighlights={}

notify("雪糕","🔵 礼物鸭蓝色轮廓已关闭",2)
end

local function isVoidCrate(model)
if not model:IsA("Model")or model.Name~="SaplingCrate"then return false end
local settings=model:FindFirstChild("Settings")
if not settings then return false end
local woodClass=settings:FindFirstChild("WoodClass")
if not woodClass then return false end
return woodClass.Value=="Void"
end

local function addVoidCrateHighlight(model)
if not voidCrateOutlineEnabled then return end
if voidCrateHighlights[model]then return end
local hl=Instance.new("Highlight")
hl.Parent=model
hl.FillColor=Color3.fromRGB(170,0,255)
hl.FillTransparency=0.7
hl.OutlineColor=Color3.fromRGB(100,0,200)
hl.OutlineTransparency=0.3
hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
hl.Enabled=true
voidCrateHighlights[model]=hl
end

local function removeVoidCrateHighlight(model)
local hl=voidCrateHighlights[model]
if hl then
pcall(function()hl:Destroy()end)
voidCrateHighlights[model]=nil
end
end

local function syncVoidCrateHighlights()
if not voidCrateOutlineEnabled then return end
local currentCrates={}
for _,model in pairs(workspace.PlayerModels:GetChildren())do
if isVoidCrate(model)then
currentCrates[model]=true
if not voidCrateHighlights[model]then
addVoidCrateHighlight(model)
end
end
end
for model,_ in pairs(voidCrateHighlights)do
if not currentCrates[model]then
removeVoidCrateHighlight(model)
end
end
end

local function enableVoidCrateOutline()
if voidCrateOutlineEnabled then return end
voidCrateOutlineEnabled=true
if type(voidCrateHighlights)~="table"then voidCrateHighlights={}end

syncVoidCrateHighlights()

if voidCrateRefreshTask then task.cancel(voidCrateRefreshTask)end
voidCrateRefreshTask=task.spawn(function()
while voidCrateOutlineEnabled do
syncVoidCrateHighlights()
task.wait(2)
end
end)

if voidCrateAddedConn then voidCrateAddedConn:Disconnect()end
voidCrateAddedConn=workspace.PlayerModels.ChildAdded:Connect(function(child)
if voidCrateOutlineEnabled and isVoidCrate(child)then
addVoidCrateHighlight(child)
end
end)
if voidCrateRemovingConn then voidCrateRemovingConn:Disconnect()end
voidCrateRemovingConn=workspace.PlayerModels.ChildRemoved:Connect(function(child)
if child:IsA("Model")and child.Name=="SaplingCrate"then
removeVoidCrateHighlight(child)
end
end)

notify("雪糕","🟣 Void树苗箱紫色轮廓已开启（实时刷新）",2)
end

local function disableVoidCrateOutline()
if not voidCrateOutlineEnabled then return end
voidCrateOutlineEnabled=false

if voidCrateRefreshTask then task.cancel(voidCrateRefreshTask);voidCrateRefreshTask=nil end
if voidCrateAddedConn then voidCrateAddedConn:Disconnect();voidCrateAddedConn=nil end
if voidCrateRemovingConn then voidCrateRemovingConn:Disconnect();voidCrateRemovingConn=nil end

for _,hl in pairs(voidCrateHighlights)do pcall(function()hl:Destroy()end)end
voidCrateHighlights={}

notify("雪糕","🟣 Void树苗箱紫色轮廓已关闭",2)
end

 espEnabled=false
 espGui,espFrames,espRenderConn,espPlayerAddedConn,espPlayerRemovingConn = nil,nil,nil,nil,nil

_G.qsMain=_G.qsMain or {}
for k,v in pairs({gs=gs,lp=lp,ws=ws,rep=rep,mouse=mouse,defaultDragAttempts=defaultDragAttempts,defaultDragInterval=defaultDragInterval,CONFIG_FILE=CONFIG_FILE,loadDragConfig=loadDragConfig,duckCycleIndex=duckCycleIndex,bai=bai,voidSaplingRunning=voidSaplingRunning,shuaxinlb=shuaxinlb,uprightCFrame=uprightCFrame,safeTeleport=safeTeleport,unlockPlayer=unlockPlayer,lockPlayerAt=lockPlayerAt,carTeleport=carTeleport,tp=tp,droptool=droptool,saveDragConfig=saveDragConfig,treeMapping=treeMapping,treeNames=treeNames,getNextDragID=getNextDragID,DRAG_TOTAL=DRAG_TOTAL,DRAG_SET_START=DRAG_SET_START,DRAG_SET_COUNT=DRAG_SET_COUNT,DRAG_SET_INTERVAL=DRAG_SET_INTERVAL,DRAG_REFRESH_INTERVAL=DRAG_REFRESH_INTERVAL,DRAG_AFTER_WAIT=DRAG_AFTER_WAIT,dragToPosition=dragToPosition,findUncutTree=findUncutTree,axeConfigCache=axeConfigCache,loadWeaponConfig=loadWeaponConfig,selectBestWeapon=selectBestWeapon,bringTreeRemote=bringTreeRemote,safeTeleportNoWait=safeTeleportNoWait,getBestAxeData=getBestAxeData,getTreeClassFromModel=getTreeClassFromModel,forceDragUntilProcessed=forceDragUntilProcessed,decomposeAndProcess=decomposeAndProcess,startDecomposeSelection=startDecomposeSelection,deleteLavaObjectsOnce=deleteLavaObjectsOnce,startAutoDelete=startAutoDelete,stopAutoDelete=stopAutoDelete,executeSequenceAndReturn=executeSequenceAndReturn,bringDuck=bringDuck,bringDuckc=bringDuckc,translateEvilNotes=translateEvilNotes,evilNoteItemMap=evilNoteItemMap,getEvilMaterialNames=getEvilMaterialNames,craftRevengeSword=craftRevengeSword,craftLunarDuck=craftLunarDuck,refreshPrivateServer=refreshPrivateServer,setDragEnhance=setDragEnhance,applyNoClip=applyNoClip,addHighlightToModel=addHighlightToModel,removeHighlightFromModel=removeHighlightFromModel,addDuckOutline=addDuckOutline,removeDuckOutline=removeDuckOutline,syncDuckHighlights=syncDuckHighlights,enableDuckOutline=enableDuckOutline,disableDuckOutline=disableDuckOutline,isVoidCrate=isVoidCrate,addVoidCrateHighlight=addVoidCrateHighlight,removeVoidCrateHighlight=removeVoidCrateHighlight,syncVoidCrateHighlights=syncVoidCrateHighlights,enableVoidCrateOutline=enableVoidCrateOutline,disableVoidCrateOutline=disableVoidCrateOutline})do _G.qsMain[k]=v end

]====]
local SRC_MAIN2 = [====[
_G.qsMain=_G.qsMain or {}
local gs=_G.qsMain.gs
local lp=_G.qsMain.lp
local ws=_G.qsMain.ws
local rep=_G.qsMain.rep
local mouse=_G.qsMain.mouse
local defaultDragAttempts=_G.qsMain.defaultDragAttempts
local defaultDragInterval=_G.qsMain.defaultDragInterval
local CONFIG_FILE=_G.qsMain.CONFIG_FILE
local loadDragConfig=_G.qsMain.loadDragConfig
local duckCycleIndex=_G.qsMain.duckCycleIndex
local bai=_G.qsMain.bai
local voidSaplingRunning=_G.qsMain.voidSaplingRunning
local shuaxinlb=_G.qsMain.shuaxinlb
local uprightCFrame=_G.qsMain.uprightCFrame
local safeTeleport=_G.qsMain.safeTeleport
local unlockPlayer=_G.qsMain.unlockPlayer
local lockPlayerAt=_G.qsMain.lockPlayerAt
local carTeleport=_G.qsMain.carTeleport
local tp=_G.qsMain.tp
local droptool=_G.qsMain.droptool
local saveDragConfig=_G.qsMain.saveDragConfig
local treeMapping=_G.qsMain.treeMapping
local treeNames=_G.qsMain.treeNames
local getNextDragID=_G.qsMain.getNextDragID
local DRAG_TOTAL=_G.qsMain.DRAG_TOTAL
local DRAG_SET_START=_G.qsMain.DRAG_SET_START
local DRAG_SET_COUNT=_G.qsMain.DRAG_SET_COUNT
local DRAG_SET_INTERVAL=_G.qsMain.DRAG_SET_INTERVAL
local DRAG_REFRESH_INTERVAL=_G.qsMain.DRAG_REFRESH_INTERVAL
local DRAG_AFTER_WAIT=_G.qsMain.DRAG_AFTER_WAIT
local dragToPosition=_G.qsMain.dragToPosition
local findUncutTree=_G.qsMain.findUncutTree
local axeConfigCache=_G.qsMain.axeConfigCache
local loadWeaponConfig=_G.qsMain.loadWeaponConfig
local selectBestWeapon=_G.qsMain.selectBestWeapon
local bringTreeRemote=_G.qsMain.bringTreeRemote
local safeTeleportNoWait=_G.qsMain.safeTeleportNoWait
local getBestAxeData=_G.qsMain.getBestAxeData
local getTreeClassFromModel=_G.qsMain.getTreeClassFromModel
local forceDragUntilProcessed=_G.qsMain.forceDragUntilProcessed
local decomposeAndProcess=_G.qsMain.decomposeAndProcess
local startDecomposeSelection=_G.qsMain.startDecomposeSelection
local deleteLavaObjectsOnce=_G.qsMain.deleteLavaObjectsOnce
local startAutoDelete=_G.qsMain.startAutoDelete
local stopAutoDelete=_G.qsMain.stopAutoDelete
local executeSequenceAndReturn=_G.qsMain.executeSequenceAndReturn
local bringDuck=_G.qsMain.bringDuck
local bringDuckc=_G.qsMain.bringDuckc
local translateEvilNotes=_G.qsMain.translateEvilNotes
local evilNoteItemMap=_G.qsMain.evilNoteItemMap
local getEvilMaterialNames=_G.qsMain.getEvilMaterialNames
local craftRevengeSword=_G.qsMain.craftRevengeSword
local craftLunarDuck=_G.qsMain.craftLunarDuck
local refreshPrivateServer=_G.qsMain.refreshPrivateServer
local setDragEnhance=_G.qsMain.setDragEnhance
local applyNoClip=_G.qsMain.applyNoClip
local addHighlightToModel=_G.qsMain.addHighlightToModel
local removeHighlightFromModel=_G.qsMain.removeHighlightFromModel
local addDuckOutline=_G.qsMain.addDuckOutline
local removeDuckOutline=_G.qsMain.removeDuckOutline
local syncDuckHighlights=_G.qsMain.syncDuckHighlights
local enableDuckOutline=_G.qsMain.enableDuckOutline
local disableDuckOutline=_G.qsMain.disableDuckOutline
local isVoidCrate=_G.qsMain.isVoidCrate
local addVoidCrateHighlight=_G.qsMain.addVoidCrateHighlight
local removeVoidCrateHighlight=_G.qsMain.removeVoidCrateHighlight
local syncVoidCrateHighlights=_G.qsMain.syncVoidCrateHighlights
local enableVoidCrateOutline=_G.qsMain.enableVoidCrateOutline
local disableVoidCrateOutline=_G.qsMain.disableVoidCrateOutline
local function createEspFrame(p)
if espFrames[p]or not espGui then return end
local f=Instance.new("Frame");f.Size=UDim2.new(0,50,0,70);f.BackgroundTransparency=1;f.Parent=espGui
local img=Instance.new("ImageLabel");img.Size=UDim2.new(1,0,0,50);img.BackgroundTransparency=1;img.ScaleType=Enum.ScaleType.Fit;img.Parent=f
local txt=Instance.new("TextLabel");txt.Size=UDim2.new(1,0,0,20);txt.Position=UDim2.new(0,0,0,50);txt.BackgroundTransparency=1;txt.TextColor3=Color3.new(1,1,1);txt.TextScaled=true;txt.Font=Enum.Font.GothamBold;txt.Text="?";txt.Parent=f
espFrames[p]={frame=f,image=img,text=txt}
task.spawn(function()
local suc,thumb=pcall(function()return game:GetService("Players"):GetUserThumbnailAsync(p.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size150x150)end)
if not suc then task.wait(1);suc,thumb=pcall(function()return game:GetService("Players"):GetUserThumbnailAsync(p.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size150x150)end)end
if suc and espFrames[p]then espFrames[p].image.Image=thumb end
end)
end

local function removeEspFrame(p)
if espFrames[p]then espFrames[p].frame:Destroy();espFrames[p]=nil end
end

local function updateEsp()
if not espEnabled then return end
local cam=workspace.CurrentCamera
local localPos=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
if not localPos then return end
for p,data in pairs(espFrames)do
local hrp=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if hrp then
local pos,onScreen=cam:WorldToScreenPoint(hrp.Position)
if onScreen then
data.frame.Visible=true;data.frame.Position=UDim2.new(0,pos.X-25,0,pos.Y-70)
local dist=(hrp.Position-localPos.Position).Magnitude;data.text.Text=string.format("%.1f",dist)
else data.frame.Visible=false end
else data.frame.Visible=false end
end
end

local function enableEsp()
if espEnabled then return end
espEnabled=true
local success,guiParent=pcall(function()return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")end)
if not success or not guiParent then guiParent=game:GetService("CoreGui")end
espGui=Instance.new("ScreenGui");espGui.Name="ESP_GUI_雪糕";espGui.ResetOnSpawn=false;espGui.Parent=guiParent
task.spawn(function()while espEnabled do task.wait(5);if espGui and not espGui.Parent then espGui.Parent=guiParent end end end)
espFrames={}
for _,p in pairs(game.Players:GetPlayers())do if p~=lp then createEspFrame(p)end end
espRenderConn=game:GetService("RunService").RenderStepped:Connect(updateEsp)
espPlayerAddedConn=game.Players.PlayerAdded:Connect(function(p)if p~=lp then createEspFrame(p)end end)
espPlayerRemovingConn=game.Players.PlayerRemoving:Connect(removeEspFrame)
notify("雪糕","ESP已开启",2)
end

local function disableEsp()
if not espEnabled then return end
espEnabled=false
if espRenderConn then espRenderConn:Disconnect()end
if espPlayerAddedConn then espPlayerAddedConn:Disconnect()end
if espPlayerRemovingConn then espPlayerRemovingConn:Disconnect()end
if espGui then espGui:Destroy()end
espGui=nil;espFrames=nil
notify("雪糕","ESP已关闭",2)
end

local bailib=loadstring(game:HttpGet"http://qinscript.lol/333/透明UI.lua")()
local win=bailib:new("木材大亨2",'')
_G.qSnowMainWin=win
_G.qSnowLP=lp
_G.qSnowSafeTeleport=safeTeleport
_G.qSnowDragToPosition=dragToPosition

local Tab1=win:Tab("玩家","2700297399")
local Tab=win:Tab("主要","2700297399")
local Tab2=win:Tab("环境","2700297399")
local Tab4=win:Tab("针对","2700297399")

local Section3=Tab1:section("玩家",true)
local Section4=Tab1:section("普通传送",false)
local Section6=Tab1:section("汽车传送",false)

local Sectionbringtree=Tab:section("带来树",false)
local Section5=Tab:section("木头",false)
local SectionDuck=Tab:section("鸭子",false)
local Sectiontuozhuai=Tab:section("拖拽",false)
local SectionEVIL=Tab:section("恶魔鸭合成",false)
local SectionESP=Tab:section("玩家透视",false)
local Section1=Tab:section("基地",false)
local Section=Tab:section("斧头",false)
local Sectionshuaxin=Tab:section("刷新私服",false)
local Sectionyanjiang=Tab:section("岩浆",false)
local Sectionqita=Tab:section("其他功能",false)
local Sectionzhengli=Tab:section("物品整理",false)

local Sectionhuanjin=Tab2:section("环境",false)

local Sectionmogui=Tab4:section("了",true)

Section5:Button("选择锯木机",function()
notify("雪糕","请点击锯木机任意部件",3)
local conn
conn=mouse.Button1Down:Connect(function()
local target=mouse.Target
if not target then
notify("雪糕","未选中任何物体",2)
return
end

local model=target:FindFirstAncestorOfClass("Model")
if not model then
notify("雪糕","请点击一个模型",2)
return
end

local function isSawmill(root)

local attr=root:GetAttribute("ItemName")
if attr and type(attr)=="string"and attr:lower():find("saw")then
return true
end

for _,child in pairs(root:GetDescendants())do
if child.Name=="ItemName"then
local val=child.Value
if val and type(val)=="string"and val:lower():find("saw")then
return true
end
end
end

if root.Name and root.Name:lower():find("saw")then
return true
end

local typeVal=root:FindFirstChild("Type")
if typeVal and typeVal.Value=="Sawmill"then
return true
end
return false
end

if not isSawmill(model)then
notify("雪糕","这不是锯木机（未检测到锯木机标识）",3)
return
end

local function findPart(root)
for _,child in pairs(root:GetDescendants())do
if child.Name=="Conveyor"and child:IsA("BasePart")then
return child,"Conveyor"
end
end
for _,child in pairs(root:GetDescendants())do
if child.Name=="Main"and child:IsA("BasePart")then
return child,"Main"
end
end
return nil,nil
end

local part,partType=findPart(model)
if not part then
notify("雪糕","找不到 Conveyor 或 Main 部件",3)
return
end

bai.cachedSawmill=model
bai.cachedSawmillPos=part.CFrame
conn:Disconnect()
notify("雪糕","✅ 已记忆锯木机位置（"..partType.."）",3)
end)
end)

 currentSortTool=nil
 sortStartHeight=1
 sortGap=0

local function getSortItemType(model)

if model:FindFirstChild("BlueprintWoodClass")then
return nil
end

if model:FindFirstChild("ButtonRemote_SpawnButton")then
return nil
end

if model:FindFirstChild("PurchasedBoxItemName")then
local itemName=model.PurchasedBoxItemName.Value
if itemName==nil or itemName==""or itemName==" "then
return nil
end
end

if model:FindFirstChild("BoxItemName")then
local itemName=model.BoxItemName.Value
if itemName==nil or itemName==""or itemName==" "then
return nil
end
end

if model:FindFirstChild("TreeClass")then
return"TreeClass:"..model.TreeClass.Value
end

if model:FindFirstChild("Type")then
return"Type:"..model.Type.Value
end

if model.Name and model.Name~=""then
return"Name:"..model.Name
end
return nil
end

local function getModelSize(model)
local primary=model.PrimaryPart or model:FindFirstChild("Main")or model:FindFirstChild("WoodSection")or model:FindFirstChildWhichIsA("BasePart")
if primary then
return primary.Size
end
return Vector3.new(2,2,2)
end

local function getModelBottom(model)
local primary=model.PrimaryPart or model:FindFirstChild("Main")or model:FindFirstChild("WoodSection")or model:FindFirstChildWhichIsA("BasePart")
if primary then
return primary.Position.Y-primary.Size.Y/2
end
return 0
end

local function isSortable(model)

if model:FindFirstChild("BlueprintWoodClass")then
return false
end

if model:FindFirstChild("ButtonRemote_SpawnButton")then
return false
end

if model:FindFirstChild("PurchasedBoxItemName")then
local itemName=model.PurchasedBoxItemName.Value
if itemName==nil or itemName==""or itemName==" "then
return false
end
end

if model:FindFirstChild("BoxItemName")then
local itemName=model.BoxItemName.Value
if itemName==nil or itemName==""or itemName==" "then
return false
end
end

if model:FindFirstChild("TreeClass")then
return true
end

if model:FindFirstChild("Owner")then
return true
end
return false
end

local function giveSortTool()
if currentSortTool and currentSortTool.Parent then
currentSortTool:Destroy()
end

currentSortTool=Instance.new("Tool")
currentSortTool.RequiresHandle=false
currentSortTool.Name="点击要整理的物品"

currentSortTool.Activated:Connect(function()
local target=mouse.Target
if not target then return end

local model=target:FindFirstAncestorOfClass("Model")
if not model then
notify("雪糕","请点击一个物品",2)
return
end

local owner=model:FindFirstChild("Owner")
if not owner or tostring(owner.Value)~=bai.zlwjia then
notify("雪糕","不属于所选玩家: "..bai.zlwjia,2)
return
end

if not isSortable(model)then
notify("雪糕","该物品不可整理（只支持 Loose Item / Tool / Furniture / Gift / 木头 / 停车位）",2)
return
end

local itemName=model.Name
if not itemName or itemName==""then
notify("雪糕","无法识别该物品名称",2)
return
end

notify("雪糕","⏳ 正在整理同名物品: "..itemName,2)

local items={}

for _,v in pairs(workspace.PlayerModels:GetChildren())do
if v:IsA("Model")and v:FindFirstChild("Owner")and tostring(v.Owner.Value)==bai.zlwjia then
if v.Name==itemName and isSortable(v)then
table.insert(items,v)
end
end
end

for _,log in pairs(workspace.LogModels:GetChildren())do
if log:FindFirstChild("Owner")and tostring(log.Owner.Value)==bai.zlwjia then
if log.Name==itemName and isSortable(log)then
table.insert(items,log)
end
end
end

if#items==0 then
notify("雪糕","没有找到同名且可整理的物品",3)
return
end

local hrp=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
if not hrp then
notify("雪糕","无法获取玩家位置，请重生",3)
return
end

local feetPos=hrp.Position-Vector3.new(0,3.5,0)
local startPos=feetPos+Vector3.new(0,sortStartHeight,0)

local maxSize=Vector3.new(0,0,0)
for _,item in ipairs(items)do
local sz=getModelSize(item)
if sz.X>maxSize.X then maxSize=Vector3.new(sz.X,maxSize.Y,maxSize.Z)end
if sz.Y>maxSize.Y then maxSize=Vector3.new(maxSize.X,sz.Y,maxSize.Z)end
if sz.Z>maxSize.Z then maxSize=Vector3.new(maxSize.X,maxSize.Y,sz.Z)end
end

local xCount=bai.zix or 5
local zCount=bai.zlz or 3
local layerHeight=maxSize.Y*0.8

local sortedCount=0
local colInRow=0
local rowInLayer=0
local layerCount=0

table.sort(items,function(a,b)
local szA=getModelSize(a)
local szB=getModelSize(b)
return szA.X*szA.Z<szB.X*szB.Z
end)

for i,item in ipairs(items)do

if not lp.Character or not lp.Character:FindFirstChild("HumanoidRootPart")then
notify("雪糕","⚠️ 角色丢失，停止整理",2)
break
end

local size=getModelSize(item)
local itemWidth=size.X+sortGap
local itemDepth=size.Z+sortGap

local x=colInRow*itemWidth
local z=rowInLayer*itemDepth
local y=layerCount*layerHeight

local targetPos=CFrame.new(
startPos.X+x,
startPos.Y+y,
startPos.Z+z
)

colInRow=colInRow+1
if colInRow>=xCount then
colInRow=0
rowInLayer=rowInLayer+1
if rowInLayer>=zCount then
rowInLayer=0
layerCount=layerCount+1
end
end

local primary=item.PrimaryPart or item:FindFirstChild("Main")or item:FindFirstChild("WoodSection")or item:FindFirstChildWhichIsA("BasePart")
if primary then
if not item.PrimaryPart then item.PrimaryPart=primary end

safeTeleport(primary.CFrame+Vector3.new(0,2,0))
task.wait(0.1)
if dragToPosition(item,targetPos)then
sortedCount=sortedCount+1
end
end
end

if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")then
safeTeleport(hrp.CFrame)
end

notify("雪糕",string.format("已整理 %d/%d 个同名物品",sortedCount,#items),3)
end)

currentSortTool.Parent=lp.Backpack
notify("雪糕","整理工具已添加到背包，点击物品开始整理",3)
end

if Sectionzhengli then

local sortPlayerDropdown=nil
local function refreshSortPlayerList()
local list={}
for _,p in pairs(game.Players:GetPlayers())do
table.insert(list,p.Name)
end
if sortPlayerDropdown then
sortPlayerDropdown:SetOptions(list)

local found=false
for _,name in ipairs(list)do
if name==bai.zlwjia then
found=true
break
end
end
if not found then
bai.zlwjia=list[1]or lp.Name
sortPlayerDropdown:SetValue(bai.zlwjia)
end
end
end

sortPlayerDropdown=Sectionzhengli:Dropdown("选择玩家（整理目标）","SortPlayerDropdown",{lp.Name},function(v)
bai.zlwjia=v
notify("雪糕","已切换到玩家: "..v,2)
end)
refreshSortPlayerList()

Sectionzhengli:Button("刷新玩家列表",function()
refreshSortPlayerList()
end)

Sectionzhengli:Textbox("每行数量","SortCountX",tostring(bai.zix or 5),function(v)
local num=tonumber(v)
if num and num>0 then bai.zix=math.floor(num)else notify("雪糕","请输入正整数",2)end
end)

Sectionzhengli:Textbox("每列数量（Z轴方向）","SortCountZ",tostring(bai.zlz or 3),function(v)
local num=tonumber(v)
if num and num>0 then bai.zlz=math.floor(num)else notify("雪糕","请输入正整数",2)end
end)

Sectionzhengli:Textbox("物品间隙","SortGap",tostring(sortGap),function(v)
local num=tonumber(v)
if num and num>=0 then sortGap=num else notify("雪糕","请输入大于等于0的数字",2)end
end)

Sectionzhengli:Textbox("起始高度偏移（从脚底往上）","SortHeight",tostring(sortStartHeight),function(v)
local num=tonumber(v)
if num then sortStartHeight=num else notify("雪糕","请输入有效数字",2)end
end)

Sectionzhengli:Button("获取整理工具",function()
giveSortTool()
end)

Sectionzhengli:Button("删除整理工具",function()
if currentSortTool and currentSortTool.Parent then
currentSortTool:Destroy()
currentSortTool=nil
notify("雪糕","🗑️ 整理工具已删除",2)
else
notify("雪糕","没有找到整理工具",2)
end
end)

Sectionzhengli:Label("提示：1. 点击同类任意物品，自动排列所有同类物品")
end

Section5:Button("一键加工（分解可用 速度快）",function()
startDecomposeSelection()
end)

SectionEVIL:Button("删除恶魔鸭墙",function()
pcall(function()
if workspace:FindFirstChild("Region_Main")and workspace.Region_Main:FindFirstChild("ExplodeMe")then
workspace.Region_Main.ExplodeMe:Destroy()
end
end)
notify("雪糕","已尝试删除恶魔鸭墙",3)
end)

local selectedMaterialKeys={nil,nil,nil}

local dragTargets={
[1]=CFrame.new(-223.74,61.00,940.42),
[2]=CFrame.new(-232.924927,61.3797455,933.015076),
[3]=CFrame.new(-241.81,61,925.51)
}

local openPositions={
[1]=CFrame.new(-228.78,59.8,943.14),
[2]=CFrame.new(-230.03,59.8,935.47),
[3]=CFrame.new(-239.71,59.8,927.46)
}

local function highlightModel(model)
if not model or not model.Parent then return end
local primary=model.PrimaryPart or model:FindFirstChild("Main")or model:FindFirstChildWhichIsA("BasePart")
if not primary then return end
local box=Instance.new("SelectionBox")
box.Adornee=primary
box.Color3=Color3.fromRGB(0,255,0)
box.Transparency=0.5
box.LineThickness=0.05
box.Parent=primary
task.delay(0.8,function()pcall(function()box:Destroy()end)end)
end

local function getItemKey(model)
if not model then return nil end
if model:FindFirstChild("PurchasedBoxItemName")then
return"PurchasedBoxItemName:"..model.PurchasedBoxItemName.Value
elseif model:FindFirstChild("ItemName")then
return"ItemName:"..model.ItemName.Value
elseif model:FindFirstChild("DraggableItem")then
return"DraggableItem:"..tostring(model.DraggableItem.Parent)
end
return nil
end

local function findItemByKey(key,allowFuzzy)
if not key then return nil end
local prefix,value=key:match("^(.-):(.+)$")
if not prefix or not value then return nil end

for _,model in pairs(ws.PlayerModels:GetChildren())do
if model:FindFirstChild("Owner")and model.Owner.Value==lp then
if prefix=="PurchasedBoxItemName"and model:FindFirstChild("PurchasedBoxItemName")and model.PurchasedBoxItemName.Value==value then
return model
elseif prefix=="ItemName"and model:FindFirstChild("ItemName")and model.ItemName.Value==value then
return model
elseif prefix=="DraggableItem"and model:FindFirstChild("DraggableItem")and tostring(model.DraggableItem.Parent)==value then
return model
end
end
end

if allowFuzzy then
for _,model in pairs(ws.PlayerModels:GetChildren())do
if model:FindFirstChild("Owner")and model.Owner.Value==lp then
local modelValue=nil
if model:FindFirstChild("PurchasedBoxItemName")then
modelValue=model.PurchasedBoxItemName.Value
elseif model:FindFirstChild("ItemName")then
modelValue=model.ItemName.Value
elseif model:FindFirstChild("DraggableItem")then
modelValue=tostring(model.DraggableItem.Parent)
end
if modelValue==value then
notify("雪糕","自动找到同类物品: "..model.Name,2)
return model
end
end
end
end
return nil
end

local function openItem(item)
if not item then return false end
local remoteButton=item:FindFirstChild("ButtonRemote_Main")
if remoteButton then
local ok=pcall(function()
game:GetService("ReplicatedStorage").Interaction.RemoteProxy:FireServer(remoteButton)
end)
if ok then
notify("雪糕","已发送按钮打开请求",2)
return true
end
end
if item:FindFirstChild("BoxItemName")or item:FindFirstChild("PurchasedBoxItemName")then
local ok=pcall(function()
rep.Interaction.ClientInteracted:FireServer(item,'Open box')
end)
if ok then
notify("雪糕","已发送打开盒子请求",2)
return true
end
end
notify("雪糕","该物品无法通过已知方式打开",2)
return false
end
 evilTranslatedLabels={}

local function waitItemReady(item,timeout)
timeout=timeout or 3
local waited=0
while waited<timeout do
if not item or not item.Parent then return false end
if item:FindFirstChild("ButtonRemote_Main")or item:FindFirstChild("BoxItemName")or item:FindFirstChild("PurchasedBoxItemName")or item:FindFirstChild("ItemName")or item:FindFirstChild("DraggableItem")then
return true
end
task.wait(0.2)
waited=waited+0.2
end
return item and item.Parent and(item:FindFirstChild("ItemName")~=nil or item:FindFirstChild("PurchasedBoxItemName")~=nil)
end

 evilCombineStopFlag=false
 evilAutoRunning=false
 evilCombineCount=1

-- ==================== 等待新恶魔鸭出现（默认5秒） ====================
local function waitEvilDuckAppear(timeout, preSet)
local deadline=os.clock()+(timeout or 5)
while os.clock()<deadline do
if evilCombineStopFlag then return false end
for _,m in pairs(ws.PlayerModels:GetChildren())do
if m:IsA("Model")and m.Name=="DuckEvil"and(not preSet or not preSet[m])then
return true
end
end
task.wait(0.2)
end
return false
end

-- ==================== 等待新恶魔鸭的 Main.PointLight 消失（合成彻底完成） ====================
local function waitEvilDuckLightGone(timeout)
local deadline=os.clock()+(timeout or 35)
while os.clock()<deadline do
if evilCombineStopFlag then return false end
local hasLight=false
for _,m in pairs(ws.PlayerModels:GetChildren())do
if m:IsA("Model")and m.Name=="DuckEvil"then
local main=m:FindFirstChild("Main")
if main and main:FindFirstChild("PointLight")then hasLight=true break end
end
end
if not hasLight then return true end
task.wait(0.2)
end
return false
end

local function startEvilDuckCombine(basePos)
local items={}

for i=1,3 do
local key=selectedMaterialKeys[i]
if not key then
notify("雪糕",string.format("第 %d 个材料未选择",i),3)
return
end
local item=findItemByKey(key,true)
if not item then
notify("雪糕",string.format("第 %d 个材料不存在且无同类物品，请重新选择",i),3)
return
end
items[i]=item
selectedMaterialKeys[i]=getItemKey(item)
end

local hrp=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
local originalPos=basePos or(hrp and hrp.CFrame)
if not originalPos then
notify("雪糕","无法获取玩家位置",3)
return false
end

local preDucks={}
for _,m in pairs(ws.PlayerModels:GetChildren())do
if m:IsA("Model")and m.Name=="DuckEvil"then preDucks[m]=true end
end

-- 反复拖拽+打开，直到新恶魔鸭出现（5秒内没出现就重新拖拽一遍，最多4轮）
local ok=false
for attempt=1,4 do
if evilCombineStopFlag then return false end
if attempt>1 then
notify("雪糕",string.format("5秒内未出现新恶魔鸭，重新拖拽（第 %d 轮）",attempt),3)
end

-- 阶段1：先把 3 个材料全部拖到固定位置（拖完为止）
for i=1,3 do
local item=items[i]
if not item or not item.Parent then
local key=selectedMaterialKeys[i]
if key then
item=findItemByKey(key,true)
end
if not item then
notify("雪糕",string.format("第 %d 个材料消失，合成中止",i),3)
return false
end
items[i]=item
end

if not waitItemReady(item,3)then
notify("雪糕",string.format("第 %d 个材料尚未就绪，拖拽/打开可能失败",i),2)
end

local primary=item.PrimaryPart or item:FindFirstChild("Main")or item:FindFirstChild("WoodSection")or item:FindFirstChildWhichIsA("BasePart")
if not primary then
notify("雪糕",string.format("第 %d 个材料无法定位部件",i),2)
return false
end
if not item.PrimaryPart then item.PrimaryPart=primary end

-- 拖拽时也锁定人物（悬空防布娃娃/移动，不挤物品），拖完再解锁
lockPlayerAt(primary.CFrame+Vector3.new(2,0,0))

-- 先请求物品所有权（游戏拖拽必须走这个，否则服务器不承认位置）
pcall(function()rep.Interaction.ClientRequestOwnership:FireServer(primary)end)
dragToPosition(item,dragTargets[i],nil,true)

unlockPlayer()

notify("雪糕",string.format("第 %d 个材料已拖到 %d 号位",i,i),2)
end

-- 阶段2：全部拖完后，再一个一个传过去打开
for i=1,3 do
local item=items[i]
if not item or not item.Parent then
local key=selectedMaterialKeys[i]
if key then
item=findItemByKey(key,true)
end
if not item then
notify("雪糕",string.format("第 %d 个材料消失，合成中止",i),3)
return false
end
items[i]=item
end

local posIdx=i
-- 锁定到物品正上方悬空（+4 格，脚底不碰物品，避免物理挤飞物品）
local dp2=item.PrimaryPart or item:FindFirstChild("Main")or item:FindFirstChild("WoodSection")or item:FindFirstChildWhichIsA("BasePart")
if dp2 then
if not item.PrimaryPart then item.PrimaryPart=dp2 end
local lockCF=dp2.CFrame+Vector3.new(2,0,0)
lockPlayerAt(lockCF)
task.wait(0.5)
openItem(item)
task.wait(0.4)
unlockPlayer()
else
safeTeleport(openPositions[posIdx])
lockPlayerAt(openPositions[posIdx]+Vector3.new(2,0,0))
task.wait(0.5)
openItem(item)
task.wait(0.4)
unlockPlayer()
end

notify("雪糕",string.format("已打开第 %d 个材料（%d 号位）",i,posIdx),2)
end

safeTeleport(originalPos)
task.wait(0.1)

-- 5秒内没出现新鸭子 → 跳出本轮，重新拖拽一遍
if waitEvilDuckAppear(5, preDucks)then
ok=waitEvilDuckLightGone(35)
if ok then
-- 把新生成的恶魔鸭拖回用户原本位置
local newDuck=nil
for _,m in pairs(ws.PlayerModels:GetChildren())do
if m:IsA("Model")and m.Name=="DuckEvil"and not preDucks[m]then
newDuck=m
break
end
end
if newDuck then
local dp=newDuck.PrimaryPart or newDuck:FindFirstChild("Main")or newDuck:FindFirstChildWhichIsA("BasePart")
if dp then
if not newDuck.PrimaryPart then newDuck.PrimaryPart=dp end
safeTeleport(dp.CFrame+Vector3.new(0,0.5,0))
dragToPosition(newDuck,originalPos,nil,true)
notify("雪糕","新恶魔鸭已拖回原位置",3)
end
end
break
end
end
end

if ok then
notify("雪糕","恶魔鸭合成完成！",3)
else
notify("雪糕","恶魔鸭合成未完成（多次拖拽后新鸭仍未出现或 PointLight 未消失）",3)
end
return ok
end

local function selectMaterial(index)
notify("雪糕",string.format("请点击第 %d 个属于自己的物品",index),4)
local conn
conn=mouse.Button1Up:Connect(function()
conn:Disconnect()
local target=mouse.Target
if not target then notify("雪糕","未选中任何物品",2);return end
local model=target:FindFirstAncestorWhichIsA("Model")
if not model or not model:FindFirstChild("Owner")or model.Owner.Value~=lp then
notify("雪糕","只能选择自己的物品",2)
return
end
local key=getItemKey(model)
if not key then
notify("雪糕","无法识别该物品类型",2)
return
end
selectedMaterialKeys[index]=key
highlightModel(model)
notify("雪糕",string.format("已选中第 %d 个材料: %s",index,model.Name),2)
end)
end

SectionEVIL:Button("选择第1个材料",function()selectMaterial(1)end)
SectionEVIL:Button("选择第2个材料",function()selectMaterial(2)end)
SectionEVIL:Button("选择第3个材料",function()selectMaterial(3)end)

SectionEVIL:Button("显示当前已选材料",function()
local msg={}
for i=1,3 do
local key=selectedMaterialKeys[i]
if key then
local item=findItemByKey(key,false)
if item then
msg[i]=string.format("第%d个: %s",i,item.Name)
else
msg[i]=string.format("第%d个: [已消失，合成时会自动匹配同类]",i)
end
else
msg[i]=string.format("第%d个: 未选择",i)
end
end
notify("雪糕",table.concat(msg,"\n"),5)
end)

SectionEVIL:Button("开始合成恶魔鸭",function()
for i=1,3 do
if not selectedMaterialKeys[i]then
notify("雪糕",string.format("第 %d 个材料未选择，请先选择",i),3)
return
end
end
startEvilDuckCombine()
end)

local function getMaterialBuyName(key)
if not key then return nil end
local _,value=key:match("^(.-):(.+)$")
if not value or value==""then return nil end
return value
end

SectionEVIL:Textbox("合成数量","EvilCombineCount","1",function(v)
local num=tonumber(v)
if num and num>0 then evilCombineCount=math.floor(num)end
end)

SectionEVIL:Button("自动合成恶魔鸭（自动买材料）",function()
local names,iderr=getEvilMaterialNames()
if not names then
notify("雪糕","识别材料失败: "..tostring(iderr),3)
return
end
for i=1,3 do
local nm=names[i]
if nm and nm.item then
selectedMaterialKeys[i]="ItemName:"..nm.item
notify("雪糕",string.format("已识别材料 %d: %s",i,nm.item),2)
else
if not selectedMaterialKeys[i]then
notify("雪糕",string.format("第 %d 个材料识别失败（%s），请用\"选择第%d个材料\"手动点选",i,nm and nm.display or"未找到",i),3)
return
end
notify("雪糕",string.format("材料 %d 识别失败，沿用已手动选择项",i),2)
end
end
local count=evilCombineCount or 1
if count<=0 then count=1 end
if evilAutoRunning then
notify("雪糕","自动合成已在运行中",3)
return
end
if not _G.qSnowBuyBlueprintBox then
notify("雪糕","自动购买模块未加载，无法买材料",4)
return
end
evilAutoRunning=true
evilCombineStopFlag=false
if _G.qSnowResetBuyStopFlag then pcall(_G.qSnowResetBuyStopFlag)end
task.spawn(function()
local baseHrp=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
local basePos=baseHrp and baseHrp.CFrame
local successCount=0
for c=1,count do
if evilCombineStopFlag then break end
notify("雪糕",string.format("=== 第 %d/%d 次合成 ===",c,count),2)
for i=1,3 do
if evilCombineStopFlag then break end
local key=selectedMaterialKeys[i]
if findItemByKey(key,false)then
notify("雪糕",string.format("材料 %d 已有，跳过购买",i),2)
else
local buyName=getMaterialBuyName(key)
if not buyName then
notify("雪糕",string.format("第 %d 个材料名字无效",i),3)
else
local box,err
for r=1,3 do
if evilCombineStopFlag then break end
box,err=_G.qSnowBuyBlueprintBox(buyName)
if box then break end
notify("雪糕",string.format("购买材料 %d 失败（第 %d 次重试）: %s",i,r,tostring(err or"未知")),3)
task.wait(0.6)
end
if box then
notify("雪糕",string.format("已购买材料 %d: %s",i,buyName),2)
else
notify("雪糕",string.format("材料 %d 购买失败，重试3次仍未成功",i),3)
end
end
end
task.wait(0.6)
end
if evilCombineStopFlag then break end
local ok=startEvilDuckCombine(basePos)
if evilCombineStopFlag then break end
if ok then
successCount=successCount+1
notify("雪糕",string.format("第 %d 次合成完成（新恶魔鸭已生成，PointLight 已消失）",c),2)
else
notify("雪糕","合成未完成，重新把物品拖回合成位置",3)
for i=1,3 do
local key=selectedMaterialKeys[i]
if key then
local item=findItemByKey(key,true)
if item then
local p=item.PrimaryPart or item:FindFirstChild("Main")or item:FindFirstChild("WoodSection")or item:FindFirstChildWhichIsA("BasePart")
if p then
if not item.PrimaryPart then item.PrimaryPart=p end
pcall(function()rep.Interaction.ClientRequestOwnership:FireServer(p)end)
end
dragToPosition(item,dragTargets[i])
end
end
task.wait(0.3)
end
end
if basePos then safeTeleport(basePos)end
task.wait(1)
end
evilAutoRunning=false
if basePos then safeTeleport(basePos)end
notify("雪糕",string.format("恶魔鸭自动合成结束：成功 %d 次",successCount),4)
end)
end)

SectionEVIL:Button("停止自动合成",function()
evilCombineStopFlag=true
notify("雪糕","已发送停止信号",3)
end)

-- ==================== 自动合成核心（生成 EvilHeart） ====================
 evilHeathStopFlag=false
 evilHeathAutoRunning=false
 evilHeathCount=1

local evilHeathMaterials={"HappyBall","Egg","Cocoa"}
local evilHeathDragTargets={
[1]=CFrame.new(-515.637939,-86.914101,-2013.382812),
[2]=CFrame.new(-526.625244,-86.957069,-2017.517578),
[3]=CFrame.new(-536.980713,-86.994179,-2021.368164)
}

local function waitEvilHeartAppear(timeout, preSet)
local deadline=os.clock()+(timeout or 10)
while os.clock()<deadline do
if evilHeathStopFlag then return false end
for _,m in pairs(ws.PlayerModels:GetChildren())do
if m:IsA("Model")and m.Name=="EvilHeart"and(not preSet or not preSet[m])then
return true
end
end
task.wait(0.2)
end
return false
end

local function startEvilHeartCombine(basePos)
local hrp=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
local originalPos=basePos or(hrp and hrp.CFrame)
if not originalPos then
notify("雪糕","无法获取玩家位置",3)
return false
end
local preHeaths={}
for _,m in pairs(ws.PlayerModels:GetChildren())do
if m:IsA("Model")and m.Name=="EvilHeart"then preHeaths[m]=true end
end
local ok=false
for attempt=1,4 do
if evilHeathStopFlag then return false end
if attempt>1 then notify("雪糕",string.format("5秒内未出现新EvilHeart，重新拖拽（第 %d 轮）",attempt),3)end
local items={}
for i=1,3 do
if evilHeathStopFlag then return false end
local buyName=evilHeathMaterials[i]
local key="ItemName:"..buyName
local item=findItemByKey(key,false)
if not item then
if not _G.qSnowBuyBlueprintBox then
notify("雪糕","自动购买模块未加载，无法购买材料 "..buyName,4)
return false
end
local box,err
for r=1,3 do
if evilHeathStopFlag then return false end
box,err=_G.qSnowBuyBlueprintBox(buyName)
if box then break end
notify("雪糕",string.format("购买材料 %s 失败（第 %d 次重试）: %s",buyName,r,tostring(err or"未知")),3)
task.wait(0.6)
end
if not box then notify("雪糕",string.format("材料 %s 购买失败，重试3次仍未成功",buyName),3)end
item=box or findItemByKey(key,true)
end
if not item then notify("雪糕",string.format("材料 %s 无法获取",buyName),3)return false end
items[i]=item
if not waitItemReady(item,3)then
notify("雪糕",string.format("材料 %s 尚未就绪",buyName),2)
end
local primary=item.PrimaryPart or item:FindFirstChild("Main")or item:FindFirstChild("WoodSection")or item:FindFirstChildWhichIsA("BasePart")
if primary then
if not item.PrimaryPart then item.PrimaryPart=primary end
lockPlayerAt(primary.CFrame+Vector3.new(2,0,0))
dragToPosition(item,evilHeathDragTargets[i],nil,true)
unlockPlayer()
notify("雪糕",string.format("%s 已拖到 %d 号位",buyName,i),2)
end
end
for i=1,3 do
if evilHeathStopFlag then return false end
local item=items[i]
if not item or not item.Parent then
local key="ItemName:"..evilHeathMaterials[i]
item=findItemByKey(key,true)
end
if item and item.Parent then
local p2=item.PrimaryPart or item:FindFirstChild("Main")or item:FindFirstChildWhichIsA("BasePart")
if p2 then
if not item.PrimaryPart then item.PrimaryPart=p2 end
local lockCF=p2.CFrame+Vector3.new(2,0,0)
lockPlayerAt(lockCF)
task.wait(0.5)
end
local opened=openItem(item)
task.wait(0.4)
unlockPlayer()
notify("雪糕",string.format("已打开 %s（%d 号位）",evilHeathMaterials[i],i),2)
end
end
if waitEvilHeartAppear(10, preHeaths)then
ok=true
local newHeath=nil
for _,m in pairs(ws.PlayerModels:GetChildren())do
if m:IsA("Model")and m.Name=="EvilHeart"and not preHeaths[m]then
newHeath=m
break
end
end
if newHeath then
local dp=newHeath.PrimaryPart or newHeath:FindFirstChild("Main")or newHeath:FindFirstChildWhichIsA("BasePart")
if dp then
if not newHeath.PrimaryPart then newHeath.PrimaryPart=dp end
safeTeleport(dp.CFrame+Vector3.new(0,0.5,0))
dragToPosition(newHeath,originalPos,nil,true)
notify("雪糕","新EvilHeart已拖回原位置",3)
end
end
break
end
end
if ok then
notify("雪糕","EvilHeart 合成完成！",3)
else
notify("雪糕","EvilHeart 合成未完成（多次拖拽后仍未出现）",3)
end
safeTeleport(originalPos)
return ok
end

SectionEVIL:Textbox("EvilHeart合成数量","EvilHeartCount","1",function(v)
local num=tonumber(v)
if num and num>0 then evilHeathCount=math.floor(num)end
end)

SectionEVIL:Button("自动合成核心（生成EvilHeart）",function()
if evilHeathAutoRunning then
notify("雪糕","EvilHeart自动合成已在运行中",3)
return
end
if not _G.qSnowBuyBlueprintBox then
notify("雪糕","自动购买模块未加载，无法买材料",4)
return
end
evilHeathAutoRunning=true
evilHeathStopFlag=false
task.spawn(function()
local baseHrp=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
local basePos=baseHrp and baseHrp.CFrame
local successCount=0
local total=evilHeathCount or 1
for c=1,total do
if evilHeathStopFlag then break end
notify("雪糕",string.format("=== 第 %d/%d 次 EvilHeart 合成 ===",c,total),2)
if startEvilHeartCombine(basePos) then
successCount=successCount+1
notify("雪糕",string.format("第 %d 次 EvilHeart 合成完成",c),2)
else
notify("雪糕",string.format("第 %d 次 EvilHeart 合成未完成",c),3)
end
if basePos then safeTeleport(basePos)end
task.wait(1)
end
evilHeathAutoRunning=false
if basePos then safeTeleport(basePos)end
notify("雪糕",string.format("EvilHeart 自动合成结束：成功 %d 次",successCount),4)
end)
end)

SectionEVIL:Button("停止EvilHeart合成",function()
evilHeathStopFlag=true
notify("雪糕","已发送停止信号",3)
end)

Section3:Slider('设置速度','Sliderflag',16,100,600,false,function(s)
bai.walkspeed=s
spawn(function()
while task.wait()do
if lp.Character then lp.Character.Humanoid.WalkSpeed=bai.walkspeed end
end
end)
end)
Section3:Slider('设置跳跃','Sliderflag',50,50,600,false,function(s)
bai.JumpPower=s
spawn(function()
while task.wait()do
if lp.Character then lp.Character.Humanoid.JumpPower=bai.JumpPower end
end
end)
end)
Section3:Slider('设置重力','Sliderflag',198,-999,999,false,function(s)
game.workspace.Gravity=s
end)
Section3:Slider('设置相机焦距','Sliderflag',100,0,9999,false,function(s)
lp.CameraMaxZoomDistance=s
end)
Section3:Toggle("穿墙",'Toggleflag',false,function(state)
applyNoClip(state)
end)
Section3:Toggle("自身发光",'Toggleflag',false,function(state)
if state then
local light=Instance.new('PointLight',lp.Character.Head);light.Name='bai';light.Range=150;light.Brightness=1.7
else
pcall(function()lp.Character.Head.bai:remove()end)
end
end)
Section3:Button("加载隐身脚本",function()
loadstring(game:HttpGet("http://qinscript.lol/333/隐身开源.lua"))()
end)
Section3:Button("安全自杀（删除头部）",function()
lp.Character.Head:Destroy()
end)
Section3:Button("解锁最大焦距",function()
lp.CameraMaxZoomDistance=9e9
end)

Section4:Dropdown("传送","Dropdown",{
"出生点","木材反斗城","回家","连接逻辑店","土地商店","会员商店","画店",
"桥对岸","沙滩","火木","雪山","洞穴","码头","黑市","糖果原","雪地入口",
"盖克斯航运","玻璃冰木入口","云层","山边商品","章鱼哥祭坛","沼泽商店",
"石头商店","沼泽","冰胡","沙漠","辐射商店","核污染区","种子商人",
"鲍勃的店","家具店","车店","罗布克斯商店","肯德坤专卖店","秋季商店"
},function(b)
local list=b
if list=="出生点"then
tp(CFrame.new(187,3,55))
elseif list=="木材反斗城"then
tp(CFrame.new(265,5,57))
elseif list=="洞穴"then
tp(CFrame.new(3581,-177,430))
elseif list=="连接逻辑店"then
tp(CFrame.new(4607,9,-798))
elseif list=="雪山"then
tp(CFrame.new(1451.66248,412.208405,3183.47607))
elseif list=="土地商店"then
tp(CFrame.new(258,5,-99))
elseif list=="画店"then
tp(CFrame.new(5207,-156,719))
elseif list=="火木"then
tp(CFrame.new(-1585,625,1140))
elseif list=="沙滩"then
tp(CFrame.new(2549,5,-42))
elseif list=="桥对岸"then
tp(CFrame.new(109,5,-1166))
elseif list=="会员商店"then
tp(CFrame.new(907,4,-92))
elseif list=="码头"then
tp(CFrame.new(1122,1,-203))
elseif list=="黑市"then
tp(CFrame.new(-22,61,1377))
elseif list=="糖果原"then
tp(CFrame.new(-561,272,2312))
elseif list=="雪地入口"then
tp(CFrame.new(888,61,1188))
elseif list=="盖克斯航运"then
tp(CFrame.new(1894,-2,1581))
elseif list=="玻璃冰木入口"then
tp(CFrame.new(1929,256,2918))
elseif list=="云层"then
tp(CFrame.new(2073,495,2967))
elseif list=="山边商品"then
tp(CFrame.new(-640,160,374))
elseif list=="章鱼哥祭坛"then
tp(CFrame.new(-1622,196,941))
elseif list=="沼泽商店"then
tp(CFrame.new(-1274,133,-1443))
elseif list=="沼泽"then
tp(CFrame.new(-999,133,-1191))
elseif list=="石头商店"then
tp(CFrame.new(-2387,302,-1899))
elseif list=="冰胡"then
tp(CFrame.new(-2149,321,743))
elseif list=="沙漠"then
tp(CFrame.new(-612,46,-3169))
elseif list=="辐射商店"then
tp(CFrame.new(172,12,-2627))
elseif list=="核污染区"then
tp(CFrame.new(207,15,-2752))
elseif list=="种子商人"then
tp(CFrame.new(-24,18,-2684))
elseif list=="鲍勃的店"then
tp(CFrame.new(261,9,-2541))
elseif list=="家具店"then
tp(CFrame.new(492,4,-1723))
elseif list=="车店"then
tp(CFrame.new(512,4,-1459))
elseif list=="罗布克斯商店"then
tp(CFrame.new(652,4,-1589))
elseif list=="肯德坤专卖店"then
tp(CFrame.new(65,4,-455))
elseif list=="秋季商店"then
tp(CFrame.new(6004,4,33))
elseif list=="回家"then
for i,v in pairs(game.Workspace.Properties:GetChildren())do
if v.Owner.Value==lp then
tp(v.OriginSquare.CFrame+Vector3.new(0,10,0))
break
end
end
end
end)

local teleList={
"恶魔鸭合成地点","裂纹木所在地","回家","连接逻辑店","土地商店","会员商店","画店",
"桥对岸","沙滩","火木","雪山","洞穴","码头","黑市","糖果原","雪地入口",
"盖克斯航运","玻璃冰木入口","云层","山边商品","章鱼哥祭坛","沼泽商店",
"石头商店","沼泽","冰胡","星星岛","辐射商店","核污染区","种子商人",
"鲍勃的店","家具店","车店","罗布克斯商店","肯德坤专卖店","秋季商店"
}

Section6:Dropdown("传送",'Dropdown',teleList,function(val)
local cf=nil
if val=="出生点"then
cf=CFrame.new(187,5,55)
elseif val=="回家"then
for _,v in pairs(workspace.Properties:GetChildren())do
if v.Owner.Value==lp then
cf=v.OriginSquare.CFrame+Vector3.new(0,10,0)
break
end
end
elseif val=="连接逻辑店"then
cf=CFrame.new(4607,9,-740)
elseif val=="土地商店"then
cf=CFrame.new(230,5,-99)
elseif val=="会员商店"then
cf=CFrame.new(907,4,-115)
elseif val=="画店"then
cf=CFrame.new(5207,-156,719)
elseif val=="桥对岸"then
cf=CFrame.new(109,5,-1166)
elseif val=="沙滩"then
cf=CFrame.new(2549,5,-42)
elseif val=="火木"then
cf=CFrame.new(-1585,625,1140)
elseif val=="雪山"then
cf=CFrame.new(1451.66248,412.208405,3183.47607)
elseif val=="洞穴"then
cf=CFrame.new(3581,-177,430)
elseif val=="码头"then
cf=CFrame.new(1122,1,-203)
elseif val=="黑市"then
cf=CFrame.new(-15,61,1365)
elseif val=="糖果原"then
cf=CFrame.new(-561,272,2312)
elseif val=="雪地入口"then
cf=CFrame.new(888,61,1188)
elseif val=="盖克斯航运"then
cf=CFrame.new(1894,-2,1581)
elseif val=="玻璃冰木入口"then
cf=CFrame.new(1929,256,2918)
elseif val=="云层"then
cf=CFrame.new(2060,495,2967)
elseif val=="山边商品"then
cf=CFrame.new(-640,160,374)
elseif val=="章鱼哥祭坛"then
cf=CFrame.new(-1622,196,941)
elseif val=="沼泽商店"then
cf=CFrame.new(-1274,133,-1443)
elseif val=="石头商店"then
cf=CFrame.new(-2395,302,-1899)
elseif val=="沼泽"then
cf=CFrame.new(-999,133,-1191)
elseif val=="冰胡"then
cf=CFrame.new(-2149,321,743)
elseif val=="星星岛"then
cf=CFrame.new(-612,46,-3169)
elseif val=="辐射商店"then
cf=CFrame.new(172,12,-2627)
elseif val=="核污染区"then
cf=CFrame.new(207,15,-2752)
elseif val=="种子商人"then
cf=CFrame.new(-15,18,-2680)
elseif val=="鲍勃的店"then
cf=CFrame.new(245,9,-2541)
elseif val=="家具店"then
cf=CFrame.new(490,4,-1690)
elseif val=="车店"then
cf=CFrame.new(512,4,-1490)
elseif val=="罗布克斯商店"then
cf=CFrame.new(652,4,-1565)
elseif val=="肯德坤专卖店"then
cf=CFrame.new(100,4,-455)
elseif val=="秋季商店"then
cf=CFrame.new(6004,4,33)
end
if cf then
carTeleport(cf)
end
end)

Section:Toggle("自动扔斧头",'Toggleflag',false,function(state)
bai.autodropae=state
if state then
while task.wait()do
if bai.autodropae==true then
droptool(lp.Character.HumanoidRootPart.CFrame)
end
end
end
end)
Section:Toggle("自动捡斧头",'Toggleflag',false,function(state)
bai.autopick=state
if state then
while bai.autopick==true do
task.wait(0.5)
for a,b in pairs(workspace.PlayerModels:GetChildren())do
if b:FindFirstChild("Owner")and b.Owner.Value==lp then
if b:FindFirstChild("Type")and b.Type.Value=="Tool"then
rep.Interaction.ClientInteracted:FireServer(b,'Pick up tool')
end
end
end
end
end
end)

 teleportTargetCF=nil
 teleportTargetPlayer=lp.Name
 teleportMarker=nil

 selectingMode=false
 selectedItems={}
local selectionBoxes={}
 selectionConn=nil

local function setTeleportPoint()
if teleportMarker then pcall(function()teleportMarker:Destroy()end);teleportMarker=nil end
local hrp=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
if not hrp then notify("雪糕","无法获取玩家位置",3)return end
teleportTargetCF=hrp.CFrame
local marker=Instance.new("Part")
marker.Name="baiBasedropCord"
marker.Anchored=true
marker.Parent=workspace
marker.Shape=Enum.PartType.Ball
marker.Size=Vector3.new(2,2,2)
marker.Color=Color3.fromRGB(0,217,255)
marker.Material=Enum.Material.ForceField
marker.CFrame=teleportTargetCF
teleportMarker=marker
notify("雪糕","传送点已设置（球体标记）",3)
end

local function clearTeleportPoint()
if teleportMarker then pcall(function()teleportMarker:Destroy()end);teleportMarker=nil end
teleportTargetCF=nil
notify("雪糕","🗑️ 传送点已清除",3)
end

local function isSelectable(model)
if not model or not model:IsA("Model")then return false end

if model:FindFirstChild("BlueprintWoodClass")then
return false
end

if model:FindFirstChild("ButtonRemote_SpawnButton")then
return false
end

local name=model.Name or""
local hasPurchasedBoxItem=model:FindFirstChild("PurchasedBoxItemName")
local hasBoxItem=model:FindFirstChild("BoxItemName")
local hasType=model:FindFirstChild("Type")

if name:find("Crate")or name:find("Box")or name:find("Gift")then

local hasValidItem=false

if hasPurchasedBoxItem then
local val=hasPurchasedBoxItem.Value
if val and val~=""and val~=" "then
hasValidItem=true
end
end

if not hasValidItem and hasBoxItem then
local val=hasBoxItem.Value
if val and val~=""and val~=" "then
hasValidItem=true
end
end

if not hasValidItem and hasType then
local val=hasType.Value
if val and val~=""and val~=" "then
hasValidItem=true
end
end

if not hasValidItem then
return false
end
end

local targetPlayer=game.Players:FindFirstChild(teleportTargetPlayer)
if not targetPlayer then return false end

local owner=model:FindFirstChild("Owner")
if owner and owner.Value==targetPlayer then
return true
end

if workspace.LogModels:FindFirstChild(model.Name)==model then
if owner and owner.Value==targetPlayer then
return true
end
end

return false
end

local function highlightItem(model)
if selectionBoxes[model]then return end
local primary=model.PrimaryPart or model:FindFirstChild("Main")or model:FindFirstChild("WoodSection")or model:FindFirstChildWhichIsA("BasePart")
if not primary then return end
local box=Instance.new("SelectionBox")
box.Adornee=primary
box.Color3=Color3.fromRGB(0,255,0)
box.Transparency=0.5
box.LineThickness=0.05
box.Parent=primary
selectionBoxes[model]=box
end

local function unhighlightItem(model)
local box=selectionBoxes[model]
if box then
pcall(function()box:Destroy()end)
selectionBoxes[model]=nil
end
end

local function clearSelection()
for model,_ in pairs(selectedItems)do
unhighlightItem(model)
end
selectedItems={}
if selectionCountLabel then
selectionCountLabel:SetText("已选中: 0")
end
end

local function selectItem(model)
if not isSelectable(model)then
notify("雪糕","该物品不可选择或不属于所选玩家",2)
return
end
if selectedItems[model]then
unhighlightItem(model)
selectedItems[model]=nil
notify("雪糕","已取消选中: "..(model.Name or"物品"),2)
if selectionCountLabel then
local count=0
for _ in pairs(selectedItems)do count=count+1 end
selectionCountLabel:SetText("已选中: "..count)
end
return
end
selectedItems[model]=true
highlightItem(model)
notify("雪糕","已选中: "..(model.Name or"物品"),2)
if selectionCountLabel then
local count=0
for _ in pairs(selectedItems)do count=count+1 end
selectionCountLabel:SetText("已选中: "..count)
end
end

local function selectSameNameItems(sourceModel)
local firstModel=sourceModel or next(selectedItems)
if not firstModel then
notify("雪糕","请先至少选中一个物品",3)
return
end
local targetName=firstModel.Name
if not targetName then
notify("雪糕","无法获取物品名称",3)
return
end

local count=0

if sourceModel and not selectedItems[sourceModel]then
selectedItems[sourceModel]=true
highlightItem(sourceModel)
count=count+1
end

for _,model in pairs(workspace.PlayerModels:GetChildren())do
if model:IsA("Model")and isSelectable(model)then
if model.Name==targetName and not selectedItems[model]then
selectedItems[model]=true
highlightItem(model)
count=count+1
end
end
end

for _,log in pairs(workspace.LogModels:GetChildren())do
if isSelectable(log)then
if log.Name==targetName and not selectedItems[log]then
selectedItems[log]=true
highlightItem(log)
count=count+1
end
end
end

if count>0 then
notify("雪糕",string.format("已添加 %d 个同名物品",count),3)
else
notify("雪糕","没有找到其他同名物品",3)
end
if selectionCountLabel then
local total=0
for _ in pairs(selectedItems)do total=total+1 end
selectionCountLabel:SetText("已选中: "..total)
end
end

local function teleportSelectedItems()
if not teleportTargetCF then
notify("雪糕","请先设置传送点",3)
return
end

local all={}
for model,_ in pairs(selectedItems)do
if model and model.Parent then
local primary=model.PrimaryPart or model:FindFirstChild("Main")or model:FindFirstChild("WoodSection")or model:FindFirstChildWhichIsA("BasePart")
if primary then
if not model.PrimaryPart then model.PrimaryPart=primary end
table.insert(all,model)
end
end
end
if#all==0 then
notify("雪糕","没有选中的物品",3)
return
end

local originalPos=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
if originalPos then originalPos=originalPos.CFrame end

local successCount=0
for _,model in ipairs(all)do
if model.Parent and model.PrimaryPart then

pcall(function()safeTeleport(model.PrimaryPart.CFrame+Vector3.new(0,2,0))end)
task.wait(0.1)

dragToPosition(model,teleportTargetCF)

unhighlightItem(model)
selectedItems[model]=nil
successCount=successCount+1
end
end

if selectionCountLabel then
local remaining=0
for _ in pairs(selectedItems)do remaining=remaining+1 end
selectionCountLabel:SetText("已选中: "..remaining)
end

if originalPos and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")then
safeTeleport(originalPos)
end

notify("雪糕",string.format("传送完成，成功 %d / %d 个物品",successCount,#all),3)
end

local SectionTeleport=Tab:section("传送物品 (选择模式)",false)

 teleportPlayerDropdown=nil
local function refreshTeleportPlayerList()
local list={}
for _,p in pairs(game.Players:GetPlayers())do table.insert(list,p.Name)end
if teleportPlayerDropdown then
teleportPlayerDropdown:SetOptions(list)
if not table.find(list,teleportTargetPlayer)then
teleportPlayerDropdown:SetValue(lp.Name)
end
end
end

teleportPlayerDropdown=SectionTeleport:Dropdown("选择玩家","TeleportPlayerDropdown",{lp.Name},function(v)
teleportTargetPlayer=v
clearSelection()
end)
refreshTeleportPlayerList()

SectionTeleport:Button("刷新玩家列表",refreshTeleportPlayerList)

SectionTeleport:Button("设置传送点（当前位置）",setTeleportPoint)
SectionTeleport:Button("删除传送点",clearTeleportPoint)

_G.qsMain=_G.qsMain or {}
for k,v in pairs({createEspFrame=createEspFrame,removeEspFrame=removeEspFrame,updateEsp=updateEsp,enableEsp=enableEsp,disableEsp=disableEsp,bailib=bailib,win=win,Tab1=Tab1,Tab=Tab,Tab2=Tab2,Tab4=Tab4,Section3=Section3,Section4=Section4,Section6=Section6,Sectionbringtree=Sectionbringtree,Section5=Section5,SectionDuck=SectionDuck,Sectiontuozhuai=Sectiontuozhuai,SectionEVIL=SectionEVIL,SectionESP=SectionESP,Section1=Section1,Section=Section,Sectionshuaxin=Sectionshuaxin,Sectionyanjiang=Sectionyanjiang,Sectionqita=Sectionqita,Sectionzhengli=Sectionzhengli,Sectionhuanjin=Sectionhuanjin,Sectionmogui=Sectionmogui,getSortItemType=getSortItemType,getModelSize=getModelSize,getModelBottom=getModelBottom,isSortable=isSortable,giveSortTool=giveSortTool,selectedMaterialKeys=selectedMaterialKeys,dragTargets=dragTargets,openPositions=openPositions,highlightModel=highlightModel,getItemKey=getItemKey,findItemByKey=findItemByKey,openItem=openItem,waitItemReady=waitItemReady,waitEvilDuckAppear=waitEvilDuckAppear,waitEvilDuckLightGone=waitEvilDuckLightGone,startEvilDuckCombine=startEvilDuckCombine,selectMaterial=selectMaterial,getMaterialBuyName=getMaterialBuyName,evilHeathMaterials=evilHeathMaterials,evilHeathDragTargets=evilHeathDragTargets,waitEvilHeartAppear=waitEvilHeartAppear,startEvilHeartCombine=startEvilHeartCombine,teleList=teleList,selectionBoxes=selectionBoxes,setTeleportPoint=setTeleportPoint,clearTeleportPoint=clearTeleportPoint,isSelectable=isSelectable,highlightItem=highlightItem,unhighlightItem=unhighlightItem,clearSelection=clearSelection,selectItem=selectItem,selectSameNameItems=selectSameNameItems,teleportSelectedItems=teleportSelectedItems,SectionTeleport=SectionTeleport,refreshTeleportPlayerList=refreshTeleportPlayerList})do _G.qsMain[k]=v end

]====]
local SRC_MAIN3 = [====[
_G.qsMain=_G.qsMain or {}
local gs=_G.qsMain.gs
local lp=_G.qsMain.lp
local ws=_G.qsMain.ws
local rep=_G.qsMain.rep
local mouse=_G.qsMain.mouse
local defaultDragAttempts=_G.qsMain.defaultDragAttempts
local defaultDragInterval=_G.qsMain.defaultDragInterval
local CONFIG_FILE=_G.qsMain.CONFIG_FILE
local loadDragConfig=_G.qsMain.loadDragConfig
local duckCycleIndex=_G.qsMain.duckCycleIndex
local bai=_G.qsMain.bai
local voidSaplingRunning=_G.qsMain.voidSaplingRunning
local shuaxinlb=_G.qsMain.shuaxinlb
local uprightCFrame=_G.qsMain.uprightCFrame
local safeTeleport=_G.qsMain.safeTeleport
local unlockPlayer=_G.qsMain.unlockPlayer
local lockPlayerAt=_G.qsMain.lockPlayerAt
local carTeleport=_G.qsMain.carTeleport
local tp=_G.qsMain.tp
local droptool=_G.qsMain.droptool
local saveDragConfig=_G.qsMain.saveDragConfig
local treeMapping=_G.qsMain.treeMapping
local treeNames=_G.qsMain.treeNames
local getNextDragID=_G.qsMain.getNextDragID
local DRAG_TOTAL=_G.qsMain.DRAG_TOTAL
local DRAG_SET_START=_G.qsMain.DRAG_SET_START
local DRAG_SET_COUNT=_G.qsMain.DRAG_SET_COUNT
local DRAG_SET_INTERVAL=_G.qsMain.DRAG_SET_INTERVAL
local DRAG_REFRESH_INTERVAL=_G.qsMain.DRAG_REFRESH_INTERVAL
local DRAG_AFTER_WAIT=_G.qsMain.DRAG_AFTER_WAIT
local dragToPosition=_G.qsMain.dragToPosition
local findUncutTree=_G.qsMain.findUncutTree
local axeConfigCache=_G.qsMain.axeConfigCache
local loadWeaponConfig=_G.qsMain.loadWeaponConfig
local selectBestWeapon=_G.qsMain.selectBestWeapon
local bringTreeRemote=_G.qsMain.bringTreeRemote
local safeTeleportNoWait=_G.qsMain.safeTeleportNoWait
local getBestAxeData=_G.qsMain.getBestAxeData
local getTreeClassFromModel=_G.qsMain.getTreeClassFromModel
local forceDragUntilProcessed=_G.qsMain.forceDragUntilProcessed
local decomposeAndProcess=_G.qsMain.decomposeAndProcess
local startDecomposeSelection=_G.qsMain.startDecomposeSelection
local deleteLavaObjectsOnce=_G.qsMain.deleteLavaObjectsOnce
local startAutoDelete=_G.qsMain.startAutoDelete
local stopAutoDelete=_G.qsMain.stopAutoDelete
local executeSequenceAndReturn=_G.qsMain.executeSequenceAndReturn
local bringDuck=_G.qsMain.bringDuck
local bringDuckc=_G.qsMain.bringDuckc
local translateEvilNotes=_G.qsMain.translateEvilNotes
local evilNoteItemMap=_G.qsMain.evilNoteItemMap
local getEvilMaterialNames=_G.qsMain.getEvilMaterialNames
local craftRevengeSword=_G.qsMain.craftRevengeSword
local craftLunarDuck=_G.qsMain.craftLunarDuck
local refreshPrivateServer=_G.qsMain.refreshPrivateServer
local setDragEnhance=_G.qsMain.setDragEnhance
local applyNoClip=_G.qsMain.applyNoClip
local addHighlightToModel=_G.qsMain.addHighlightToModel
local removeHighlightFromModel=_G.qsMain.removeHighlightFromModel
local addDuckOutline=_G.qsMain.addDuckOutline
local removeDuckOutline=_G.qsMain.removeDuckOutline
local syncDuckHighlights=_G.qsMain.syncDuckHighlights
local enableDuckOutline=_G.qsMain.enableDuckOutline
local disableDuckOutline=_G.qsMain.disableDuckOutline
local isVoidCrate=_G.qsMain.isVoidCrate
local addVoidCrateHighlight=_G.qsMain.addVoidCrateHighlight
local removeVoidCrateHighlight=_G.qsMain.removeVoidCrateHighlight
local syncVoidCrateHighlights=_G.qsMain.syncVoidCrateHighlights
local enableVoidCrateOutline=_G.qsMain.enableVoidCrateOutline
local disableVoidCrateOutline=_G.qsMain.disableVoidCrateOutline
local createEspFrame=_G.qsMain.createEspFrame
local removeEspFrame=_G.qsMain.removeEspFrame
local updateEsp=_G.qsMain.updateEsp
local enableEsp=_G.qsMain.enableEsp
local disableEsp=_G.qsMain.disableEsp
local bailib=_G.qsMain.bailib
local win=_G.qsMain.win
local Tab1=_G.qsMain.Tab1
local Tab=_G.qsMain.Tab
local Tab2=_G.qsMain.Tab2
local Tab4=_G.qsMain.Tab4
local Section3=_G.qsMain.Section3
local Section4=_G.qsMain.Section4
local Section6=_G.qsMain.Section6
local Sectionbringtree=_G.qsMain.Sectionbringtree
local Section5=_G.qsMain.Section5
local SectionDuck=_G.qsMain.SectionDuck
local Sectiontuozhuai=_G.qsMain.Sectiontuozhuai
local SectionEVIL=_G.qsMain.SectionEVIL
local SectionESP=_G.qsMain.SectionESP
local Section1=_G.qsMain.Section1
local Section=_G.qsMain.Section
local Sectionshuaxin=_G.qsMain.Sectionshuaxin
local Sectionyanjiang=_G.qsMain.Sectionyanjiang
local Sectionqita=_G.qsMain.Sectionqita
local Sectionzhengli=_G.qsMain.Sectionzhengli
local Sectionhuanjin=_G.qsMain.Sectionhuanjin
local Sectionmogui=_G.qsMain.Sectionmogui
local getSortItemType=_G.qsMain.getSortItemType
local getModelSize=_G.qsMain.getModelSize
local getModelBottom=_G.qsMain.getModelBottom
local isSortable=_G.qsMain.isSortable
local giveSortTool=_G.qsMain.giveSortTool
local selectedMaterialKeys=_G.qsMain.selectedMaterialKeys
local dragTargets=_G.qsMain.dragTargets
local openPositions=_G.qsMain.openPositions
local highlightModel=_G.qsMain.highlightModel
local findItemByKey=_G.qsMain.findItemByKey
local openItem=_G.qsMain.openItem
local waitItemReady=_G.qsMain.waitItemReady
local waitEvilDuckAppear=_G.qsMain.waitEvilDuckAppear
local waitEvilDuckLightGone=_G.qsMain.waitEvilDuckLightGone
local startEvilDuckCombine=_G.qsMain.startEvilDuckCombine
local selectMaterial=_G.qsMain.selectMaterial
local getMaterialBuyName=_G.qsMain.getMaterialBuyName
local evilHeathMaterials=_G.qsMain.evilHeathMaterials
local evilHeathDragTargets=_G.qsMain.evilHeathDragTargets
local waitEvilHeartAppear=_G.qsMain.waitEvilHeartAppear
local startEvilHeartCombine=_G.qsMain.startEvilHeartCombine
local teleList=_G.qsMain.teleList
local selectionBoxes=_G.qsMain.selectionBoxes
local setTeleportPoint=_G.qsMain.setTeleportPoint
local clearTeleportPoint=_G.qsMain.clearTeleportPoint
local isSelectable=_G.qsMain.isSelectable
local highlightItem=_G.qsMain.highlightItem
local unhighlightItem=_G.qsMain.unhighlightItem
local clearSelection=_G.qsMain.clearSelection
local selectItem=_G.qsMain.selectItem
local selectSameNameItems=_G.qsMain.selectSameNameItems
local teleportSelectedItems=_G.qsMain.teleportSelectedItems
local SectionTeleport=_G.qsMain.SectionTeleport
local refreshTeleportPlayerList=_G.qsMain.refreshTeleportPlayerList
do

local function isItem(m)
return m and m:IsA("Model")and(m:FindFirstChild("Owner")~=nil or m:FindFirstChild("Type")~=nil)
end

local function groupKey(m)
local owner=m:FindFirstChild("Owner")
if owner and owner.Value~=nil then
return m.Name,owner.Value
end
local t=m:FindFirstChild("Type")
return m.Name,(t and t.Value)or nil
end

local function scanSameName(sourceModel)
if not sourceModel then return 0 end
local tn,to=groupKey(sourceModel)
if not tn then return 0 end
local count=0
local function trySel(m)
if isItem(m)then
local n,o=groupKey(m)
if n==tn and o==to and not selectedItems[m]then
selectedItems[m]=true
highlightItem(m)
count=count+1
end
end
end
trySel(sourceModel)
for _,m in pairs(workspace.PlayerModels:GetDescendants())do trySel(m)end
for _,m in pairs(workspace.LogModels:GetDescendants())do trySel(m)end
pcall(function()
for _,store in pairs(StoresFolder:GetChildren())do
local si=store:FindFirstChild("ShopItems")
if si then
for _,m in pairs(si:GetDescendants())do trySel(m)end
end
end
end)
return count
end

local function cancelSameName(sourceModel)
local tn,to=groupKey(sourceModel)
local n=0
for m,_ in pairs(selectedItems)do
local mn,mo=groupKey(m)
if mn==tn and mo==to then
unhighlightItem(m)
selectedItems[m]=nil
n=n+1
end
end
return n
end

selectingToggle=SectionTeleport:Toggle("选择模式（点击选中/取消单个物品）","ToggleSelectMode",false,function(state)
selectingMode=state
if state then
if selectionConn then selectionConn:Disconnect()end
selectionConn=mouse.Button1Down:Connect(function()
if not selectingMode then return end
local target=mouse.Target
if not target then return end
if target:FindFirstAncestorOfClass("ScreenGui")then return end
local model=target:FindFirstAncestorOfClass("Model")
if not model then return end
if not isItem(model)then
notify("雪糕","不是物品（无 Type/Owner）",2)
return
end
if selectedItems[model]then
unhighlightItem(model)
selectedItems[model]=nil
notify("雪糕","已取消选中: "..model.Name,2)
else
selectedItems[model]=true
highlightItem(model)
notify("雪糕","已选中: "..model.Name,2)
end
end)
notify("雪糕","选择模式已开启（单件选中/取消）",3)
else
if selectionConn then selectionConn:Disconnect()end
selectionConn=nil
notify("雪糕","选择模式已关闭",3)
end
end)

SectionTeleport:Toggle("点击选择同名物品","ToggleSelectSameName",false,function(state)
bai.selectSameOwnerOn=state
if state then
if bai.selectSameOwnerConn then bai.selectSameOwnerConn:Disconnect()end
bai.selectSameOwnerConn=mouse.Button1Down:Connect(function()
if not bai.selectSameOwnerOn then return end
local target=mouse.Target
if not target then return end
if target:FindFirstAncestorOfClass("ScreenGui")then return end
local model=target:FindFirstAncestorOfClass("Model")
if not model then return end
if not isItem(model)then
notify("雪糕","不是物品（无 Type/Owner）",2)
return
end
if selectedItems[model]then
local n=cancelSameName(model)
notify("雪糕","已取消本组: "..n.." 个",2)
else
local n=scanSameName(model)
if n>0 then
notify("雪糕",string.format("已选中 %d 个同名物品",n),3)
else
notify("雪糕","没有找到同名物品",3)
end
end
end)
notify("雪糕","已开启：点击选中同组，再点取消同组",3)
else
if bai.selectSameOwnerConn then bai.selectSameOwnerConn:Disconnect()end
bai.selectSameOwnerConn=nil
notify("雪糕","已关闭",3)
end
end)
end

local selectionCountLabel=SectionTeleport:Label("已选中: 0")

SectionTeleport:Button("清空所有选中",function()
clearSelection()
end)

SectionTeleport:Button("传送所有选中物品",function()
if not teleportTargetCF then
notify("雪糕","请先设置传送点",3)
return
end
if not next(selectedItems)then
notify("雪糕","没有选中的物品",3)
return
end
task.spawn(teleportSelectedItems)
end)

SectionTeleport:Label("提示：1. 选择模式开启后点击物品只能选中，不能取消")
SectionTeleport:Label("      2. 同名字选择基于物品的 Name（如 Duck、Crate 等）")
SectionTeleport:Label("      3. 传送完毕后自动清空所有选中")
SectionTeleport:Label("      4. 自动过滤：建筑蓝图、车辆、已打开盒子（只剩Main且无有效物品属性）")

Section1:Button("点击土地免费获得",function()
local freeland=false
notify("雪糕","请你点击一个空的土地",4)
local click=mouse.Button1Up:Connect(function()
local target=mouse.Target.Parent
if target.Name=="Property"and target.Owner.Value==nil then
rep.PropertyPurchasing.ClientPurchasedProperty:FireServer(target,target.OriginSquare.OriginCFrame.Value.p+Vector3.new(0,3,0))
wait(0.5);freeland=true
Instance.new('RemoteEvent',game:service'ReplicatedStorage'.Interaction).Name="Ban"
lp.Character.HumanoidRootPart.CFrame=target.OriginSquare.CFrame+Vector3.new(0,10,0)
else notify("雪糕","这个土地有主人了",4)end
end)
repeat task.wait()until freeland
click:Disconnect()
end)
Section1:Button("最大土地（需拥有土地）",function()
local base,square
for _,v in pairs(workspace.Properties:GetChildren())do if v.Owner.Value==lp then base=v;square=v.OriginSquare end end
if not base then notify("雪糕","你没有土地",3)return end
local spos=square.Position
local function expand(pos)rep.PropertyPurchasing.ClientExpandedProperty:FireServer(base,pos)end
expand(CFrame.new(spos.X+40,spos.Y,spos.Z))
expand(CFrame.new(spos.X-40,spos.Y,spos.Z))
expand(CFrame.new(spos.X,spos.Y,spos.Z+40))
expand(CFrame.new(spos.X,spos.Y,spos.Z-40))
expand(CFrame.new(spos.X+40,spos.Y,spos.Z+40))
expand(CFrame.new(spos.X+40,spos.Y,spos.Z-40))
expand(CFrame.new(spos.X-40,spos.Y,spos.Z+40))
expand(CFrame.new(spos.X-40,spos.Y,spos.Z-40))
expand(CFrame.new(spos.X+80,spos.Y,spos.Z))
expand(CFrame.new(spos.X-80,spos.Y,spos.Z))
expand(CFrame.new(spos.X,spos.Y,spos.Z+80))
expand(CFrame.new(spos.X,spos.Y,spos.Z-80))
expand(CFrame.new(spos.X+80,spos.Y,spos.Z+80))
expand(CFrame.new(spos.X+80,spos.Y,spos.Z-80))
expand(CFrame.new(spos.X-80,spos.Y,spos.Z+80))
expand(CFrame.new(spos.X-80,spos.Y,spos.Z-80))
expand(CFrame.new(spos.X+40,spos.Y,spos.Z+80))
expand(CFrame.new(spos.X-40,spos.Y,spos.Z+80))
expand(CFrame.new(spos.X+80,spos.Y,spos.Z+40))
expand(CFrame.new(spos.X+80,spos.Y,spos.Z-40))
expand(CFrame.new(spos.X-80,spos.Y,spos.Z+40))
expand(CFrame.new(spos.X-80,spos.Y,spos.Z-40))
expand(CFrame.new(spos.X+40,spos.Y,spos.Z-80))
expand(CFrame.new(spos.X-40,spos.Y,spos.Z-80))
notify("雪糕","已尝试扩大土地",3)
end)
Section1:Textbox("选择存档编号 (1-8)",'TextBoxfalg',"输入1-8的数字",function(s)
bai.soltnumber=s
end)
Section1:Button("加载存档",function()
local slot=tonumber(bai.soltnumber)
if slot and slot>=1 and slot<=8 then
local success,err=pcall(function()return rep.LoadSaveRequests.RequestLoad:InvokeServer(slot)end)
if success then notify("雪糕","已尝试加载存档 "..slot,3)else notify("雪糕","加载失败: "..tostring(err),3)end
else notify("雪糕","存档编号无效",3)end
end)

Sectiontuozhuai:Toggle("拖拽器增强",'Toggleflag',false,function(state)
setDragEnhance(state)
end)
Section5:Button("传送所有木头到你脚下",function()
bringAllMyLogsToFeet()
end)
Section5:Button("卖木头",function()
task.spawn(function()sellAllWood()end)
end)
Section5:Button("卖木板",function()
task.spawn(function()sellAllPlanks()end)
end)
Section5:Button("卖木头+木板",function()
task.spawn(function()sellWoodAndPlanks()end)
end)
Section5:Button("停止出售",function()
stopSelling()
end)
Sectionshuaxin:Button("刷新私服（确保私服无人）",function()
refreshPrivateServer()
end)

Sectionyanjiang:Toggle("开启自动删除岩浆伤害",'Toggleflag',false,function(state)
if state then startAutoDelete(3)else stopAutoDelete()end
end)
Sectionyanjiang:Textbox("岩浆检查间隔（秒）",'TextBoxfalg',"默认 1",function(val)
local num=tonumber(val)
if num and num>0 then
if autoDeleteRunning then stopAutoDelete();task.wait(0.5);startAutoDelete(num)end
else notify("雪糕","请输入大于0的数字",2)end
end)
Sectionyanjiang:Button("手动执行一次岩浆删除",function()
deleteLavaObjectsOnce(false)
end)

Sectiontuozhuai:Textbox("次数",'TextBoxfalg',"5",function(v)
local num=tonumber(v);if num and num>0 then dragAttempts=num else notify("雪糕","请输入大于0的数字",2)end
end)
Sectiontuozhuai:Textbox("间隔",'TextBoxfalg',"0.04",function(v)
local num=tonumber(v);if num and num>0 then dragInterval=num else notify("雪糕","请输入大于0的数字",2)end
end)
Sectiontuozhuai:Button("保存配置",function()
saveDragConfig()
end)
Sectiontuozhuai:Button("删除配置",function()
if writefile then
local success,err=pcall(function()

if isfile and isfile(CONFIG_FILE)then
delfile(CONFIG_FILE)
end
end)
if success then

dragAttempts=defaultDragAttempts
dragInterval=defaultDragInterval
notify("雪糕","配置已删除，已恢复默认值 (次数="..defaultDragAttempts..", 间隔="..defaultDragInterval..")",3)
else
notify("雪糕","删除失败: "..tostring(err),3)
end
else
notify("雪糕","当前环境不支持删除配置文件",3)
end
end)

local treeNamesWithPlaceholder={"--- 请选择树木 ---"}
for _,name in ipairs(treeNames)do table.insert(treeNamesWithPlaceholder,name)end
 selectedTreeName=treeNamesWithPlaceholder[1]
 selectedTreeClass=nil

Sectionbringtree:Dropdown("选择树木种类",'Dropdown',treeNamesWithPlaceholder,function(b)
if b=="--- 请选择树木 ---"then
selectedTreeName=b;selectedTreeClass=nil
else
selectedTreeName=b;selectedTreeClass=treeMapping[b]
end
bai.cuttreeselect=selectedTreeClass or"Generic"
end)

 batchCount=1
Sectionbringtree:Textbox("数量","BatchCountBox",tostring(batchCount),function(v)
local num=tonumber(v)
if num and num>0 then
batchCount=math.floor(num)
else
notify("雪糕","请输入大于 0 的整数",2)
end
end)

 isRunning=false

Sectionbringtree:Button("带来树",function()
if isRunning then
notify("雪糕","任务正在运行中，请勿重复启动",2)
return
end
if not selectedTreeClass then
notify("雪糕","请先在下拉框中选择一种树木",3)
return
end
if batchCount<1 then
notify("雪糕","请设置有效的数量",3)
return
end

isRunning=true
task.spawn(function()
local successCount=0
local failCount=0
for i=1,batchCount do
if not isRunning then
notify("雪糕","任务已被用户停止",2)
break
end
if batchCount==1 then
notify("雪糕","开始砍树...",2)
else
notify("雪糕",string.format("开始第 %d/%d 次...",i,batchCount),2)
end
local ok=bringTreeRemote(selectedTreeClass)
if ok then
successCount=successCount+1
if batchCount>1 then
notify("雪糕",string.format("第 %d 次成功 (成功:%d, 失败:%d)",i,successCount,failCount),2)
end
else
failCount=failCount+1
notify("雪糕",string.format("第 %d 次失败，已停止",i),3)
break
end
task.wait(0.01)
end
if batchCount>1 then
notify("雪糕",string.format("全部完成 — 成功 %d 次，失败 %d 次",successCount,failCount),3)
else
if successCount==1 then
notify("雪糕","砍树完成",3)
end
end
isRunning=false
end)
end)

Sectionbringtree:Button("停止",function()
if isRunning then
isRunning=false
notify("雪糕","正在停止任务...",2)
else
notify("雪糕","当前没有运行中的任务",2)
end
end)

 spawnItemList={}
 selectedSpawnItem=""
 spawnLoopRunning=false
 spawnLoopTask=nil
local ITEM_LIST_URL="http://qinscript.lol/333/SpawningItemsList.txt"
local TRANSLATE_URL="http://qinscript.lol/333/ItemNames_CN.lua"

 itemNameMapping={}

local function loadTranslations()
local success,content=pcall(game.HttpGet,game,TRANSLATE_URL)
if not success or not content then
return false
end
local func,err=loadstring(content)
if not func then
return false
end
local ok,mapping=pcall(func)
if not ok or type(mapping)~="table"then
return false
end
itemNameMapping=mapping
return true
end

local function getDisplayName(enName)
local cnName=itemNameMapping[enName]
if cnName then
return enName.." ("..cnName..")"
else
return enName
end
end

local function loadSpawnItemList()
local success,content=pcall(game.HttpGet,game,ITEM_LIST_URL)
if not success or not content then
notify("雪糕","无法从网络加载物品列表，请检查网络",3)
return false
end

local items={}
for line in content:gmatch("[^\r\n]+")do
for word in line:gmatch("%S+")do
if word~=""then
table.insert(items,word)
end
end
end

if#items==0 then
notify("雪糕","物品列表为空",3)
return false
end

spawnItemList=items
return true
end

local function spawnAdminItem(itemName)
if not itemName or itemName==""then return end
local success,err=pcall(function()
game:GetService("ReplicatedStorage"):WaitForChild("Interaction"):WaitForChild("SpawnItemPass"):FireServer(itemName)
end)
if not success then
notify("雪糕","生成失败: "..itemName,2)
end
end

local function startContinuousSpawn()
if spawnLoopRunning then return end
if selectedSpawnItem==""then
notify("雪糕","请先在下拉框中选择一个物品",3)
return
end
spawnLoopRunning=true
local displayName=getDisplayName(selectedSpawnItem)
notify("雪糕",string.format("开始连续生成 [%s] ，关闭开关即可停止",displayName),4)
spawnLoopTask=task.spawn(function()
while spawnLoopRunning do
spawnAdminItem(selectedSpawnItem)
task.wait(0.5)
end
end)
end

local function stopContinuousSpawn()
if not spawnLoopRunning then return end
spawnLoopRunning=false
if spawnLoopTask then
task.cancel(spawnLoopTask)
spawnLoopTask=nil
end
notify("雪糕","已停止连续生成",3)
end

loadTranslations()
loadSpawnItemList()

local function createSpawnUI()
if#spawnItemList==0 then
Sectionqita:Label("物品列表加载失败，请检查网络或重试")
return
end

local displayOptions={}
local valueMap={}
for _,enName in ipairs(spawnItemList)do
local display=getDisplayName(enName)

if valueMap[display]then
display=display.." ["..enName.."]"
end
displayOptions[#displayOptions+1]=display
valueMap[display]=enName
end

local currentDisplay=displayOptions[1]
selectedSpawnItem=valueMap[currentDisplay]

Sectionqita:Dropdown("选择要生成的物品","Dropdown_SpawnItem",displayOptions,function(selectedDisplay)
currentDisplay=selectedDisplay
selectedSpawnItem=valueMap[selectedDisplay]
if spawnLoopRunning then
notify("雪糕","物品已切换为: "..selectedSpawnItem,3)
end
end)

Sectionqita:Toggle("连续生成（间隔0.5秒）","Toggle_ContinuousSpawn",false,function(state)
if state then
startContinuousSpawn()
else
stopContinuousSpawn()
end
end)

Sectionqita:Button("重新加载物品列表和翻译",function()
if spawnLoopRunning then
notify("雪糕","请先关闭连续生成，再重新加载",3)
return
end
loadTranslations()
loadSpawnItemList()
notify("雪糕","列表和翻译已重新加载，请重启脚本以刷新下拉菜单",3)
end)

Sectionqita:Label("提示：开启开关后，每隔0.5秒生成一次当前选中的物品")
end

createSpawnUI()

 combinedRemoteConn=nil
 openSimilarEnabled=false

local function isOwnedByPlayer(model)
local owner=model:FindFirstChild("Owner")
return owner and owner.Value==lp
end

local function hasBlueprintWoodClass(model)
return model:FindFirstChild("BlueprintWoodClass")~=nil
end

local function getItemKey(model)
if not model then return nil end
if model:FindFirstChild("PurchasedBoxItemName")then
return"PurchasedBox:"..model.PurchasedBoxItemName.Value
elseif model:FindFirstChild("ItemName")then
return"Item:"..model.ItemName.Value
elseif model:FindFirstChild("DraggableItem")then
return"Drag:"..tostring(model.DraggableItem.Parent)
elseif model:FindFirstChild("ButtonRemote_Main")then
return"Button:"..model.Name
end
return model.Name
end

local function openOneItem(model,originalCF)
if not model or not model.Parent then return false end
if not isOwnedByPlayer(model)then return false end
if hasBlueprintWoodClass(model)then return false end

local primaryPart=model.PrimaryPart or model:FindFirstChild("Main")or model:FindFirstChildWhichIsA("BasePart")
if not primaryPart then return false end

local hrp=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
if not hrp then return false end

local targetCF=primaryPart.CFrame+Vector3.new(0,2,0)
pcall(function()hrp.CFrame=uprightCFrame(hrp,targetCF)end)
task.wait(0.1)

local success=false

local remoteButton=model:FindFirstChild("ButtonRemote_Main")
if remoteButton then
local ok,err=pcall(function()
game:GetService("ReplicatedStorage").Interaction.RemoteProxy:FireServer(remoteButton)
end)
if ok then
notify("雪糕","已发送按钮打开请求",2)
success=true
else
notify("雪糕","按钮打开失败: "..tostring(err),2)
end

elseif model:FindFirstChild("BoxItemName")or model:FindFirstChild("PurchasedBoxItemName")then
local ok,err=pcall(function()
rep.Interaction.ClientInteracted:FireServer(model,'Open box')
end)
if ok then
notify("雪糕","已发送打开盒子请求",2)
success=true
else
notify("雪糕","打开盒子失败: "..tostring(err),2)
end
else
notify("雪糕","该物品无法通过已知方式打开",2)
end

task.wait(0.2)
for _=1,10 do
if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")then
pcall(function()lp.Character.HumanoidRootPart.CFrame=originalCF end)
break
end
task.wait(0.1)
end
return success
end

local function onMouseClick()
if not combinedRemoteConn then return end
local target=mouse.Target
if not target then return end
local model=target:FindFirstAncestorWhichIsA("Model")
if not model then return end

if not isOwnedByPlayer(model)then return end

if hasBlueprintWoodClass(model)then return end

local hrp=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
if not hrp then return end
local originalCF=hrp.CFrame

if openSimilarEnabled then
local currentKey=getItemKey(model)
local sameItems={}
for _,obj in ipairs(workspace:GetDescendants())do
if obj:IsA("Model")and obj~=model and isOwnedByPlayer(obj)and not hasBlueprintWoodClass(obj)then
local objKey=getItemKey(obj)
if objKey and objKey==currentKey then
table.insert(sameItems,obj)
end
end
end

local success=openOneItem(model,originalCF)
if not success then return end
task.wait(0.3)

for _,other in ipairs(sameItems)do
if other and other.Parent then
local currentOriginal=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
if currentOriginal then
local ok=openOneItem(other,currentOriginal.CFrame)
if not ok then break end
task.wait(0.3)
end
end
end
notify("雪糕","同类物品批量打开完成",3)
else
openOneItem(model,originalCF)
end
end

do
local lp=game:GetService("Players").LocalPlayer
local gamepasses=lp:FindFirstChild("Gamepasses")

if not _G.GamepassesOriginalValues then
_G.GamepassesOriginalValues={}
end

function SaveGamepassesOriginal()
if not gamepasses then return false end
_G.GamepassesOriginalValues={}
for _,v in ipairs(gamepasses:GetDescendants())do
if v:IsA("BoolValue")or v:IsA("IntValue")or v:IsA("NumberValue")then
_G.GamepassesOriginalValues[v]=v.Value
end
end
return true
end

function UnlockAllGamepasses()
if not gamepasses then return false end
local count=0
for _,v in ipairs(gamepasses:GetDescendants())do
if v:IsA("BoolValue")then
v.Value=true
count=count+1
elseif v:IsA("IntValue")or v:IsA("NumberValue")then
v.Value=1
count=count+1
end
end
return count
end

function RestoreGamepassesOriginal()
if not gamepasses then return false end
local count=0
for obj,val in pairs(_G.GamepassesOriginalValues)do
if obj and obj.Parent then
obj.Value=val
count=count+1
end
end
return count
end

SaveGamepassesOriginal()
end

if game:GetService("Players").LocalPlayer:FindFirstChild("Gamepasses")then
Sectionqita:Button("解锁所有通行证",function()
local count=UnlockAllGamepasses()
notify("雪糕","已解锁 "..count.." 个通行证",2)
end)

Sectionqita:Button("恢复通行证原值",function()
local count=RestoreGamepassesOriginal()
notify("雪糕","已恢复 "..count.." 个通行证的原始值",2)
end)

Sectionqita:Button("重新保存当前值为原始值",function()
SaveGamepassesOriginal()
notify("雪糕","已将当前通行证值保存为新的原始值",2)
end)
else
Sectionqita:Label("未找到 Gamepasses 文件夹")
end

 combinedRemoteEnabled=false
Sectionqita:Toggle("远程打开物品（只开盒子，过滤建筑）","Toggle_CombinedRemote",false,function(state)
combinedRemoteEnabled=state
if combinedRemoteEnabled then
if combinedRemoteConn then combinedRemoteConn:Disconnect()end
combinedRemoteConn=mouse.Button1Down:Connect(onMouseClick)
notify("雪糕","远程打开已开启（只识别盒子，自动忽略建筑）",3)
else
if combinedRemoteConn then
combinedRemoteConn:Disconnect()
combinedRemoteConn=nil
end
notify("雪糕","远程打开已关闭",3)
end
end)

Sectionqita:Toggle("打开同类物品（相同 BoxItemName 值）","Toggle_OpenSimilar",false,function(state)
openSimilarEnabled=state
if state then
notify("雪糕","同类模式已启用（基于 BoxItemName 值，且自动过滤建筑）",3)
else
notify("雪糕","同类模式已关闭",3)
end
end)

Sectionqita:Label("提示：点击自己的盒子 → 自动传送打开 → 返回")
Sectionqita:Label("同类模式：按 BoxItemName 值打开所有同类盒子，建筑自动忽略")
Sectionqita:Button("点击传送",function()
local tool=Instance.new("Tool");tool.RequiresHandle=false;tool.Name="点击传送工具"
tool.Activated:connect(function()
local pos=mouse.Hit+Vector3.new(0,2.5,0)
pos=CFrame.new(pos.X,pos.Y,pos.Z)
lp.Character.HumanoidRootPart.CFrame=pos
end)
tool.Parent=lp.Backpack
end)

local duckTypeList={
{name="2018CGift_Duck",display="礼物鸭"},
{name="Duck",display="🦆 普通鸭"},
{name="DuckAngel",display="👼 天堂鸭"},
{name="DuckEvil",display="😈 恶魔鸭"},
{name="LunarDuck",display="🌙 月亮鸭"},
{name="FallenDuck",display="💀 堕落鸭"},
}
local duckDisplayOptions={}
for _,v in ipairs(duckTypeList)do
table.insert(duckDisplayOptions,v.display)
end

 selectedDuckName=duckTypeList[1].name
 batchDuckCount=1
 duckBatchStop=false

local function countDucks(duckName,ownOnly)
local count=0
for _,model in pairs(workspace.PlayerModels:GetChildren())do
if model:IsA("Model")and model.Name==duckName then
local owner=model:FindFirstChild("Owner")
if(ownOnly and owner and owner.Value==lp)or(not ownOnly and(not owner or owner.Value==nil))then
count=count+1
end
end
end
return count
end

local function bringDucksBatch(duckName,ownOnly,count)
if duckBatchStop then duckBatchStop=false end
local startPos=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
if not startPos then
notify("雪糕","无法获取玩家起始位置",3)
return
end
startPos=startPos.CFrame
local successCount=0
local maxLoops=(count==0)and 9999 or count
for i=1,maxLoops do
if duckBatchStop then
notify("雪糕","已停止批量带回",3)
break
end
local remaining=countDucks(duckName,ownOnly)
if remaining==0 then
notify("雪糕","已经没有符合条件的鸭子了",3)
break
end
if count~=0 and successCount>=count then
break
end
bringDuckc(duckName,ownOnly,"cycle")
task.wait(0.01)
successCount=successCount+1

pcall(function()safeTeleport(startPos)end)
if count==0 and countDucks(duckName,ownOnly)==0 then
break
end
end

pcall(function()safeTeleport(startPos)end)
notify("雪糕",string.format("批量带回结束，共带回 %d 只",successCount),3)
duckBatchStop=false
end

SectionDuck:Dropdown("选择鸭子类型","DuckDropdown",duckDisplayOptions,function(display)
for _,v in ipairs(duckTypeList)do
if v.display==display then
selectedDuckName=v.name
break
end
end
end)

SectionDuck:Textbox("带回数量（0=无限循环）","DuckCount","1",function(val)
local num=tonumber(val)
if num and num>=0 then
batchDuckCount=num
else
notify("雪糕","请输入非负整数",2)
end
end)

SectionDuck:Button("带回自己的",function()
duckBatchStop=false
task.spawn(function()
bringDucksBatch(selectedDuckName,true,batchDuckCount)
end)
end)

SectionDuck:Button("带回无归属的",function()
duckBatchStop=false
task.spawn(function()
bringDucksBatch(selectedDuckName,false,batchDuckCount)
end)
end)

SectionDuck:Button("停止当前任务",function()
duckBatchStop=true
notify("雪糕","正在停止...",2)
end)

SectionDuck:Label("提示：数量填 0 表示无限循环带回所有符合条件的鸭子")
SectionDuck:Label("注意：无归属鸭子即 Owner 为空的")

SectionDuck:Button("执行天堂鸭序列并返回",function()
executeSequenceAndReturn()
end)

SectionDuck:Button("一键合成复仇剑（可用）",function()
craftRevengeSword()
end)

SectionDuck:Button("一键合成月亮鸭（合成完毕后需要自行使用带回无归属）",function()
craftLunarDuck()
end)

local function autoGetGiftDuckDirect(targetCount)
targetCount=targetCount or 1
if duckAutoRunning then
notify("雪糕","任务已在运行中",2)
return
end
duckAutoRunning=true
duckStopFlag=false
local successCount=0

local startPos=lp.Character and lp.Character.HumanoidRootPart.CFrame
if not startPos then
notify("雪糕","无法获取玩家起始位置",3)
duckAutoRunning=false
return
end

local function getPlayerPos()
local hrp=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
return hrp and hrp.Position or nil
end

local function getMyDucks()
local ducks={}
for _,m in pairs(workspace.PlayerModels:GetChildren())do
if m:IsA("Model")and m.Name=="2018CGift_Duck"then
local owner=m:FindFirstChild("Owner")
if owner and owner.Value==lp then
table.insert(ducks,m)
end
end
end
return ducks
end

local initialDucks={}
for _,d in ipairs(getMyDucks())do
initialDucks[d]=true
end
local initialCount=#getMyDucks()
notify("雪糕","初始鸭子数: "..initialCount,2)

local function syncDragToPosition(model,targetCF,timeout)
timeout=timeout or 5
local done=false
local success=false
dragToPosition(model,targetCF,function()
done=true
success=true
end)
local startTime=tick()
while not done and tick()-startTime<timeout do
task.wait(0.1)
end
return success
end

local function buyCrate()
local fineFinds=workspace.Stores:FindFirstChild("FineFinds")
if not fineFinds then return nil,"找不到商店"end
local npcChar=fineFinds:FindFirstChild("Manachron")
if not npcChar then return nil,"找不到NPC"end

local npcId=nil
if _G.qSnowNpcMapping and _G.qSnowNpcMapping["FineFinds"]and _G.qSnowNpcMapping["FineFinds"].id then
npcId=_G.qSnowNpcMapping["FineFinds"].id
end
if not npcId and _G.qSnowGetCashierIds then
local ok,ids=pcall(_G.qSnowGetCashierIds)
if ok and type(ids)=="table"then
npcId=ids["Manachron"]or ids["FineFinds"]
if npcId and _G.qSnowNpcMapping and _G.qSnowNpcMapping["FineFinds"]then
_G.qSnowNpcMapping["FineFinds"].id=npcId
end
end
end
if not npcId then return nil,"无法获取NPC ID"end

local counter=fineFinds:FindFirstChild("Counter")
if not counter or not counter:IsA("BasePart")then return nil,"找不到Counter"end

local shopItems=fineFinds:FindFirstChild("ShopItems")
if not shopItems then return nil,"无ShopItems"end
local crateItem=shopItems:FindFirstChild("Crate")
if not crateItem then
for _=1,10 do
crateItem=shopItems:FindFirstChild("Crate")
if crateItem then break end
task.wait(0.15)
end
if not crateItem then return nil,"Crate不在货架"end
end

local primary=crateItem.PrimaryPart or crateItem:FindFirstChild("WoodSection")or crateItem:FindFirstChild("Main")or crateItem:FindFirstChildWhichIsA("BasePart")
if not primary then return nil,"无法定位商品"end
if not crateItem.PrimaryPart then crateItem.PrimaryPart=primary end

-- 锁定人物到商品上方 → 拖到柜台 → 锁定到柜台上方（对齐自动购买模块的购买流程）
lockPlayerAt(primary.CFrame+Vector3.new(0,3,0))
task.wait(0.2)
local counterSurface=counter.CFrame+Vector3.new(0,0.6,0)
dragToPosition(crateItem,counterSurface,nil,true)
lockPlayerAt(counter.CFrame+Vector3.new(0,3,0))
task.wait(0.1)

local NPCDialog=REPLICATED_STORAGE:WaitForChild("NPCDialog")
local purchased={}
local conn=workspace.PlayerModels.ChildAdded:Connect(function(m)
if m:IsA("Model")and m:FindFirstChild("Owner")and m.Owner.Value==lp then
table.insert(purchased,m)
end
end)

local args={{ID=npcId,Character=npcChar,Name="Manachron"},"ConfirmPurchase"}
local ok,err=pcall(function()
NPCDialog.PlayerChatted:InvokeServer(table.unpack(args))
end)

task.wait(0.5)
conn:Disconnect()
unlockPlayer()

if not ok then
return nil,"购买请求失败: "..tostring(err)
end
return purchased[1],"成功"
end

local attempt=0
while duckAutoRunning and not duckStopFlag and successCount<targetCount do
attempt=attempt+1
notify("雪糕",string.format("购买 #%d (已获得 %d/%d)",attempt,successCount,targetCount),2)

local crate,msg=buyCrate()
if not crate then
notify("雪糕","购买失败: "..msg,2)
task.wait(0.15)
if duckStopFlag then break end

local currentDucks=getMyDucks()
if#currentDucks>initialCount then
for _,d in ipairs(currentDucks)do
if not initialDucks[d]and d.Parent then
if not d.PrimaryPart then
local prim=d:FindFirstChild("Main")or d:FindFirstChildWhichIsA("BasePart")
if prim then d.PrimaryPart=prim end
end
if d.PrimaryPart then
safeTeleport(d.PrimaryPart.CFrame+Vector3.new(0,2,0))
task.wait(0.2)
if syncDragToPosition(d,startPos)then
safeTeleport(startPos)
successCount=successCount+1
initialDucks[d]=true
initialCount=initialCount+1
notify("雪糕",string.format("鸭子已带回 (%d/%d)",successCount,targetCount),3)
break
end
end
end
end
end
if duckStopFlag then break end
continue
end

local playerPos=getPlayerPos()
if not playerPos then
notify("雪糕","位置丢失",2)
continue
end
local candidates={}
for _,m in pairs(workspace.PlayerModels:GetChildren())do
if m:IsA("Model")and m:FindFirstChild("Owner")and m.Owner.Value==lp then
local name=m.Name
if name:find("Crate Purchased by")or name:find("crate purchased by")then
local prim=m.PrimaryPart or m:FindFirstChild("Main")or m:FindFirstChildWhichIsA("BasePart")
if prim then
local d=(prim.Position-playerPos).Magnitude
if d<=50 then
table.insert(candidates,{model=m,dist=d})
end
end
end
end
end

if#candidates==0 then
notify("雪糕","未找到板条箱（50米）",2)
continue
end

notify("雪糕",string.format("找到 %d 个板条箱，全部打开",#candidates),2)

table.sort(candidates,function(a,b)return a.dist<b.dist end)

for _,cand in ipairs(candidates)do
local crateBox=cand.model
if duckStopFlag then break end
local opened=false
for retry=1,2 do
if duckStopFlag then break end
local ok=pcall(function()
rep.Interaction.ClientInteracted:FireServer(crateBox,'Open box')
end)
if ok then
opened=true
break
end
task.wait(0.1)
end
if not opened then
notify("雪糕","打开板条箱失败",2)
end
end

task.wait(0.2)
local buttonCrates={}
for _,m in pairs(workspace.PlayerModels:GetChildren())do
if m:IsA("Model")and m.Name=="Crate"then
local owner=m:FindFirstChild("Owner")
if owner and owner.Value==lp then
local prim=m.PrimaryPart or m:FindFirstChild("Main")or m:FindFirstChildWhichIsA("BasePart")
if prim and(prim.Position-playerPos).Magnitude<=50 then
table.insert(buttonCrates,m)
end
end
end
end

if#buttonCrates>0 then
notify("雪糕",string.format("找到 %d 个可点击的 Crate",#buttonCrates),2)
for _,crateModel in ipairs(buttonCrates)do
if duckStopFlag then break end
local btn=crateModel:FindFirstChild("ButtonRemote_Main")
if btn then
pcall(function()
game:GetService("ReplicatedStorage").Interaction.RemoteProxy:FireServer(btn)
end)
end
task.wait(0.04)
end
else
notify("雪糕","未找到可点击的 Crate",2)
end

task.wait(0.5)

local currentDucks=getMyDucks()
if#currentDucks>initialCount then
for _,d in ipairs(currentDucks)do
if not initialDucks[d]and d.Parent then
if not d.PrimaryPart then
local prim=d:FindFirstChild("Main")or d:FindFirstChildWhichIsA("BasePart")
if prim then d.PrimaryPart=prim end
end
if d.PrimaryPart then
safeTeleport(d.PrimaryPart.CFrame+Vector3.new(0,2,0))
task.wait(0.2)
if syncDragToPosition(d,startPos)then
safeTeleport(startPos)
successCount=successCount+1
initialDucks[d]=true
initialCount=initialCount+1
notify("雪糕",string.format("鸭子已带回 (%d/%d)",successCount,targetCount),3)

end
end
end
end
else
notify("雪糕","未出鸭",2)
end

if successCount>=targetCount then
break
end
notify("雪糕","未达标，继续购买",2)
task.wait(0.08)
end

if duckStopFlag then
notify("雪糕","已停止",2)
elseif successCount>=targetCount then
notify("雪糕",string.format("成功获取 %d 只鸭子",successCount),3)
else
notify("雪糕","任务结束，未达到目标",3)
end

safeTeleport(startPos)
duckAutoRunning=false
duckStopFlag=false
end

SectionDuck:Textbox("目标获取数量","TargetDuckCount","1",function(v)
local num=tonumber(v)
if num and num>0 then
targetDuckCount=math.floor(num)
else
targetDuckCount=1
end
end)

SectionDuck:Button("开始获取普通鸭",function()
task.spawn(function()autoGetGiftDuckDirect(targetDuckCount)end)
end)

SectionDuck:Button("停止任务",function()

if duckAutoRunning then
duckStopFlag=true
end

if voidSaplingRunning then
duckStopFlag=true
end
if not duckAutoRunning and not voidSaplingRunning then
notify("雪糕","当前没有运行中的任务",2)
else
notify("雪糕","正在停止任务...",2)
end
end)

SectionEVIL:Button("翻译此恶魔鸭提示（按一次就好了多按会有空气 一大串英文就是力量宝珠（50t）",function()

for _,lbl in ipairs(evilTranslatedLabels)do
pcall(function()lbl:Remove()end)
end
evilTranslatedLabels={}

local results=translateEvilNotes()
for _,text in ipairs(results)do
local newLabel=SectionEVIL:Label(text)
table.insert(evilTranslatedLabels,newLabel)
end
end)

SectionESP:Toggle("礼物鸭透视","Toggle_DuckOutline",false,function(state)
if state then enableDuckOutline()else disableDuckOutline()end
end)

SectionESP:Toggle("虚空树苗箱透视","Toggle_VoidCrateOutline",false,function(state)
if state then enableVoidCrateOutline()else disableVoidCrateOutline()end
end)
SectionESP:Toggle("头像+距离",'Toggleflag',false,function(state)
if state then enableEsp()else disableEsp()end
end)

Sectionhuanjin:Toggle("终日白天",'Toggleflag',false,function(state)
bai.awaysday=state
if state then
while task.wait()do
if bai.awaysday==true then game:GetService('Lighting').TimeOfDay=('14:00:00')end
end
end
end)
Sectionhuanjin:Toggle("终日黑夜",'Toggleflag',false,function(state)
bai.awaysdnight=state
if state then
while task.wait()do
if bai.awaysdnight==true then game:GetService('Lighting').TimeOfDay=('2:00:00')end
end
end
end)
Sectionhuanjin:Toggle("去除雾",'Toggleflag',false,function(state)
bai.nofog=state
if state then
while task.wait()do
if bai.nofog==true then game:GetService('Lighting').FogEnd=1000000 end
end
end
end)
Sectionhuanjin:Toggle("消除阴影",'Toggleflag',false,function(state)
game.Lighting.GlobalShadows=not state
end)
Sectionhuanjin:Toggle("水上行走",'Toggleflag',false,function(state)
for _,v in pairs(workspace.Water:GetChildren())do if v:IsA("BasePart")then v.CanCollide=state end end
for _,v in pairs(workspace.Bridge.VerticalLiftBridge.WaterModel:GetChildren())do if v:IsA("BasePart")then v.CanCollide=state end end
end)
Sectionhuanjin:Toggle("删除水（透明）",'Toggleflag',false,function(state)
for _,v in pairs(workspace.Water:GetChildren())do if v.Name=="Water"then v.Transparency=state and 1 or 0 end end
end)
Sectionhuanjin:Toggle("删除岩浆（透明）",'Toggleflag',false,function(state)
for _,v in pairs(workspace.Region_Volcano:GetDescendants())do
if v.Name=="Lava"then for _,part in pairs(v:GetChildren())do if part:IsA("Part")then part.Transparency=state and 1 or 0 end end end
end
end)
Sectionhuanjin:Button("删除灵视神殿石头及门",function()
pcall(function()workspace.Region_Mountainside.BoulderRegen.Boulder:Destroy()end)
pcall(function()workspace.Region_Mountainside.Door.Door:Destroy()end)
notify("雪糕","已删除石头与门",3)
end)

local dropdown_devil=Sectionmogui:Dropdown("选择玩家名称",'Dropdown',bai.dropdown,function(v)
bai.playernamedied=v
end)
Sectionmogui:Button("刷新列表",function()
shuaxinlb(true);dropdown_devil:SetOptions(bai.dropdown)
end)
Sectionmogui:Button("传送到玩家旁边",function()
local target=game.Players:FindFirstChild(bai.playernamedied)
if target and target.Character then safeTeleport(target.Character.HumanoidRootPart.CFrame+Vector3.new(0,3,0))end
end)
Sectionmogui:Button("传送到玩家基地",function()
for _,v in pairs(workspace.Properties:GetChildren())do
if v.Owner.Value==game.Players[bai.playernamedied]then safeTeleport(v.OriginSquare.CFrame+Vector3.new(0,10,0));break end
end
end)
Sectionmogui:Button("汽车传送到玩家旁边",function()
local target=game.Players:FindFirstChild(bai.playernamedied)
if target and target.Character then carTeleport(target.Character.HumanoidRootPart.CFrame+Vector3.new(0,3,0))end
end)
Sectionmogui:Button("汽车传送到玩家基地",function()
for _,v in pairs(workspace.Properties:GetChildren())do
if v.Owner.Value==game.Players[bai.playernamedied]then carTeleport(v.OriginSquare.CFrame+Vector3.new(0,10,0))end
end
end)
Sectionmogui:Toggle("查看玩家",'Toggleflag',false,function(state)
if state then
local target=game.Players:FindFirstChild(bai.playernamedied)
if target and target.Character then workspace.CurrentCamera.CameraSubject=target.Character.Humanoid end
else
workspace.CurrentCamera.CameraSubject=lp.Character.Humanoid
end
end)
Sectionmogui:Toggle("查看玩家基地",'Toggleflag',false,function(state)
local see=nil
for _,v in pairs(workspace.Properties:GetChildren())do
if v.Owner.Value==game.Players[bai.playernamedied]then see=v.OriginSquare end
end
if state then
if see then workspace.CurrentCamera.CameraSubject=see
else notify("雪糕","没有找到基地",3)end
else
workspace.CurrentCamera.CameraSubject=lp.Character.Humanoid
end
end)
-- 原来这里是一长串 if/elseif 硬编码, 只能选到 66 种树, 而且和带来树那套各写一份。
-- 现在复用 treeMapping/treeNames(运行时从 Planter Spawner.Amounts 读来的完整列表)。
local tptreeNames={}
for _,n in ipairs(treeNames)do table.insert(tptreeNames,n)end
sortTreeNames(tptreeNames)

Section4:Dropdown("传送到树",'Dropdown',tptreeNames,function(b)
bai.tptree=treeMapping[b]or"Generic"
local found=false
for i,v in pairs(game.Workspace:GetChildren())do
if v.Name=="TreeRegion"then
for j,k in ipairs(v:GetChildren())do
if k:FindFirstChild("TreeClass")and k.TreeClass.Value==bai.tptree then
local wsPart=k:FindFirstChild("WoodSection")
if wsPart and lp.Character then lp.Character:MoveTo(wsPart.Position)end
found=true
break
end
end
end
end
if not found then notify("雪糕","没找到该种类的树",3)end
end)

 paintToolInstance=nil

function createPaintTool()

if paintToolInstance and paintToolInstance.Parent then
paintToolInstance:Destroy()
paintToolInstance=nil
end

local tool=Instance.new("Tool")
tool.RequiresHandle=false
tool.Name="涂装工具"

tool.Activated:Connect(function()
local target=mouse.Target
if not target then
notify("雪糕","未点击任何物体",2)
return
end

local model=target:FindFirstAncestorOfClass("Model")
if not model then
notify("雪糕","请点击一个模型",2)
return
end

if not selectedPaintMaterial or selectedPaintMaterial==""then
notify("雪糕","请先选择材质",2)
return
end

local placeStructure=game:GetService("ReplicatedStorage"):FindFirstChild("PlaceStructure")
if not placeStructure then
notify("雪糕","PlaceStructure 不存在",3)
return
end

local paintToolRemote=placeStructure:FindFirstChild("PaintTool")
if not paintToolRemote then
notify("雪糕","PaintTool 远程事件不存在",3)
return
end

pcall(function()
paintToolRemote:FireServer(model,selectedPaintMaterial)
end)

notify("雪糕","已发送涂装请求: "..selectedPaintMaterial,2)
end)

tool.Parent=lp.Backpack
paintToolInstance=tool
notify("雪糕","涂已添加到背包，点击任意模型即可填充",3)
end

Sectionqita:Dropdown("选择材质","PaintMaterialDropdown",{
"RainbowFlame","BlueFlame","Flame","Ash","Aspen","Birch","Blah","Brick","BrickAlternative","BrickDark","Bush",
"Candy","CandyAlternative","CandyNeon","CandycaneGreen","CandycaneRed",
"Cartoony","CartoonyRainbow","CaveCrawler","Cavern","CavernCrawler","Celestial",
"Cherry","CobbleStone","Cookie","Copper","Diamond","Dog","Dry","DryNeon",
"Electric","Ember","Fir","Frost","Generic","GenericDead","GenericFall",
"GenericGold","GenericPrime","GenericSpecial","Glass","GlowShroom","Gold",
"GoldSwampy","Grass1","GreatOak","GreenSwampy","GrottoCrawler","Hell","Ice",
"Koa","LoneCave","Magma","Maple","Marble","MuckySewer","NeonRainbow","Oak",
"Palm","Pine","PotBush","Potato","REEE","Radioactive","Rainbow","Random",
"Ruby","Sand","Scale","SewageTree","Shine","Sign","Silver","Skittles","Sky",
"Snow","SnowGlow","Spirit","Spooky","SpookyGhoul","SpookyNeon","Star","Stone",
"Taco","Thread","TunnelCrawler","Virtual","Void","Volcano","Waffer","Walnut"
},function(v)
selectedPaintMaterial=v
end)

Sectionqita:Button("获取填充工具（需要通行证）",function()
createPaintTool()
end)
_G.qsMain=_G.qsMain or {}
for k,v in pairs({selectionCountLabel=selectionCountLabel,treeNamesWithPlaceholder=treeNamesWithPlaceholder,ITEM_LIST_URL=ITEM_LIST_URL,TRANSLATE_URL=TRANSLATE_URL,loadTranslations=loadTranslations,getDisplayName=getDisplayName,loadSpawnItemList=loadSpawnItemList,spawnAdminItem=spawnAdminItem,startContinuousSpawn=startContinuousSpawn,stopContinuousSpawn=stopContinuousSpawn,createSpawnUI=createSpawnUI,isOwnedByPlayer=isOwnedByPlayer,hasBlueprintWoodClass=hasBlueprintWoodClass,getItemKey=getItemKey,openOneItem=openOneItem,onMouseClick=onMouseClick,duckTypeList=duckTypeList,duckDisplayOptions=duckDisplayOptions,countDucks=countDucks,bringDucksBatch=bringDucksBatch,autoGetGiftDuckDirect=autoGetGiftDuckDirect,dropdown_devil=dropdown_devil,createPaintTool=createPaintTool})do _G.qsMain[k]=v end

]====]
local SRC_BP   = [====[
local function uprightCFrame(hrp,cf)
local pos=cf.Position
local yRot=hrp and hrp.Orientation.Y or 0
return CFrame.new(pos)*CFrame.Angles(0,math.rad(yRot),0)
end

local win=_G.qSnowMainWin
if not win then
local bailib=loadstring(game:HttpGet("http://qinscript.lol/333/透明UI.lua"))()
win=bailib:new("蓝图工具","")
end

local lp=game.Players.LocalPlayer
local mouse=lp:GetMouse()
local rs=game:GetService("ReplicatedStorage")
local StarterGui=game:GetService("StarterGui")

local function notify(title,desc,duration)
pcall(function()
StarterGui:SetCore("SendNotification",{
Title=tostring(title or"通知"),
Text=tostring(desc or""),
Duration=duration or 3,
})
end)
end

local function showConfirmDialog(title,desc)
local result=nil
local done=false

local gui=Instance.new("ScreenGui")
gui.Name="ConfirmDialog_Xuegao"
gui.ResetOnSpawn=false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
pcall(function()gui.Parent=game:GetService("CoreGui")end)
if not gui.Parent then gui.Parent=lp:WaitForChild("PlayerGui")end

local bg=Instance.new("Frame")
bg.Size=UDim2.new(1,0,1,0)
bg.BackgroundColor3=Color3.fromRGB(0,0,0)
bg.BackgroundTransparency=0.5
bg.BorderSizePixel=0
bg.ZIndex=1
bg.Parent=gui

local frame=Instance.new("Frame")
frame.Size=UDim2.new(0,360,0,180)
frame.Position=UDim2.new(0.5,0,0.5,0)
frame.AnchorPoint=Vector2.new(0.5,0.5)
frame.BackgroundColor3=Color3.fromRGB(22,22,30)
frame.BorderSizePixel=0
frame.ZIndex=2
frame.Parent=bg
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,14)

local titleLabel=Instance.new("TextLabel")
titleLabel.Size=UDim2.new(1,-30,0,32)
titleLabel.Position=UDim2.new(0,15,0,15)
titleLabel.BackgroundTransparency=1
titleLabel.Text=title
titleLabel.TextColor3=Color3.fromRGB(240,240,245)
titleLabel.TextSize=18
titleLabel.Font=Enum.Font.GothamBold
titleLabel.TextXAlignment=Enum.TextXAlignment.Left
titleLabel.ZIndex=3
titleLabel.Parent=frame

local descLabel=Instance.new("TextLabel")
descLabel.Size=UDim2.new(1,-30,0,70)
descLabel.Position=UDim2.new(0,15,0,55)
descLabel.BackgroundTransparency=1
descLabel.Text=desc
descLabel.TextColor3=Color3.fromRGB(200,200,210)
descLabel.TextSize=14
descLabel.Font=Enum.Font.Gotham
descLabel.TextXAlignment=Enum.TextXAlignment.Left
descLabel.TextYAlignment=Enum.TextYAlignment.Top
descLabel.TextWrapped=true
descLabel.ZIndex=3
descLabel.Parent=frame

local yesBtn=Instance.new("TextButton")
yesBtn.Size=UDim2.new(0,150,0,38)
yesBtn.Position=UDim2.new(0,15,1,-55)
yesBtn.BackgroundColor3=Color3.fromRGB(50,130,240)
yesBtn.BorderSizePixel=0
yesBtn.Text="用无颜色填充"
yesBtn.TextColor3=Color3.fromRGB(255,255,255)
yesBtn.TextSize=14
yesBtn.Font=Enum.Font.GothamBold
yesBtn.ZIndex=3
yesBtn.Parent=frame
Instance.new("UICorner",yesBtn).CornerRadius=UDim.new(0,8)

local noBtn=Instance.new("TextButton")
noBtn.Size=UDim2.new(0,150,0,38)
noBtn.Position=UDim2.new(1,-165,1,-55)
noBtn.BackgroundColor3=Color3.fromRGB(60,60,75)
noBtn.BorderSizePixel=0
noBtn.Text="取消"
noBtn.TextColor3=Color3.fromRGB(240,240,245)
noBtn.TextSize=14
noBtn.Font=Enum.Font.GothamBold
noBtn.ZIndex=3
noBtn.Parent=frame
Instance.new("UICorner",noBtn).CornerRadius=UDim.new(0,8)

yesBtn.MouseButton1Click:Connect(function()
result=true
done=true
gui:Destroy()
end)
noBtn.MouseButton1Click:Connect(function()
result=false
done=true
gui:Destroy()
end)

while not done do task.wait(0.05)end
return result
end

local BLUEPRINT_FOLDER="Blueprint"

local function ensureFolder()
if not isfolder or not makefolder then return end
pcall(function()
if not isfolder(BLUEPRINT_FOLDER)then makefolder(BLUEPRINT_FOLDER)end
end)
end

local XOR_TAG="QSNOW1::"
local XOR_KEY="qinscript.lol-blueprint-2024"

local function _xorByte(a,b)
local r,p=0,1
while a>0 or b>0 do
if(a%2)~=(b%2)then r=r+p end
a=math.floor(a/2)
b=math.floor(b/2)
p=p*2
end
return r
end

local function xorData(data)
local kl=#XOR_KEY
if kl==0 then return data end
local out={}
for i=1,#data do
local b=string.byte(data,i)
local k=string.byte(XOR_KEY,((i-1)%kl)+1)
out[#out+1]=string.char(_xorByte(b,k))
end
return table.concat(out)
end

local function decryptContent(content)
if type(content)=="string"and content:sub(1,#XOR_TAG)==XOR_TAG then
return xorData(content:sub(#XOR_TAG+1))
end
return content
end

local function encryptContent(content)
return XOR_TAG..xorData(content)
end

local function writeBlueprint(fileName,content,encrypt)
ensureFolder()
local finalContent=content
if encrypt then finalContent=encryptContent(content)end
local candidates={
BLUEPRINT_FOLDER.."/"..fileName,
"/"..BLUEPRINT_FOLDER.."/"..fileName,
}
for _,path in ipairs(candidates)do
if pcall(function()writefile(path,finalContent)end)then return path end
end
if pcall(function()writefile(fileName,finalContent)end)then return fileName end
return nil
end

local function readBlueprint(filePath)
if readfile then
local ok,content=pcall(readfile,filePath)
if ok and content then return decryptContent(content)end
ok,content=pcall(readfile,BLUEPRINT_FOLDER.."/"..filePath)
if ok and content then return decryptContent(content)end
end
return nil
end

local function safeFileName(s)
return(s:gsub("[\\/:*?\"<>|]","_"))
end

local function playerLabel(p)
local displayName=p.DisplayName or p.Name
local userName=p.Name
return"名字："..displayName.." 用户名："..userName
end

local function getBasePosition(player)
local props=workspace:FindFirstChild("Properties")
if not props then return nil end
for _,v in pairs(props:GetChildren())do
local owner=v:FindFirstChild("Owner")
if owner and owner.Value==player then
local sq=v:FindFirstChild("OriginSquare")
if sq then return sq.Position end
end
end
return nil
end

local function getMyBase()
local props=workspace:FindFirstChild("Properties")
if not props then return nil,nil end
for _,v in pairs(props:GetChildren())do
local owner=v:FindFirstChild("Owner")
if owner and owner.Value==lp then
local sq=v:FindFirstChild("OriginSquare")
if sq then return v,sq end
end
end
return nil,nil
end

local cfgMidWait=8
local cfgPlaceDelay=0
local cfgFillDelay=0
local doPlace=true
local doFill=true

local TabBlueprint=win:Tab("蓝图","2700297399")
local SectionSave=TabBlueprint:section("保存蓝图到文件",true)
local SectionPlace=TabBlueprint:section("放置 / 填充",true)
local SectionBase=TabBlueprint:section("基地",true)

SectionPlace:Toggle("执行放置","ToggleDoPlace",true,function(state)doPlace=state end)
SectionPlace:Toggle("执行填充","ToggleDoFill",true,function(state)doFill=state end)

SectionPlace:Textbox("放置后等待（秒）","CfgMidWait",tostring(cfgMidWait),function(v)
local n=tonumber(v);if n and n>=0 then cfgMidWait=n end
end)
SectionPlace:Textbox("放置间隔（秒）","CfgPlaceDelay",tostring(cfgPlaceDelay),function(v)
local n=tonumber(v);if n and n>=0 then cfgPlaceDelay=n end
end)
SectionPlace:Textbox("填充间隔（秒）","CfgFillDelay",tostring(cfgFillDelay),function(v)
local n=tonumber(v);if n and n>=0 then cfgFillDelay=n end
end)

local function loadDataFromFile(filePath)
local content=readBlueprint(filePath)
if not content then return nil end
local fn=loadstring(content)
if fn then
local ok,data=pcall(fn)
if ok and type(data)=="table"then return data end
end
if loadfile then
local fn2=loadfile(filePath)
if fn2 then
local ok,data=pcall(fn2)
if ok and type(data)=="table"then return data end
end
end
return nil
end

local bpFileDropdown=nil
local bpFileList={}
local bpFileLookup={}
local bpSelectedFile=nil
local refreshBpFiles

local function saveOnePlayer(targetPlayer,encrypt)
if not targetPlayer then return 0,"找不到玩家"end

local container=workspace:FindFirstChild("PlayerModels")
if not container then return 0,"PlayerModels 不存在"end

local list={}
local noMaterialCount=0
local seen={}
for _,obj in pairs(container:GetDescendants())do
pcall(function()
if not(obj:IsA("Model")or obj:IsA("BasePart"))then return end
local owner=obj:FindFirstChild("Owner")
local itemName=obj:FindFirstChild("ItemName")
if not(owner and itemName)then return end
if owner.Value~=targetPlayer then return end
if not obj:FindFirstChild("BuildDependentWood")then return end

local unit=obj
if obj:IsA("BasePart")then
local pm=obj:FindFirstAncestorOfClass("Model")
if pm and pm~=container then unit=pm end
end
local typeVal=unit:FindFirstChild("Type")or obj:FindFirstChild("Type")
if not(typeVal and typeVal.Value=="Structure")then return end
if seen[unit]then return end
seen[unit]=true

local woodClass=unit:FindFirstChild("BlueprintWoodClass")or obj:FindFirstChild("BlueprintWoodClass")

local pivot
if unit:IsA("Model")then
local s1,r1=pcall(function()return unit:GetPivot()end)
if s1 and r1 then pivot=r1 end
if not pivot then
local s2,r2=pcall(function()return unit:GetBoundingBox()end)
if s2 and r2 then pivot=r2 end
end
else
pivot=unit.CFrame
end
if not pivot then return end

local cfStr=string.format(
"CFrame.new(%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f)",
pivot:GetComponents()
)

local wsValue=""
if woodClass and woodClass.Value~=nil then
wsValue=tostring(woodClass.Value)
end
if wsValue==""then noMaterialCount=noMaterialCount+1 end

list[#list+1]={
WS=wsValue,
N=tostring(itemName.Value),
CFrame=cfStr
}
end)
end

if#list==0 then return 0,"无数据"end

local fileName=safeFileName(playerLabel(targetPlayer))..string.format("（%d个蓝图）",#list)

local nameCount={}
local wsCount={}
for _,item in ipairs(list)do
nameCount[item.N]=(nameCount[item.N]or 0)+1
if item.WS~=""then
wsCount[item.WS]=(wsCount[item.WS]or 0)+1
end
end

local function sortedPairs(t)
local arr={}
for k,v in pairs(t)do table.insert(arr,{k=k,v=v})end
table.sort(arr,function(a,b)return a.v>b.v end)
return arr
end

local headerLines={}
headerLines[#headerLines+1]="-- ================================"
headerLines[#headerLines+1]="-- 蓝图概览"
headerLines[#headerLines+1]="-- ================================"
headerLines[#headerLines+1]=string.format("-- 玩家: %s (%s)",
targetPlayer.DisplayName or targetPlayer.Name,targetPlayer.Name)
headerLines[#headerLines+1]=string.format("-- 总数: %d 个蓝图",#list)
headerLines[#headerLines+1]=string.format("-- 无材质: %d 个",noMaterialCount)

local basePos=getBasePosition(targetPlayer)
if basePos then
headerLines[#headerLines+1]=string.format("-- Base: %.4f, %.4f, %.4f",
basePos.X,basePos.Y,basePos.Z)
end

headerLines[#headerLines+1]="--"
headerLines[#headerLines+1]="-- 【需要的蓝图种类】"
for _,entry in ipairs(sortedPairs(nameCount))do
headerLines[#headerLines+1]=string.format("--   %-30s x%d",entry.k,entry.v)
end

headerLines[#headerLines+1]="--"
headerLines[#headerLines+1]="-- 【使用的材质】"
local wsArr=sortedPairs(wsCount)
if#wsArr==0 then
headerLines[#headerLines+1]="--   (无)"
else
for _,entry in ipairs(wsArr)do
headerLines[#headerLines+1]=string.format("--   %-30s x%d",entry.k,entry.v)
end
end
headerLines[#headerLines+1]="-- ================================"
headerLines[#headerLines+1]=""

local lines={table.concat(headerLines,"\n").."return {"}
for _,item in ipairs(list)do
lines[#lines+1]=string.format(
'    {WS="%s",N="%s",CFrame=%s},',
item.WS,item.N,item.CFrame
)
end
lines[#lines+1]="}"

local path=writeBlueprint(fileName,table.concat(lines,"\n"),encrypt)
if path then return#list,nil,path,noMaterialCount end
return 0,"写入失败",nil,0
end

local savePlayerDropdown=nil
local savePlayerLookup={}
local savePlayerName=lp.Name

local function refreshSavePlayerList()
savePlayerLookup={}
local displayList={}
for _,p in pairs(game.Players:GetPlayers())do
local label=playerLabel(p)
table.insert(displayList,label)
savePlayerLookup[label]=p
end
if savePlayerDropdown then
savePlayerDropdown:SetOptions(displayList)
for label,p in pairs(savePlayerLookup)do
if p.Name==savePlayerName then
savePlayerDropdown:SetValue(label)
break
end
end
end
end

local initList={}
for _,p in pairs(game.Players:GetPlayers())do
local label=playerLabel(p)
initList[#initList+1]=label
savePlayerLookup[label]=p
end

savePlayerDropdown=SectionSave:Dropdown("选择玩家","SavePlayerDropdown",initList,function(label)
local p=savePlayerLookup[label]
if p then savePlayerName=p.Name end
end)

SectionSave:Button("刷新玩家列表",refreshSavePlayerList)

SectionSave:Button("保存选中玩家（加密）",function()
local targetPlayer=game.Players:FindFirstChild(savePlayerName)
local count,err,path,noMat=saveOnePlayer(targetPlayer,true)
if count>0 then
notify("雪糕",string.format("已加密保存 %d 条到 %s（无材质 %d 条）",count,path or"?",noMat or 0),4)
if refreshBpFiles then refreshBpFiles()end
else
notify("雪糕","保存失败："..tostring(err or"无数据"),4)
end
end)

SectionSave:Button("保存选中玩家（不加密）",function()
local targetPlayer=game.Players:FindFirstChild(savePlayerName)
local count,err,path,noMat=saveOnePlayer(targetPlayer,false)
if count>0 then
notify("雪糕",string.format("已保存 %d 条到 %s（无材质 %d 条）",count,path or"?",noMat or 0),4)
if refreshBpFiles then refreshBpFiles()end
else
notify("雪糕","保存失败："..tostring(err or"无数据"),4)
end
end)

SectionSave:Button("一键保存服务器所有人（加密）",function()
task.spawn(function()
local players=game.Players:GetPlayers()
local savedPlayers={}
local totalSaved=0
local failedPlayers={}

for _,p in ipairs(players)do
local count,err=saveOnePlayer(p,true)
if count>0 then
table.insert(savedPlayers,p.Name)
totalSaved=totalSaved+count
elseif err~="无数据"then
table.insert(failedPlayers,p.Name)
end
task.wait(0.05)
end

notify("雪糕",string.format("加密保存完成：%d 名玩家，共 %d 条",#savedPlayers,totalSaved),6)

if refreshBpFiles then refreshBpFiles()end
end)
end)

SectionSave:Button("一键保存服务器所有人（不加密）",function()
task.spawn(function()
local players=game.Players:GetPlayers()
local savedPlayers={}
local totalSaved=0
local failedPlayers={}

for _,p in ipairs(players)do
local count,err=saveOnePlayer(p,false)
if count>0 then
table.insert(savedPlayers,p.Name)
totalSaved=totalSaved+count
elseif err~="无数据"then
table.insert(failedPlayers,p.Name)
end
task.wait(0.05)
end

notify("雪糕",string.format("保存完成：%d 名玩家，共 %d 条",#savedPlayers,totalSaved),6)

if refreshBpFiles then refreshBpFiles()end
end)
end)

SectionBase:Button("点击获取土地",function()
notify("雪糕","请点击一块空地",4)
local conn
conn=mouse.Button1Up:Connect(function()
local target=mouse.Target
if not target then return end
local prop=target:FindFirstAncestorOfClass("Model")
if not prop or prop.Name~="Property"then
notify("雪糕","请点击土地模型",3)
return
end
local owner=prop:FindFirstChild("Owner")
local square=prop:FindFirstChild("OriginSquare")
if not owner or not square then return end
if owner.Value==nil then
pcall(function()
rs.PropertyPurchasing.ClientPurchasedProperty:FireServer(
prop,square.Position+Vector3.new(0,3,0))
end)
conn:Disconnect()
notify("雪糕","已购买土地",3)
task.wait(0.3)
local hrp=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
if hrp then hrp.CFrame=uprightCFrame(hrp,square.CFrame+Vector3.new(0,10,0))end
else
notify("雪糕","这块地已经有主人",3)
end
end)
end)

local function expandMyBase()
local base,square=getMyBase()
if not base then return false end

local spos=square.Position
local function expand(offset)
local pos=CFrame.new(spos.X+offset[1],spos.Y+offset[2],spos.Z+offset[3])
pcall(function()
rs.PropertyPurchasing.ClientExpandedProperty:FireServer(base,pos)
end)
end

local d,d2=40,80
local offsets={
{d,0,0},{-d,0,0},{0,0,d},{0,0,-d},
{d,0,d},{d,0,-d},{-d,0,d},{-d,0,-d},
{d2,0,0},{-d2,0,0},{0,0,d2},{0,0,-d2},
{d2,0,d2},{d2,0,-d2},{-d2,0,d2},{-d2,0,-d2},
{d,0,d2},{-d,0,d2},{d2,0,d},{d2,0,-d},
{-d2,0,d},{-d2,0,-d},{d,0,-d2},{-d,0,-d2},
}
for _,o in ipairs(offsets)do expand(o)end
return true
end

SectionBase:Button("最大土地",function()
if expandMyBase()then
notify("雪糕","已扩展土地",3)
else
notify("雪糕","你没有土地",3)
end
end)

SectionBase:Button("最大土地 x3（无间隔）",function()
task.spawn(function()
for _=1,3 do
if not expandMyBase()then
notify("雪糕","你没有土地",3)
return
end
end
notify("雪糕","已执行三次最大土地",3)
end)
end)

local function findMajorityMaterial(buildingData)
local count={}
for _,entry in ipairs(buildingData)do
local ws=entry.WS
if ws and ws~=""then
count[ws]=(count[ws]or 0)+1
end
end
local bestWS,bestCount=nil,0
for ws,c in pairs(count)do
if c>bestCount then bestWS,bestCount=ws,c end
end
return bestWS,bestCount
end

local function fillMissingBlueprints(missingNames)
local buyFn=_G.qSnowBuyBlueprintBox
if not buyFn then
return 0,#missingNames,missingNames,"自动购买模块未加载"
end
_G.qSnowPlaceStopFlag=false
local blueprintFolder=lp:FindFirstChild("PlayerBlueprints")
and lp.PlayerBlueprints:FindFirstChild("Blueprints")

local startHRP=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
local startCF=startHRP and startHRP.CFrame

local function gotoCF(cf)
if not cf then return end
local hrp=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
if hrp then
pcall(function()hrp.CFrame=uprightCFrame(hrp,cf)end)
end
end

local function openBox(box)
if not box or not box.Parent then return false end
local primaryPart=box.PrimaryPart or box:FindFirstChild("Main")or box:FindFirstChildWhichIsA("BasePart")
if not primaryPart then return false end

gotoCF(primaryPart.CFrame+Vector3.new(0,2,0))
task.wait(0.15)

local ready=0
while ready<3 do
if box:FindFirstChild("ButtonRemote_Main")
or box:FindFirstChild("BoxItemName")
or box:FindFirstChild("PurchasedBoxItemName")then
break
end
task.wait(0.2)
ready=ready+0.2
end

local ok=false
local remoteButton=box:FindFirstChild("ButtonRemote_Main")
if remoteButton then
ok=pcall(function()
rs.Interaction.RemoteProxy:FireServer(remoteButton)
end)
elseif box:FindFirstChild("BoxItemName")or box:FindFirstChild("PurchasedBoxItemName")then
ok=pcall(function()
rs.Interaction.ClientInteracted:FireServer(box,'Open box')
end)
else

ok=pcall(function()
rs.Interaction.ClientInteracted:FireServer(box,'Open box')
end)
end
if not ok then
notify("雪糕","打开盒子请求发送失败",2)
end
return ok
end

local got,stillMissing=0,{}
for idx,name in ipairs(missingNames)do
if _G.qSnowPlaceStopFlag then
for j=idx,#missingNames do
table.insert(stillMissing,missingNames[j])
end
break
end
if blueprintFolder and blueprintFolder:FindFirstChild(name)then
got=got+1
else
local box,err=buyFn(name)
if not box then
table.insert(stillMissing,name)
notify("雪糕","买不到蓝图 "..name.."："..tostring(err),3)
else
openBox(box)

local waited=0
while waited<5 do
task.wait(0.3)
waited=waited+0.3
if blueprintFolder and blueprintFolder:FindFirstChild(name)then break end
end
if blueprintFolder and blueprintFolder:FindFirstChild(name)then
got=got+1
notify("雪糕","已得到蓝图: "..name,2)
else
table.insert(stillMissing,name)
end
end
task.wait(0.2)
end
end

gotoCF(startCF)
return got,#stillMissing,stillMissing,nil
end

local function placeAndFill(buildingData,label)
if type(buildingData)~="table"or#buildingData==0 then return end
_G.qSnowPlaceStopFlag=false

local placeRemote=rs.PlaceStructure.ClientPlacedBlueprint
local paintTool=rs.PlaceStructure.PaintTool

local container=workspace:FindFirstChild("PlayerModels")
if not container then
notify("雪糕","PlayerModels 不存在",3)
return
end

local majorityWS,majorityCount=findMajorityMaterial(buildingData)
if not majorityWS then
majorityWS="Generic"
majorityCount=0
end

local CELL=4
local grid={}

local function cellKey(p)
return("%d_%d_%d"):format(
math.floor(p.X/CELL),math.floor(p.Y/CELL),math.floor(p.Z/CELL))
end

local function getPos(m)
if typeof(m)=="table"then return m.Position end
if m:IsA("Model")then
if m.PrimaryPart then return m.PrimaryPart.Position end
local ok,cf=pcall(function()return m:GetBoundingBox()end)
if ok and cf then return cf.Position end
elseif m:IsA("BasePart")then
return m.Position
end
return nil
end

local function buildIndex()
grid={}
for _,m in ipairs(container:GetChildren())do
local p=getPos(m)
if p then
local k=cellKey(p)
grid[k]=grid[k]or{}
table.insert(grid[k],m)
end
end
end

local function isOccupied(pos,tol)
tol=tol or 1
local cx,cy,cz=math.floor(pos.X/CELL),math.floor(pos.Y/CELL),math.floor(pos.Z/CELL)
for dx=-1,1 do for dy=-1,1 do for dz=-1,1 do
local bucket=grid[("%d_%d_%d"):format(cx+dx,cy+dy,cz+dz)]
if bucket then
for _,m in ipairs(bucket)do
local p=getPos(m)
if p and(p-pos).Magnitude<tol then return true end
end
end
end end end
return false
end

local function markOccupied(pos)
local k=cellKey(pos)
grid[k]=grid[k]or{}
table.insert(grid[k],{Position=pos})
end

local function findModel(pos,tol)
tol=tol or 5
local cx,cy,cz=math.floor(pos.X/CELL),math.floor(pos.Y/CELL),math.floor(pos.Z/CELL)
local best,bestDist
for dx=-1,1 do for dy=-1,1 do for dz=-1,1 do
local bucket=grid[("%d_%d_%d"):format(cx+dx,cy+dy,cz+dz)]
if bucket then
for _,m in ipairs(bucket)do
local p=getPos(m)
if p then
local d=(p-pos).Magnitude
if d<tol and(not bestDist or d<bestDist)then
best,bestDist=m,d
end
end
end
end
end end end
return best
end

local function alreadyPainted(model,targetWS)
if typeof(model)=="table"then return false end
local v=model:FindFirstChild("BlueprintWoodClass")
return v and v.Value==targetWS
end

buildIndex()

local unavailableNames={}

if doPlace then

local blueprintFolder=lp:FindFirstChild("PlayerBlueprints")
and lp.PlayerBlueprints:FindFirstChild("Blueprints")

if blueprintFolder then
local uniqueNames={}
for _,entry in ipairs(buildingData)do
if entry.N and entry.N~=""then
uniqueNames[entry.N]=true
end
end

local missing={}
for name in pairs(uniqueNames)do
if not blueprintFolder:FindFirstChild(name)then
table.insert(missing,name)
end
end

if#missing>0 then
table.sort(missing)

local bought,stillCount,stillMissing=fillMissingBlueprints(missing)

if stillCount>0 then
for _,nm in ipairs(stillMissing)do unavailableNames[nm]=true end
notify("雪糕",string.format("已买齐 %d 种，仍缺 %d 种（这些将自动忽略，不影响放置和填充）",bought,stillCount),6)
else
notify("雪糕",string.format("已补齐 %d 种缺失蓝图",bought),4)
end
end
else

end

local placed,skippedP,failedP=0,0,0
for _,entry in ipairs(buildingData)do
if _G.qSnowPlaceStopFlag then notify("雪糕","已停止放置",3)break end
if entry.N and unavailableNames[entry.N]then
skippedP=skippedP+1
elseif not entry.CFrame then
failedP=failedP+1
elseif isOccupied(entry.CFrame.Position,1)then
skippedP=skippedP+1
else
local ok2=pcall(function()
placeRemote:FireServer(entry.N,entry.CFrame,lp)
end)
if ok2 then
placed=placed+1
markOccupied(entry.CFrame.Position)
else
failedP=failedP+1
end
if cfgPlaceDelay>0 then task.wait(cfgPlaceDelay)end
end
end
notify(label,string.format("放置：%d 跳 %d 失 %d",placed,skippedP,failedP),4)
end

if doPlace and doFill then
task.wait(cfgMidWait)
end

if doFill then
local gamepasses=lp:FindFirstChild("Gamepasses")
local hasPaint=gamepasses and gamepasses:FindFirstChild("paint")
local hasSpawn=gamepasses and gamepasses:FindFirstChild("spawn")
local paintOK=hasPaint and hasPaint.Value
local spawnOK=hasSpawn and hasSpawn.Value

local useNoColorMode=false
if not(paintOK or spawnOK)then
local choice=showConfirmDialog(
"缺少通行证",
"你没有 paint 或 spawn 通行证，无法使用普通方式填充材质。\n\n是否改用【无颜色填充】？\n（不设材质，模型保持默认颜色）"
)
if not choice then
notify("雪糕","已取消填充",3)
return
end
useNoColorMode=true
end

buildIndex()

if useNoColorMode then
local structureEvent=rs.PlaceStructure:FindFirstChild("ClientPlacedStructure")
if not structureEvent then
notify("雪糕","找不到 ClientPlacedStructure 事件",4)
return
end

local count=0
local noColorFail={}
local function fireNoColor(cframe,model)
pcall(function()
structureEvent:FireServer(table.unpack({
nil,
cframe,
nil,
nil,
model,
false
}))
end)
end
for _,entry in ipairs(buildingData)do
if _G.qSnowPlaceStopFlag then notify("雪糕","已停止填充",3)break end
if entry.N and unavailableNames[entry.N]then
-- 商店买不到的蓝图：忽略，不填充
else
local cframe=entry.CFrame
if cframe then
local model=findModel(cframe.Position,5)
if model then
fireNoColor(cframe,model)
count=count+1
else
noColorFail[#noColorFail+1]=entry
end
task.wait(0.2)
end
end
end

if#noColorFail>0 then
for round=1,3 do
if#noColorFail==0 or _G.qSnowPlaceStopFlag then break end
task.wait(1)
buildIndex()
local remain={}
for _,entry in ipairs(noColorFail)do
if _G.qSnowPlaceStopFlag then
remain[#remain+1]=entry
else
local cframe=entry.CFrame
local model=cframe and findModel(cframe.Position,10)
if model then
fireNoColor(cframe,model)
count=count+1
task.wait(0.2)
else
remain[#remain+1]=entry
end
end
end
noColorFail=remain
end
end

notify(label,string.format("无颜色填充：%d 个",count),5)
return
end

local painted,skippedF,filledWithMajority=0,0,0
local fail={}
local used={}

for i,entry in ipairs(buildingData)do
if _G.qSnowPlaceStopFlag then notify("雪糕","已停止填充",3)break end
if entry.N and unavailableNames[entry.N]then
-- 商店买不到的蓝图：忽略，不填充
else
local cframe=entry.CFrame
local material=entry.WS

if not material or material==""then
material=majorityWS
if material then filledWithMajority=filledWithMajority+1 end
end

if cframe and material then
local model=findModel(cframe.Position)
if model and not used[model]then
if alreadyPainted(model,material)then
skippedF=skippedF+1
used[model]=true
else
used[model]=true
paintTool:FireServer(model,material)
painted=painted+1
if cfgFillDelay>0 then task.wait(cfgFillDelay)end
end
else
fail[#fail+1]={entry=entry,i=i,fallback=material}
end
else
fail[#fail+1]={entry=entry,i=i,fallback=material}
end
end
end

if#fail>0 then
for round=1,3 do
if#fail==0 or _G.qSnowPlaceStopFlag then break end
task.wait(1)
buildIndex()
local remain={}
for _,f in ipairs(fail)do
if _G.qSnowPlaceStopFlag then
remain[#remain+1]=f
else
local cframe=f.entry.CFrame
local material=f.fallback or f.entry.WS
if not material or material==""then material=majorityWS end
local model=cframe and findModel(cframe.Position,10)
if model and material and not used[model]then
used[model]=true
if not alreadyPainted(model,material)then
paintTool:FireServer(model,material)
painted=painted+1
else
skippedF=skippedF+1
end
if cfgFillDelay>0 then task.wait(cfgFillDelay)end
else
remain[#remain+1]=f
end
end
end
fail=remain
end
end

local extra=""
if filledWithMajority>0 and majorityWS then
extra=string.format("（众数补 %d 条，材质 %s）",filledWithMajority,majorityWS)
end
notify(label,string.format("填充：%d 跳 %d 失 %d%s",painted,skippedF,#fail,extra),5)
end
end

local function getOutputFiles()
local files={}
if not listfiles then return files end

local paths={BLUEPRINT_FOLDER,"/"..BLUEPRINT_FOLDER}
local allFiles
for _,path in ipairs(paths)do
local ok,res=pcall(listfiles,path)
if ok and type(res)=="table"and#res>0 then
allFiles=res
break
end
end

if not allFiles then return files end

for _,f in ipairs(allFiles)do
if type(f)=="string"and(f:find("名字：",1,true)or f:find("名字:",1,true))then
table.insert(files,f)
end
end
return files
end

refreshBpFiles=function()
bpFileList=getOutputFiles()
bpFileLookup={}
local displayList={}
if#bpFileList==0 then
displayList={"(无)"}
else
for _,f in ipairs(bpFileList)do
local name=f:match("([^/\\]+)$")or f
table.insert(displayList,name)
bpFileLookup[name]=f
end
end
if bpFileDropdown then bpFileDropdown:SetOptions(displayList)end
return#bpFileList
end

bpFileDropdown=SectionPlace:Dropdown("选择文件","BpFileDropdown",{"(点击刷新)"},function(v)
bpSelectedFile=v
end)

SectionPlace:Button("刷新文件列表",function()
local n=refreshBpFiles()
notify("雪糕",string.format("找到 %d 个文件",n),3)
end)

SectionPlace:Button("传送到选中文件的基地",function()
if not bpSelectedFile or bpSelectedFile=="(无)"or bpSelectedFile=="(点击刷新)"then
notify("雪糕","请先选文件",3)
return
end
local filePath=bpFileLookup[bpSelectedFile]or bpSelectedFile
local content=readBlueprint(filePath)
if not content then
notify("雪糕","读取文件失败",3)
return
end
local x,y,z=content:match("%-%-%s*Base:%s*([%-%d%.]+),%s*([%-%d%.]+),%s*([%-%d%.]+)")
if not x then
notify("雪糕","文件里没有基地坐标",3)
return
end
x,y,z=tonumber(x),tonumber(y),tonumber(z)
local hrp=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
if hrp then
hrp.CFrame=CFrame.new(x,y+10,z)
notify("雪糕","已传送到该基地",3)
else
notify("雪糕","无法获取角色位置",3)
end
end)

SectionPlace:Button("开始执行",function()
if not doPlace and not doFill then
notify("雪糕","请至少开启「执行放置」或「执行填充」",3)
return
end
if not bpSelectedFile or bpSelectedFile=="(无)"or bpSelectedFile=="(点击刷新)"then
notify("雪糕","请先选文件",3)
return
end
local filePath=bpFileLookup[bpSelectedFile]or bpSelectedFile
local data=loadDataFromFile(filePath)
if not data then
notify("雪糕","加载失败："..tostring(filePath),4)
return
end
task.spawn(function()placeAndFill(data,bpSelectedFile)end)
end)

SectionPlace:Button("停止放置/填充",function()
_G.qSnowPlaceStopFlag=true
notify("雪糕","已发送放置/填充停止信号",3)
end)

SectionPlace:Label("缺失蓝图会在放置时自动购买并打开补齐","primary")

refreshBpFiles()
]====]
local SRC_AUTO = [====[

local win=_G.qSnowMainWin
if not win then
local bailib=loadstring(game:HttpGet("http://qinscript.lol/333/透明UI.lua"))()
win=bailib:new("自动购买","")
end
local lp=game.Players.LocalPlayer
local safeTeleport=_G.qSnowSafeTeleport
local dragToPosition=_G.qSnowDragToPosition
local Tab3=win:Tab("购买","2700297399")

local function uprightCFrame(hrp,cf)
local pos=cf.Position
local yRot=hrp and hrp.Orientation.Y or 0
return CFrame.new(pos)*CFrame.Angles(0,math.rad(yRot),0)
end

local lockPlayerConn=nil
local function unlockPlayer()
if lockPlayerConn then
lockPlayerConn:Disconnect()
lockPlayerConn=nil
end
end
local function lockPlayerAt(cf)
unlockPlayer()
local function hold()
local hrp=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
if hrp then
hrp.CFrame=uprightCFrame(hrp,cf)
hrp.Velocity=Vector3.new(0,0,0)
hrp.RotVelocity=Vector3.new(0,0,0)
end
end
hold()
lockPlayerConn=game:GetService("RunService").Heartbeat:Connect(hold)
end

local StoresFolder=workspace:WaitForChild("Stores")
local REPLICATED_STORAGE=game:GetService("ReplicatedStorage")
local TRANSLATE_URL="http://qinscript.lol/333/翻译商店.lua"

local translateMapping={}

local function loadTranslations()
local success,content=pcall(game.HttpGet,game,TRANSLATE_URL)
if not success or not content then
return false
end
local func,err=loadstring(content)
if not func then
return false
end
local ok,mapping=pcall(func)
if not ok or type(mapping)~="table"then
return false
end
translateMapping=mapping
return true
end

local function getDisplayName(enName)
local cnName=translateMapping[enName]
if cnName and cnName~=""then
return cnName.." ("..enName..")"
else
return enName
end
end

local storeInfoMapping={
AutumnCatalog={name="William",path="William"},
BlackMarket={name="sneakypotato7",path="sneakypotato7"},
CarStore={name="Jenny",path="Jenny"},
MusicStore={name="NazuReborn",path="NazuReborn"},
FineArt={name="Timothy",path="Timothy"},
FineFinds={name="Manachron",path="Manachron"},
FurnitureStore={name="Corey",path="Corey"},
HLStand={name="???",path="???"},
Igloo={name="Cold Guy",path="Cold Guy"},
LogicStore={name="Lincoln",path="Lincoln"},
MountainSide={name="Mr.Bacon",path="Mr.Bacon"},
PlanterStore={name="OGxOutcast",path="OGxOutcast"},
PlantomicsChoice={name="Null",path="Null"},
SallysSeasonal={name="Sally",path="Sally"},
SaplingCart={name="Billy",path="Billy"},
SeaSide={name="Guy",path="Guy"},
StoneRUs={name="Bloxyway",path="Bloxyway"},
TravelingTrader={name="Trader",path="Trader"},
VIPSHOP={name="Todd",path="Todd"},
WoodRUs={name="Thom",path="Thom"},
}

local function GetAllCashierIds()
local cashierIds={}
local receivedCount=0
local totalExpected=0
for _ in pairs(storeInfoMapping)do totalExpected=totalExpected+1 end

local connection=REPLICATED_STORAGE.NPCDialog.PromptChat.OnClientEvent:Connect(function(...)
local pack={...}
for _,v in ipairs(pack)do
if type(v)=="table"then
local nm=v.Name
local id=v.ID
if nm~=nil and id~=nil then
if not cashierIds[nm]then
cashierIds[nm]=id
receivedCount=receivedCount+1
end
end
end
end
end)

pcall(function()
REPLICATED_STORAGE.NPCDialog.SetChattingValue:InvokeServer(1)
end)

local timeout=20
local startTime=tick()
while receivedCount<totalExpected and tick()-startTime<timeout do
task.wait(0.2)
end

connection:Disconnect()
pcall(function()
REPLICATED_STORAGE.NPCDialog.SetChattingValue:InvokeServer(0)
end)

return cashierIds
end

_G.qSnowGetCashierIds=GetAllCashierIds

local npcMapping={}
for storeName,info in pairs(storeInfoMapping)do
npcMapping[storeName]={
name=info.name,
id=nil,
path=info.path,
statusLabel=nil
}
end

_G.qSnowNpcMapping=npcMapping

loadTranslations()

local stopPurchaseFlag=false

local function waitForItemRefresh(shopItems,itemName,timeout)
timeout=timeout or 10
local startTime=tick()
while tick()-startTime<timeout do
if stopPurchaseFlag then return false end
if shopItems:FindFirstChild(itemName)then
return true
end
task.wait(0.05)
end
return false
end

local function purchaseCycle(storeInfo,selectedItemName,buyAmount,doubleConfirm,itemCD)
local store=storeInfo.object
local shopItems=storeInfo.shopItems
local npcInfo=storeInfo.npc
if not npcInfo or not npcInfo.id then
notify("错误","商店 "..storeInfo.name.." NPC ID 无效",5)
return false
end

local npcChar=store:FindFirstChild(npcInfo.path)
if not npcChar then
notify("错误","找不到NPC: "..npcInfo.path,3)
return false
end

local counter=store:FindFirstChild("Counter")
if not counter or not counter:IsA("BasePart")then
notify("错误","商店 "..storeInfo.name.." 没有找到Counter部件",3)
return false
end

local NPCDialog=REPLICATED_STORAGE:WaitForChild("NPCDialog")

local function sendPurchaseAndCollect()
local purchasedItems={}
local conn=workspace.PlayerModels.ChildAdded:Connect(function(model)
if model:IsA("Model")and model:FindFirstChild("Owner")and model.Owner.Value==lp then
table.insert(purchasedItems,model)

end
end)

local args={
{
ID=npcInfo.id,
Character=npcChar,
Name=npcInfo.name,
},
"ConfirmPurchase"
}

local ok,err=pcall(function()
NPCDialog.PlayerChatted:InvokeServer(table.unpack(args))
end)
if not ok then
notify("购买失败",tostring(err),3)
conn:Disconnect()
return nil
end

task.wait(0.04)
conn:Disconnect()
return purchasedItems
end

local originalPos=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
if not originalPos then
notify("错误","无法获取玩家位置",3)
return false
end
originalPos=originalPos.CFrame

local function findItemByCD(cdValue)
for _,child in pairs(shopItems:GetChildren())do
local settings=child:FindFirstChild("Settings")
if settings then
local cd=settings:FindFirstChild("CD")
if cd and cd:IsA("StringValue")and cd.Value==cdValue then
return child
end
end
end
return nil
end

local function waitForItemRefreshByCD(cdValue,timeout)
timeout=timeout or 10
local startTime=tick()
while tick()-startTime<timeout do
if stopPurchaseFlag then return false end
local found=findItemByCD(cdValue)
if found then return true end
task.wait(0.05)
end
return false
end

local function waitForItemRefresh(itemName,timeout)
timeout=timeout or 10
local startTime=tick()
while tick()-startTime<timeout do
if stopPurchaseFlag then return false end
if shopItems:FindFirstChild(itemName)then
return true
end
task.wait(0.05)
end
return false
end

local successCycles=0
for i=1,buyAmount do
if stopPurchaseFlag then break end

local itemModel
if itemCD then
itemModel=findItemByCD(itemCD)
if not itemModel then
notify("商品消失","等待 CD: "..itemCD.." 上架...",3)
if not waitForItemRefreshByCD(itemCD,15)then
if stopPurchaseFlag then break end
notify("超时","等待 CD 刷新超时",3)
break
end
itemModel=findItemByCD(itemCD)
if not itemModel then break end
end
else
itemModel=shopItems:FindFirstChild(selectedItemName)
if not itemModel then
notify("商品消失",selectedItemName.." 不在货架，等待...",3)
if not waitForItemRefresh(selectedItemName,15)then
if stopPurchaseFlag then break end
notify("超时","等待商品 "..selectedItemName.." 刷新超时",3)
break
end
itemModel=shopItems:FindFirstChild(selectedItemName)
if not itemModel then break end
end
end

local itemPrimary=itemModel.PrimaryPart or itemModel:FindFirstChild("WoodSection")or itemModel:FindFirstChild("Main")or itemModel:FindFirstChildWhichIsA("BasePart")
if not itemPrimary then
notify("错误","无法定位商品模型",3)
break
end
if not itemModel.PrimaryPart then itemModel.PrimaryPart=itemPrimary end

if stopPurchaseFlag then break end

lockPlayerAt(itemPrimary.CFrame+Vector3.new(0,3,0))
task.wait(0.2)

if stopPurchaseFlag then break end
local counterSurface=counter.CFrame+Vector3.new(0,0.6,0)
dragToPosition(itemModel,counterSurface)

if stopPurchaseFlag then break end

lockPlayerAt(counter.CFrame+Vector3.new(0,3,0))
task.wait(0.1)

local allItems={}
local requestCount=doubleConfirm and 2 or 2
for k=1,requestCount do
if stopPurchaseFlag then break end
local items=sendPurchaseAndCollect()
if items then
for _,it in ipairs(items)do table.insert(allItems,it)end
else
break
end
if k<requestCount then
task.wait(0.01)
end
end

for _,item in ipairs(allItems)do
if stopPurchaseFlag then break end
if not item or not item.Parent then
notify("警告","购买的物品已消失，跳过",2)
continue
end
if not item.PrimaryPart then
local part=item:FindFirstChild("Main")or item:FindFirstChild("WoodSection")or item:FindFirstChildWhichIsA("BasePart")
if part then item.PrimaryPart=part end
end
dragToPosition(item,originalPos)
task.wait(0.05)
end

successCycles=successCycles+1

if i<buyAmount and not stopPurchaseFlag then
notify("等待刷新","商品被购买，等待它重新出现...",2)
local refreshed
if itemCD then
refreshed=waitForItemRefreshByCD(itemCD,30)
else
refreshed=waitForItemRefresh(selectedItemName,30)
end
if not refreshed then
if stopPurchaseFlag then break end
notify("超时","等待商品刷新超时，停止后续循环",3)
break
end
notify("刷新完成","商品已重新上架，继续下一次购买",2)
end
end

unlockPlayer()
safeTeleport(originalPos)
if stopPurchaseFlag then
notify("已停止","购买已中断，已返回原地",3)
stopPurchaseFlag=false
return false
else
notify(storeInfo.name,string.format("完成 %d / %d 次",successCycles,buyAmount),4)
return successCycles==buyAmount
end
end

local function updateNpcStatusLabel(npc,text)
if npc and npc.statusLabel then
pcall(function()
npc.statusLabel.Text=text
end)
end
end

local initialIds=GetAllCashierIds()
for storeName,info in pairs(storeInfoMapping)do
local npc=npcMapping[storeName]
if initialIds[info.name]then
npc.id=initialIds[info.name]
end
end

task.spawn(function()
local noProgress=0
while true do

local missingCount=0
for _,npc in pairs(npcMapping)do
if npc.id==nil then missingCount=missingCount+1 end
end

if missingCount==0 then break end

task.wait(2)

local newIds=GetAllCashierIds()
local gained=0
for storeName,info in pairs(storeInfoMapping)do
local npc=npcMapping[storeName]
if npc and npc.id==nil and newIds[info.name]then
npc.id=newIds[info.name]
gained=gained+1
if npc.statusLabel then
updateNpcStatusLabel(npc,"NPC ID: "..tostring(npc.id).." ✅")
end
end
end

if gained==0 then
noProgress=noProgress+1
if noProgress>=3 then break end
else
noProgress=0
end
end
end)

local allStores={}
for _,store in pairs(StoresFolder:GetChildren())do
local shopItems=store:FindFirstChild("ShopItems")
if shopItems and#shopItems:GetChildren()>0 then
local storeName=store.Name
local npcInfo=npcMapping[storeName]
if not npcInfo then

else

local itemsList={}
local isMusic=(storeName=="MusicStore")
for _,item in pairs(shopItems:GetChildren())do
local displayName=item.Name
if isMusic then
local settings=item:FindFirstChild("Settings")
if settings then
local cd=settings:FindFirstChild("CD")
if cd and cd:IsA("StringValue")and cd.Value~=""then
displayName=cd.Value
end
end
end
table.insert(itemsList,{model=item,display=displayName})
end
table.insert(allStores,{
name=storeName,
object=store,
shopItems=shopItems,
npc=npcInfo,
itemsList=itemsList,
isMusicStore=isMusic
})
end
end
end
table.sort(allStores,function(a,b)return a.name<b.name end)

local function openBlueprintBox(box)
if not box or not box.Parent then return false end
local primaryPart=box.PrimaryPart or box:FindFirstChild("Main")or box:FindFirstChildWhichIsA("BasePart")
if not primaryPart then return false end

safeTeleport(primaryPart.CFrame+Vector3.new(0,2,0))
task.wait(0.15)

local waited=0
while waited<1 do
if box:FindFirstChild("ButtonRemote_Main")or box:FindFirstChild("BoxItemName")or box:FindFirstChild("PurchasedBoxItemName")then
break
end
task.wait(0.2)
waited=waited+0.2
end

local remoteButton=box:FindFirstChild("ButtonRemote_Main")
if remoteButton then
return pcall(function()
REPLICATED_STORAGE.Interaction.RemoteProxy:FireServer(remoteButton)
end)
else
return pcall(function()
REPLICATED_STORAGE.Interaction.ClientInteracted:FireServer(box,'Open box')
end)
end
end

local function buyAllBlueprints()
stopPurchaseFlag=false
_G.qSnowStopFlag=false

local startHRP=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
local startCF=startHRP and startHRP.CFrame

local blueprintFolder=lp:FindFirstChild("PlayerBlueprints")
and lp.PlayerBlueprints:FindFirstChild("Blueprints")

local targets,seen={},{}
for _,store in ipairs(allStores)do
if store.shopItems then
for _,item in pairs(store.shopItems:GetChildren())do
local typeVal=item:FindFirstChild("Type")
local tstr=(typeVal and typeVal.Value~=nil)and tostring(typeVal.Value)or""
if tstr=="Blueprint"then
local nm=tostring(item.Name)
if nm~=""and not seen[nm]then
seen[nm]=true
if not(blueprintFolder and blueprintFolder:FindFirstChild(nm))then
targets[#targets+1]=nm
end
end
end
end
end
end
table.sort(targets)

if#targets==0 then
notify("雪糕","已拥有全部蓝图，或没找到可购买蓝图",3)
return
end

notify("雪糕",string.format("还缺 %d 种蓝图，开始购买",#targets),4)

local bought,stillMissing=0,{}
for _,nm in ipairs(targets)do
if stopPurchaseFlag then break end
local box,err=_G.qSnowBuyBlueprintBox(nm)
if not box then
table.insert(stillMissing,nm)
notify("雪糕","买不到 "..nm.."："..tostring(err),3)
else
openBlueprintBox(box)
local waited=0
while waited<5 and not(blueprintFolder and blueprintFolder:FindFirstChild(nm))do
task.wait(0.3)
waited=waited+0.3
if stopPurchaseFlag then break end
end
if blueprintFolder and blueprintFolder:FindFirstChild(nm)then
bought=bought+1
notify("雪糕","已得到蓝图: "..nm,2)
else
table.insert(stillMissing,nm)
end
end
task.wait(0.2)
end

if startCF then safeTeleport(startCF)end

if stopPurchaseFlag then
notify("雪糕","购买已停止，已返回原地",3)
return
end
if#stillMissing>0 then
local txt=table.concat(stillMissing,"\n")
pcall(function()setclipboard(txt)end)
notify("雪糕",string.format("本次新增 %d 种，仍缺 %d 种（已复制到剪贴板）",bought,#stillMissing),8)
else
notify("雪糕",string.format("购买完成，本次新增 %d 种蓝图",bought),5)
end
end

if#allStores==0 then
notify("错误","未找到任何可用的商店",5)
else

local SectionAllItems=Tab3:section("所有商品（搜索）",false)

SectionAllItems:Button("一键购买所有蓝图",function()
task.spawn(buyAllBlueprints)
end)

local allItemsList={}
for _,store in ipairs(allStores)do
if store.shopItems then
for _,item in pairs(store.shopItems:GetChildren())do
local itemName=item.Name
local translatedItem=getDisplayName(itemName)
local storeDisplay=getDisplayName(store.name)
table.insert(allItemsList,{
display=storeDisplay.." - "..translatedItem,
store=store,
item=itemName,
translated=translatedItem
})
end
end
end
table.sort(allItemsList,function(a,b)return a.display<b.display end)

local displayOptions={}
local itemMap={}
for _,entry in ipairs(allItemsList)do
table.insert(displayOptions,entry.display)
itemMap[entry.display]=entry
end

if#displayOptions==0 then
SectionAllItems:Label("暂无商品")
else
local selectedDisplay=displayOptions[1]
local selectedEntry=itemMap[selectedDisplay]

SectionAllItems:Dropdown("选择商品","AllItemsDropdown",displayOptions,function(sel)
selectedDisplay=sel
selectedEntry=itemMap[sel]
end)

local buyAmount=1
SectionAllItems:Textbox("循环次数","AllItemsBuyAmount","1",function(v)
local num=tonumber(v)
if num and num>0 then buyAmount=num else buyAmount=1 end
end)

local doubleConfirm=false
SectionAllItems:Toggle("双重确认","AllItemsDoubleConfirm",false,function(state)
doubleConfirm=state
end)

SectionAllItems:Button("开始购买",function()
if not selectedEntry then
notify("雪糕","请选择一个商品",3)
return
end
local store=selectedEntry.store
local item=selectedEntry.item
if not store.npc or not store.npc.id then
notify("雪糕","商店 '"..store.name.."' 无法购买（ID无效）",3)
return
end
_G.stopPurchaseFlag=false
pcall(function()
purchaseCycle(store,item,buyAmount,doubleConfirm)
end)
end)

SectionAllItems:Button("停止购买",function()
stopPurchaseFlag=true
_G.qSnowStopFlag=true
notify("雪糕","已发送停止信号",3)
end)
SectionAllItems:Label(string.format("共 %d 种商品",#displayOptions))
end

for _,store in ipairs(allStores)do
local storeName=store.name
local shopItemsFolder=store.shopItems
local npcInfo=store.npc

local storeDisplay=getDisplayName(storeName)
local section=Tab3:section(storeDisplay,false)

local statusText=(npcInfo.id and"NPC ID: "..tostring(npcInfo.id).." ✅")or"等待获取"
local statusLabel=section:Label(statusText)
npcInfo.statusLabel=statusLabel

local rawItems={}
for _,item in pairs(shopItemsFolder:GetChildren())do
table.insert(rawItems,{name=item.Name,model=item})
end
table.sort(rawItems,function(a,b)return a.name<b.name end)

local displayOptions={}
local valueMap={}
local isMusic=(storeName=="MusicStore")

for _,entry in ipairs(rawItems)do
local displayName=entry.name
local identifier=entry.name
if isMusic then
local settings=entry.model:FindFirstChild("Settings")
if settings then
local cd=settings:FindFirstChild("CD")
if cd and cd:IsA("StringValue")and cd.Value~=""then
displayName=cd.Value
identifier=cd.Value

if entry.model:FindFirstChild("RobuxItem")then
displayName=displayName.." (需要萝卜)"
end
end
end
end
local display=getDisplayName(displayName)
displayOptions[#displayOptions+1]=display
valueMap[display]=identifier
end

if#displayOptions==0 then
section:Label("该商店暂无商品")
else
local selectedIdentifier=valueMap[displayOptions[1]]
local currentDisplay=displayOptions[1]

section:Dropdown("选择商品","Dropdown_"..storeName,displayOptions,function(selectedDisplay)
currentDisplay=selectedDisplay
selectedIdentifier=valueMap[selectedDisplay]
end)

local buyAmount=1
section:Textbox("循环次数","Textbox_"..storeName,"输入数字（默认1）",function(value)
local num=tonumber(value)
if num and num>0 then buyAmount=num else buyAmount=1 end
end)

local doubleConfirmFlag=false
section:Toggle("双重确认","Toggle_"..storeName,doubleConfirmFlag,function(state)
doubleConfirmFlag=state
end)

section:Button("传送至柜台",function()
local counter=store.object:FindFirstChild("Counter")
if counter and counter:IsA("BasePart")then
safeTeleport(counter.CFrame+Vector3.new(0,2.5,0))
notify("传送",string.format("已传送到 %s 柜台",storeName),2)
else
notify("传送失败",string.format("商店 %s 没有找到 Counter 部件",storeName),3)
end
end)

section:Button("开始循环购买",function()
if not npcInfo.id then
notify("雪糕","商店 "..storeName.." ID 尚未获取，请稍后重试",3)
return
end
if not selectedIdentifier then
notify("雪糕","未选中商品",3)
return
end
stopPurchaseFlag=false
pcall(function()
if isMusic then

purchaseCycle(store,nil,buyAmount,doubleConfirmFlag,selectedIdentifier)
else

purchaseCycle(store,selectedIdentifier,buyAmount,doubleConfirmFlag,nil)
end
end)
end)

section:Button("停止购买",function()
stopPurchaseFlag=true
_G.qSnowStopFlag=true
notify("正在停止","已发送停止信号",3)
end)

section:Label(string.format("共 %d 种商品",#rawItems))
section:Label(string.format("NPC: %s",npcInfo.name))
end
end

local infoSection=Tab3:section("1",false)
infoSection:Label("1")
end

_G.qSnowBuyBlueprintBox=function(blueprintName)
if stopPurchaseFlag then return nil,"已停止"end
local targetStore,targetItemName=nil,nil
local lower=string.lower(tostring(blueprintName))
for _,s in ipairs(allStores)do
if s.shopItems then
for _,item in pairs(s.shopItems:GetChildren())do
if string.lower(tostring(item.Name))==lower then
targetStore,targetItemName=s,item.Name
break
end
end
end
if targetStore then break end
end
if not targetStore then
return nil,"没有任何商店出售蓝图: "..tostring(blueprintName)
end
if not targetStore.npc or not targetStore.npc.id then
return nil,"商店 "..targetStore.name.." 的 NPC ID 未获取"
end

local store=targetStore.object
local npcInfo=targetStore.npc
local npcChar=store:FindFirstChild(npcInfo.path)
if not npcChar then return nil,"找不到NPC: "..tostring(npcInfo.path)end
local counter=store:FindFirstChild("Counter")
if not counter or not counter:IsA("BasePart")then return nil,"商店无 Counter"end
local shopItems=store:FindFirstChild("ShopItems")
if not shopItems then return nil,"无 ShopItems"end

local itemModel=shopItems:FindFirstChild(targetItemName)
if not itemModel then return nil,"商品不在货架: "..targetItemName end
local primary=itemModel.PrimaryPart or itemModel:FindFirstChild("WoodSection")
or itemModel:FindFirstChild("Main")or itemModel:FindFirstChildWhichIsA("BasePart")
if not primary then return nil,"无法定位商品模型"end
if not itemModel.PrimaryPart then itemModel.PrimaryPart=primary end

lockPlayerAt(primary.CFrame+Vector3.new(0,3,0))
task.wait(0.3)

dragToPosition(itemModel,counter.CFrame+Vector3.new(0,0.6,0))
task.wait(0.09)

lockPlayerAt(counter.CFrame+Vector3.new(0,3,0))
task.wait(0.1)

local purchased={}
local conn=workspace.PlayerModels.ChildAdded:Connect(function(m)
if m:IsA("Model")and m:FindFirstChild("Owner")and m.Owner.Value==lp then
table.insert(purchased,m)
end
end)
local NPCDialog=REPLICATED_STORAGE:WaitForChild("NPCDialog")
local args={{ID=npcInfo.id,Character=npcChar,Name=npcInfo.name},"ConfirmPurchase"}
pcall(function()NPCDialog.PlayerChatted:InvokeServer(table.unpack(args))end)
task.wait(0.1)
pcall(function()NPCDialog.PlayerChatted:InvokeServer(table.unpack(args))end)
task.wait(0.1)
conn:Disconnect()

unlockPlayer()

for i=#purchased,1,-1 do
local m=purchased[i]
if m and m.Parent then
return m,targetStore.name
end
end
return nil,"购买后未找到新盒子"
end

_G.qSnowResetBuyStopFlag=function()
stopPurchaseFlag=false
_G.qSnowStopFlag=false
end

]====]


local function _log(msg)
    pcall(function()
        warn(tostring(msg))
    end)
    pcall(function()
        print(tostring(msg))
    end)
end

local function runPart(name, src)
    -- loadstring 出来的 chunk 属于"非 RobloxScript 上下文", 直接 require 游戏的 ModuleScript
    -- 会报 "Cannot require a RobloxScript module from a non RobloxScript context"。
    -- 必须在每个 chunk 开头把 require 换成执行器提供的那个。
    local preamble = "local require = (getgenv and getgenv().require) or require\n"
    local fn, lerr = loadstring(preamble .. src, "=" .. name)
    if not fn then
        _log("[runPart] " .. name .. " 编译失败: " .. tostring(lerr))
        return false
    end
    local ok, err = pcall(fn)
    if not ok then
        -- 原来这里直接把错误吞掉只 return false, 导致只能从 Roblox 日志里反推是哪一段挂了
        _log("[runPart] " .. name .. " 运行出错: " .. tostring(err))
        return false
    end
    return true
end



local AUTH_URL   = "http://qinscript.lol/api/card/verify"   
local AUTH_BYPASS_ON_FAIL = false                                

local CARD_FILE = "DexPlusPlusSetting.json"  


local function urlenc(s)
    local ok, enc = pcall(function() return game:GetService("HttpService"):UrlEncode(tostring(s)) end)
    if ok and enc then return enc end
    return tostring(s)
end


local function getHwid()
    local ok, cid = pcall(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    if ok and cid and cid ~= "" then return tostring(cid) end
    local uid = game:GetService("Players").LocalPlayer.UserId or 0
    return "FALLBACK_" .. tostring(uid)
end


local function getUsername()
    local plr = game:GetService("Players").LocalPlayer
    if plr and plr.Name then return tostring(plr.Name) end
    return ""
end



local function verifyCard(key, hwid, username)
    local keyStr = tostring(key or "")
    if AUTH_BYPASS_ON_FAIL and keyStr == "" then
        return true, "占位模式（未输入卡密），已放行"
    end
    local url = AUTH_URL .. "?key=" .. urlenc(keyStr)
        .. "&hwid=" .. urlenc(tostring(hwid))
        .. "&username=" .. urlenc(username or "")
    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok or not result then
        if AUTH_BYPASS_ON_FAIL then return true, "占位模式（服务器未就绪），已放行" end
        return false, "网络错误，无法连接验证服务器"
    end
    if string.find(result, "OK", 1, true) then
        return true, "卡密有效"
    end
    return false, (result ~= "" and result or "卡密无效")
end


local function loadSavedCardKey()
    if writefile and readfile then
        local ok, data = pcall(readfile, CARD_FILE)
        if ok and data then
            data = string.gsub(tostring(data), "%s", "")
            if data ~= "" then return data end
        end
    end
    return nil
end


local function saveCardKey(key)
    if writefile then
        pcall(writefile, CARD_FILE, tostring(key))
    end
end


local function askCardKey(callback)
    local lp = game:GetService("Players").LocalPlayer
    local pg = lp and lp:FindFirstChild("PlayerGui")
    if not pg then
        return callback(nil)
    end

    local sg = Instance.new("ScreenGui")
    sg.Name = "QSnowCardKey"
    sg.ResetOnSpawn = false
    sg.Parent = pg

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 118)
    frame.Position = UDim2.new(1, -312, 0, 12)
    frame.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    frame.BorderSizePixel = 0
    frame.Parent = sg
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 10); corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -24, 0, 26)
    title.Position = UDim2.new(0, 12, 0, 8)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 15
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "输入卡密"
    title.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 276, 0, 32)
    box.Position = UDim2.new(0, 12, 0, 38)
    box.PlaceholderText = "请输入卡密"
    box.Text = ""
    box.ClearTextOnFocus = false
    box.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.TextSize = 15
    box.Font = Enum.Font.SourceSans
    box.BorderSizePixel = 0
    box.Parent = frame
    local boxCorner = Instance.new("UICorner"); boxCorner.CornerRadius = UDim.new(0, 6); boxCorner.Parent = box

    local okBtn = Instance.new("TextButton")
    okBtn.Size = UDim2.new(0, 126, 0, 30)
    okBtn.Position = UDim2.new(0, 12, 0, 80)
    okBtn.BackgroundColor3 = Color3.fromRGB(0, 168, 90)
    okBtn.Text = "确认"
    okBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    okBtn.TextSize = 14
    okBtn.BorderSizePixel = 0
    okBtn.AutoButtonColor = true
    okBtn.Parent = frame
    local okCorner = Instance.new("UICorner"); okCorner.CornerRadius = UDim.new(0, 6); okCorner.Parent = okBtn

    local noBtn = Instance.new("TextButton")
    noBtn.Size = UDim2.new(0, 126, 0, 30)
    noBtn.Position = UDim2.new(0, 146, 0, 80)
    noBtn.BackgroundColor3 = Color3.fromRGB(92, 92, 98)
    noBtn.Text = "取消"
    noBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    noBtn.TextSize = 14
    noBtn.BorderSizePixel = 0
    noBtn.AutoButtonColor = true
    noBtn.Parent = frame
    local noCorner = Instance.new("UICorner"); noCorner.CornerRadius = UDim.new(0, 6); noCorner.Parent = noBtn

    local done = false
    local function finish(v)
        if done then return end
        done = true
        sg:Destroy()
        callback(v)
    end

    okBtn.MouseButton1Click:Connect(function() finish(box.Text) end)
    noBtn.MouseButton1Click:Connect(function() finish(nil) end)
end


local function askLoadBlueprint(callback)
    local lp = game:GetService("Players").LocalPlayer
    local pg = lp and lp:FindFirstChild("PlayerGui")
    if not pg then
        return callback(false)
    end

    local sg = Instance.new("ScreenGui")
    sg.Name = "QSnowConfirm"
    sg.ResetOnSpawn = false
    sg.Parent = pg

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 110)
    frame.Position = UDim2.new(1, -312, 0, 12)
    frame.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    frame.BorderSizePixel = 0
    frame.Parent = sg
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 10); corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -24, 0, 26)
    title.Position = UDim2.new(0, 12, 0, 8)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 15
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "是否加载蓝图功能？(第一次体验N/A小时)"
    title.Parent = frame

    local countLabel = Instance.new("TextLabel")
    countLabel.Size = UDim2.new(1, -24, 0, 20)
    countLabel.Position = UDim2.new(0, 12, 0, 36)
    countLabel.BackgroundTransparency = 1
    countLabel.Font = Enum.Font.SourceSans
    countLabel.TextSize = 13
    countLabel.TextColor3 = Color3.fromRGB(185, 185, 190)
    countLabel.TextXAlignment = Enum.TextXAlignment.Left
    countLabel.Text = "15 秒后自动关闭"
    countLabel.Parent = frame

    local okBtn = Instance.new("TextButton")
    okBtn.Size = UDim2.new(0, 126, 0, 30)
    okBtn.Position = UDim2.new(0, 12, 0, 62)
    okBtn.BackgroundColor3 = Color3.fromRGB(0, 168, 90)
    okBtn.Text = "加载蓝图"
    okBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    okBtn.TextSize = 14
    okBtn.BorderSizePixel = 0
    okBtn.AutoButtonColor = true
    okBtn.Parent = frame
    local okCorner = Instance.new("UICorner"); okCorner.CornerRadius = UDim.new(0, 6); okCorner.Parent = okBtn

    local noBtn = Instance.new("TextButton")
    noBtn.Size = UDim2.new(0, 126, 0, 30)
    noBtn.Position = UDim2.new(0, 146, 0, 62)
    noBtn.BackgroundColor3 = Color3.fromRGB(92, 92, 98)
    noBtn.Text = "不加载"
    noBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    noBtn.TextSize = 14
    noBtn.BorderSizePixel = 0
    noBtn.AutoButtonColor = true
    noBtn.Parent = frame
    local noCorner = Instance.new("UICorner"); noCorner.CornerRadius = UDim.new(0, 6); noCorner.Parent = noBtn

    local done = false
    local function finish(v)
        if done then return end
        done = true
        sg:Destroy()
        callback(v)
    end

    okBtn.MouseButton1Click:Connect(function() finish(true) end)
    noBtn.MouseButton1Click:Connect(function() finish(false) end)

    task.spawn(function()
        local remaining = 15
        while remaining > 0 and not done do
            countLabel.Text = tostring(remaining) .. " 秒后自动关闭"
            task.wait(1)
            remaining = remaining - 1
        end
        finish(false)
    end)
end



runPart("主脚本", SRC_MAIN)
runPart("主脚本2", SRC_MAIN2)
runPart("主脚本3", SRC_MAIN3)
runPart("自动购买", SRC_AUTO)


local hwid = getHwid()
local username = getUsername()
local savedKey = loadSavedCardKey()

askLoadBlueprint(function(confirmed)
    if not confirmed then return end

    
    if savedKey and savedKey ~= "" then
        local ok, msg = verifyCard(savedKey, hwid, username)
        if ok then
            runPart("蓝图工具", SRC_BP)
            return
        end
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "卡密验证失败",
                Text = tostring(msg),
                Duration = 6,
            })
        end)
        savedKey = nil  
    end

    askCardKey(function(key)
        if key == nil then return end  

        local keyStr = string.gsub(tostring(key), "%s", "")

        
        local ok, msg = verifyCard(keyStr, hwid, username)
        if not ok then
            pcall(function()
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title = "验证失败",
                    Text = tostring(msg),
                    Duration = 6,
                })
            end)
            return
        end

        if keyStr ~= "" then
            saveCardKey(keyStr)  
        end
        runPart("蓝图工具", SRC_BP)
    end)
end)
