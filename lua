-- CiaFork: standalone fork and front-wheel controls. No external loaders.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local function findScooter()
    for _, model in ipairs(workspace:GetDescendants()) do
        if model:IsA("Model") and model:FindFirstChild("FrontWheel") then
            local owner = model:FindFirstChild("ScooterOwner", true)
            if owner and owner:IsA("ObjectValue") and owner.Value == player then return model end
        end
    end
end
local function state(scooter)
    local fork = scooter and scooter:FindFirstChild("FrontFork")
    local swing = fork and fork:FindFirstChild("FrontSwingMotor")
    local suspension = scooter and scooter:FindFirstChild("FrontSuspension")
    local motor = suspension and suspension:FindFirstChild("VisualFWMotor")
    return swing and typeof(swing:GetAttribute("CiaForkOnlySwingC0")) == "CFrame" or false,
        motor and typeof(motor:GetAttribute("CiaWheelFlipOriginalC0")) == "CFrame" or false
end

-- Profiles use each model's observed mesh and spring paths.
local function forkProfile(scooter)
    if not scooter then return nil end
    local visuals = scooter:FindFirstChild("FrontForkModel")
        or scooter:FindFirstChild("FrontForkVisuals")
    if not visuals then return nil end
    local name = scooter.Name:lower():gsub("[^%w]", "")
    local frame = scooter:FindFirstChild("Frame")
    local spring = scooter:FindFirstChild("StickerSpring")
    if name:find("g2ultra", 1, true) then
        local nested = frame and frame:FindFirstChild("StickerSpring")
        if visuals:FindFirstChild("Plane.007") and visuals:FindFirstChild("Cube.003")
            and nested and nested:FindFirstChild("Object002.003") then return "G2 Ultra" end
        return nil
    elseif name:find("g2master", 1, true) then
        if visuals:FindFirstChild("Front_Fork_Carrier") and spring
            and spring:FindFirstChild("Front_Shock_Barrel") then return "G2 Master" end
        return nil
    elseif name:find("g3pro", 1, true) then
        if visuals:FindFirstChild("handlebars holder.001") and spring
            and spring:FindFirstChild("front suspension top part")
            and spring:FindFirstChild("front spring.003") then return "G3 Pro" end
        return nil
    end
    if visuals:FindFirstChild("G2_106_Fork_separated_carri_M02", true) then return "G2" end
    local nested = visuals:FindFirstChild("StickerSpring")
    if visuals:FindFirstChild("Plane.007") and visuals:FindFirstChild("Plane.006")
        and nested and nested:FindFirstChild("Object002.003", true) then return "G4" end
    return nil
end
local function toggleFork(scooter)
assert(scooter, "Your scooter was not found.")
local fork = scooter:FindFirstChild("FrontFork")
local visuals = scooter:FindFirstChild("FrontForkModel") or scooter:FindFirstChild("FrontForkVisuals")
local swing = fork and fork:FindFirstChild("FrontSwingMotor")
local steer
for _, item in ipairs(scooter:GetDescendants()) do
    if item:IsA("Motor6D") and item.Name == "SteerMotor" and item.Part1 == fork then
        steer = item
    end
end
assert(visuals and steer and swing and swing:IsA("Motor6D"), "Front fork joints or visuals missing.")

local restoringExisting = typeof(swing:GetAttribute("CiaForkOnlySwingC0")) == "CFrame"
local profile = forkProfile(scooter)
assert(restoringExisting or profile, "Unsupported or incomplete fork layout. Supported: G2, G4, G2 Ultra, G2 Master, G3 Pro.")
assert(swing.Part0 == fork and swing.Part1 == scooter:FindFirstChild("FrontSuspension"),
    "Unexpected front suspension motor connections.")

-- Undo prior whole-column and lower-arm tests.
for _, key in ipairs({"CiaSteerYOriginalC0", "CiaSteerJointOriginalC0", "CiaSteerOriginalC0"}) do
    local old = steer:GetAttribute(key)
    if typeof(old) == "CFrame" then steer.C0 = old; steer:SetAttribute(key, nil) end
end
local oldSwing = swing:GetAttribute("CiaForkOriginalC0")
if typeof(oldSwing) == "CFrame" then
    swing.C0 = oldSwing
    swing:SetAttribute("CiaForkOriginalC0", nil)
end
task.wait(0.1)

-- Fork carriers, bearings, front shock, front fender and suspension hardware.
-- Stem, grips, controls, handlebars and folding-column parts are excluded.
local ids = {[106]=true,[107]=true,[108]=true,[109]=true,[110]=true,
    [113]=true,[120]=true,[122]=true,[123]=true,[124]=true,[125]=true,
    [126]=true,[237]=true,[238]=true}
local savedKey = "CiaForkMeshOriginal"
local swingKey = "CiaForkOnlySwingC0"
local restoring = typeof(swing:GetAttribute(swingKey)) == "CFrame"
local selected = {}
local springVisuals = visuals:FindFirstChild("StickerSpring", true) or scooter:FindFirstChild("StickerSpring")
if profile == "G2 Ultra" then
    local frame = scooter:FindFirstChild("Frame")
    springVisuals = frame and frame:FindFirstChild("StickerSpring")
end
local suspension = swing.Part1
local hasCarrier = false
for _, part in ipairs(scooter:GetDescendants()) do
    if part:IsA("BasePart") then
        local id = tonumber(part.Name:match("^G2_(%d+)_"))
        local isForkMesh = part:IsDescendantOf(visuals) and (
            (profile == "G2" and ids[id])
            or ((profile == "G4" or profile == "G2 Ultra") and part.Parent == visuals
                and part.Name == "Plane.007")
            or (profile == "G2 Master" and
                (part == visuals:FindFirstChild("Front_Fork_Carrier")
                or (visuals:FindFirstChild("Front_Fork_Carrier")
                    and part:IsDescendantOf(visuals.Front_Fork_Carrier))))
        )
        local isSpringMesh = springVisuals and (part == springVisuals or part:IsDescendantOf(springVisuals))
        -- Pieces already carried by FrontSuspension follow its motor automatically.
        local followsSuspension = false
        if isSpringMesh and not restoring then
            for _, joint in ipairs(part:GetJoints()) do
                if joint:IsA("WeldConstraint") or joint:IsA("JointInstance") then
                    local other = joint.Part0 == part and joint.Part1 or joint.Part0
                    if other == suspension then followsSuspension = true end
                end
            end
        end
        if (restoring and typeof(part:GetAttribute(savedKey)) == "CFrame")
            or (not restoring and (isForkMesh or (isSpringMesh and not followsSuspension))) then
            table.insert(selected, {part=part})
            if (profile == "G2" and id == 106)
                or ((profile == "G4" or profile == "G2 Ultra") and isForkMesh)
                or (profile == "G2 Master" and part.Name == "Front_Fork_Carrier")
                or (profile == "G3 Pro" and isSpringMesh and part.Name == "front suspension top part") then
                hasCarrier = true
            end
        end
    end
end
assert(#selected > 0 and (restoring or hasCarrier), "Confirmed fork carrier not found.")
-- Find connections by their actual endpoints, regardless of name or parent.
local selectedParts, connected, welds = {}, {}, {}
for _, entry in ipairs(selected) do selectedParts[entry.part] = true end
for _, joint in ipairs(scooter:GetDescendants()) do
    if joint:IsA("WeldConstraint") or joint:IsA("JointInstance") then
        local a, b = joint.Part0, joint.Part1
        if selectedParts[a] or selectedParts[b] then
            assert(joint:IsA("WeldConstraint"),
                "Fork mesh has a different joint type: " .. joint:GetFullName()
                    .. " (" .. joint.ClassName .. ")")
            table.insert(welds, {joint=joint, enabled=joint.Enabled})
            if selectedParts[a] then connected[a] = true end
            if selectedParts[b] then connected[b] = true end
        end
    end
end
for _, entry in ipairs(selected) do
    if not connected[entry.part] then
        local child = entry.part:FindFirstChild("ActualMeshWeld")
        local detail = child and child.ClassName or "missing"
        if child and child:IsA("WeldConstraint") then
            detail = detail .. " Part0=" .. (child.Part0 and child.Part0:GetFullName() or "nil")
                .. " Part1=" .. (child.Part1 and child.Part1:GetFullName() or "nil")
                .. " Enabled=" .. tostring(child.Enabled)
        end
        error("No connected weld for " .. entry.part:GetFullName() .. "; child: " .. detail)
    end
end
-- Express the measured steering-axis turn in FrontFork's coordinates.
local pivot = steer.C1
local turn = pivot * CFrame.Angles(0, math.pi, 0) * pivot:Inverse()
-- Ultra's fork must remain on its steering-mount axis. A wheel-center
-- correction translates that mount away from the fixed stem.
if profile ~= "G2" and profile ~= "G2 Ultra" and not restoring then
    -- Keep the wheel center fixed instead of orbiting the shared steering pivot.
    -- Apply one rigid offset to the fork meshes, spring and swing motor together.
    local wheel = scooter:FindFirstChild("FrontWheel")
    assert(wheel and wheel:IsA("BasePart"), "Front wheel missing.")
    local center = fork.CFrame:PointToObjectSpace(wheel.Position)
    local rotatedCenter = turn:PointToWorldSpace(center)
    turn = CFrame.new(center - rotatedCenter) * turn
end
-- Springs/beams spanning the stationary fork root and rotating suspension
-- need their upper attachment moved; their lower attachment follows the motor.
local attachmentKey = "CiaForkSpringOriginal"
local attachmentTargets = {}
if restoring then
    for _, item in ipairs(scooter:GetDescendants()) do
        if item:IsA("Attachment") and typeof(item:GetAttribute(attachmentKey)) == "CFrame" then
            attachmentTargets[item] = item:GetAttribute(attachmentKey)
        end
    end
else
    local function onLower(part)
        return part == suspension or (part and part:IsDescendantOf(suspension))
    end
    local function addUpper(upper, lower)
        if not upper or not lower then return end
        if upper.Parent ~= fork or not onLower(lower.Parent) then return end
        if not attachmentTargets[upper] then
            upper:SetAttribute(attachmentKey, upper.CFrame)
            attachmentTargets[upper] = turn * upper.CFrame
        end
    end
    for _, item in ipairs(scooter:GetDescendants()) do
        if item:IsA("SpringConstraint") or item:IsA("Beam") or item:IsA("RopeConstraint") then
            addUpper(item.Attachment0, item.Attachment1)
            addUpper(item.Attachment1, item.Attachment0)
        end
    end
end
local targets = {}
for _, entry in ipairs(selected) do
    local part = entry.part
    local original = restoring and part:GetAttribute(savedKey)
        or fork.CFrame:ToObjectSpace(part.CFrame)
    if not restoring then part:SetAttribute(savedKey, original) end
    targets[part] = fork.CFrame * (restoring and original or turn * original)
end
if not restoring then swing:SetAttribute(swingKey, swing.C0) end
for _, entry in ipairs(welds) do entry.joint.Enabled = false end
local ok, err = pcall(function()
    for part, target in pairs(targets) do part.CFrame = target end
    for attachment, target in pairs(attachmentTargets) do attachment.CFrame = target end
    swing.C0 = restoring and swing:GetAttribute(swingKey)
        or turn * swing:GetAttribute(swingKey)
end)
for _, entry in ipairs(welds) do entry.joint.Enabled = entry.enabled end
assert(ok, err)
if restoring then
    swing:SetAttribute(swingKey, nil)
    for attachment in pairs(attachmentTargets) do attachment:SetAttribute(attachmentKey, nil) end
    for _, entry in ipairs(selected) do entry.part:SetAttribute(savedKey, nil) end
end
print("[CiaInvertedFork]", restoring and "Restored." or "Fork-only turn applied. Run again to restore.",
    "Meshes:", #selected)

end

local function toggleWheel(scooter)
assert(scooter, "Your scooter was not found.")
local suspension = scooter:FindFirstChild("FrontSuspension")
local wheel = scooter:FindFirstChild("FrontWheel")
local motor = suspension and suspension:FindFirstChild("VisualFWMotor")
assert(motor and motor:IsA("Motor6D") and motor.Part0 == suspension
    and motor.Part1 == wheel, "Front wheel motor connection missing.")
local key = "CiaWheelFlipOriginalC0"
local original = motor:GetAttribute(key)
if typeof(original) == "CFrame" then
    motor.C0 = original
    motor:SetAttribute(key, nil)
    print("[CiaWheel] Original wheel orientation restored.")
else
    original = motor.C0
    motor:SetAttribute(key, original)
    -- Turn around suspension-local vertical through the wheel joint.
    local axis = original:VectorToObjectSpace(Vector3.new(0, 1, 0))
    motor.C0 = original * CFrame.fromAxisAngle(axis, math.pi)
    print("[CiaWheel] Front wheel turned 180 degrees. Run again to restore.")
end

end

-- Per-profile calibration. Save persists to an executor file when available.
local HttpService = game:GetService("HttpService")
local calibrationFile = "CiaFork-calibration-v1.json"
local fields = {"forward", "up", "side", "pivotForward", "pivotUp"}
local function cleanCalibration(value)
    local result = {}
    for _, key in ipairs(fields) do
        local n = type(value) == "table" and tonumber(value[key]) or 0
        if not n or n ~= n or math.abs(n) == math.huge then n = 0 end
        result[key] = math.clamp(n, -3, 3)
    end
    return result
end
local savedCalibration = {}
local function importCalibration(data)
    if type(data) ~= "table" then return end
    for _, name in ipairs({"G2", "G4", "G2 Ultra", "G2 Master", "G3 Pro"}) do
        if type(data[name]) == "table" then savedCalibration[name] = cleanCalibration(data[name]) end
    end
end
if type(readfile) == "function" then
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(calibrationFile)) end)
    if ok then importCalibration(data) end
end
importCalibration(_G.CiaForkSavedCalibration)
local workingCalibration = {}
local function settingsFor(profile)
    if not workingCalibration[profile] then
        workingCalibration[profile] = cleanCalibration(savedCalibration[profile])
    end
    return workingCalibration[profile]
end
local appliedKey = "CiaForkAlignmentOffset"
local valuesKey = "CiaForkAlignmentValues"
local function applyCalibration(scooter, values)
    local enabled = state(scooter)
    if not enabled then return end
    local fork = scooter:FindFirstChild("FrontFork")
    local body = scooter:FindFirstChild("Body")
    local swing = fork and fork:FindFirstChild("FrontSwingMotor")
    local steer
    for _, item in ipairs(scooter:GetDescendants()) do
        if item:IsA("Motor6D") and item.Name == "SteerMotor" and item.Part1 == fork then steer=item;break end
    end
    assert(fork and body and body:IsA("BasePart") and swing and steer, "Alignment joints missing.")
    values = cleanCalibration(values)
    local forward = fork.CFrame:VectorToObjectSpace(body.CFrame.LookVector)
    local up = fork.CFrame:VectorToObjectSpace(body.CFrame.UpVector)
    local side = fork.CFrame:VectorToObjectSpace(body.CFrame.RightVector)
    local rotation = steer.C1.Rotation * CFrame.Angles(0, math.pi, 0) * steer.C1.Rotation:Inverse()
    local pivotShift = forward * values.pivotForward + up * values.pivotUp
    local offset = forward * values.forward + up * values.up + side * values.side
        + pivotShift - rotation:VectorToWorldSpace(pivotShift)
    local previous = swing:GetAttribute(appliedKey)
    if typeof(previous) ~= "Vector3" then previous = Vector3.zero end
    local delta = offset - previous
    if delta.Magnitude < 0.000001 then
        swing:SetAttribute(valuesKey, HttpService:JSONEncode(values))
        return
    end
    local parts, attachments, selected, welds = {}, {}, {}, {}
    for _, item in ipairs(scooter:GetDescendants()) do
        if item:IsA("BasePart") and typeof(item:GetAttribute("CiaForkMeshOriginal")) == "CFrame" then
            selected[item]=true
            table.insert(parts,{part=item,original=item.CFrame})
        elseif item:IsA("Attachment") and typeof(item:GetAttribute("CiaForkSpringOriginal")) == "CFrame" then
            assert(item.Parent == fork, "Spring attachment parent changed; restore first.")
            table.insert(attachments,{part=item,original=item.CFrame})
        end
    end
    assert(#parts>0, "No saved fork meshes; restore and enable inversion again.")
    for _, item in ipairs(scooter:GetDescendants()) do
        if item:IsA("WeldConstraint") or item:IsA("JointInstance") then
            if selected[item.Part0] or selected[item.Part1] then
                assert(item:IsA("WeldConstraint"), "Unexpected mesh joint; restore before aligning.")
                table.insert(welds,{joint=item,enabled=item.Enabled})
            end
        end
    end
    local originalSwing = swing.C0
    local worldDelta = fork.CFrame:VectorToWorldSpace(delta)
    -- No yields while visual welds are released.
    for _, entry in ipairs(welds) do entry.joint.Enabled=false end
    local ok,err=pcall(function()
        for _, entry in ipairs(parts) do entry.part.CFrame=entry.original+worldDelta end
        for _, entry in ipairs(attachments) do entry.part.CFrame=entry.original+delta end
        swing.C0=originalSwing+delta
    end)
    if not ok then
        pcall(function()
            for _, entry in ipairs(parts) do entry.part.CFrame=entry.original end
            for _, entry in ipairs(attachments) do entry.part.CFrame=entry.original end
            swing.C0=originalSwing
        end)
    end
    for _, entry in ipairs(welds) do if entry.joint.Parent then entry.joint.Enabled=entry.enabled end end
    assert(ok,err)
    swing:SetAttribute(appliedKey,offset)
    swing:SetAttribute(valuesKey,HttpService:JSONEncode(values))
end
local uncalibratedToggleFork = toggleFork
toggleFork = function(scooter)
    uncalibratedToggleFork(scooter)
    local fork=scooter:FindFirstChild("FrontFork")
    local swing=fork and fork:FindFirstChild("FrontSwingMotor")
    if swing then
        swing:SetAttribute(appliedKey,nil)
        swing:SetAttribute(valuesKey,nil)
    end
    if state(scooter) then
        local profile=forkProfile(scooter)
        if profile then applyCalibration(scooter,settingsFor(profile)) end
    end
end

local previous = playerGui:FindFirstChild("CiaForkUI")
if previous then previous:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "CiaForkUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui
local alive, busy = true, false
local connections = {}
local C = {
    base = Color3.fromRGB(13,17,22), card = Color3.fromRGB(22,28,35),
    border = Color3.fromRGB(43,53,64), green = Color3.fromRGB(157,255,83),
    text = Color3.fromRGB(239,244,248), muted = Color3.fromRGB(149,164,178),
    error = Color3.fromRGB(255,183,104),
}
local function make(class, parent, props)
    local obj = Instance.new(class)
    for k,v in pairs(props) do obj[k] = v end
    obj.Parent = parent
    return obj
end
local function corner(obj, radius)
    make("UICorner", obj, {CornerRadius=UDim.new(0,radius or 6)})
end
local function outline(obj)
    make("UIStroke",obj,{Color=C.border,Thickness=1})
end
local function label(parent, text, x,y,w,h,size,color,bold)
    return make("TextLabel",parent,{
        Text=text, Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        BackgroundTransparency=1,TextColor3=color or C.text,TextSize=size or 14,
        Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left,
    })
end
local function button(parent,text,x,y,w,h)
    local b=make("TextButton",parent,{
        Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        BackgroundColor3=C.card,BorderSizePixel=0,TextColor3=C.text,TextSize=12,
        Font=Enum.Font.GothamBold,AutoButtonColor=true,
    })
    corner(b);outline(b)
    return b
end
local panel=make("Frame",gui,{
    Size=UDim2.fromOffset(380,780),Position=UDim2.new(0.5,-190,0.5,-390),
    BackgroundColor3=C.base,BorderSizePixel=0,Active=true,
})
corner(panel,8);outline(panel)
local scale=make("UIScale",panel,{Scale=1})
local function fit()
    local camera=workspace.CurrentCamera
    if camera then scale.Scale=math.min(1,math.max(0.4,(camera.ViewportSize.X-24)/380),math.max(0.4,(camera.ViewportSize.Y-24)/780)) end
end
fit()
local accent=make("Frame",panel,{Position=UDim2.fromOffset(20,20),Size=UDim2.fromOffset(3,37),BackgroundColor3=C.green,BorderSizePixel=0})
local dragBar=make("Frame",panel,{Size=UDim2.fromOffset(284,70),BackgroundTransparency=1,Active=true})
label(dragBar,"CiaFork",32,16,230,28,24,C.text,true)
label(dragBar,"SCOOTER CUSTOMIZATION",33,46,230,15,10,C.green,true)
local hide=button(panel,"–",293,20,28,28)
local close=button(panel,"×",329,20,28,28)
local scooterLabel=label(panel,"Finding your scooter…",20,77,340,22,12,C.muted)
scooterLabel.TextTruncate=Enum.TextTruncate.AtEnd
local function row(y,title,subtitle)
    local card=make("Frame",panel,{Position=UDim2.fromOffset(20,y),Size=UDim2.fromOffset(340,70),BackgroundColor3=C.card,BorderSizePixel=0})
    corner(card);outline(card)
    label(card,title,14,12,232,22,14,C.text,true)
    local caption=label(card,subtitle,14,38,230,18,10,C.muted)
    return button(card,"OFF",255,20,70,30), caption
end
local forkButton,forkCaption=row(110,"INVERT SUSPENSION","Detecting fork layout…")
local wheelButton=row(190,"FLIP FRONT WHEEL","180° turn · compatible wheel joint")
local restore=button(panel,"RESTORE ALL",20,662,340,34)
local status=label(panel,"Enable inversion, then adjust the alignment sliders.",20,708,340,44,11,C.muted)
status.TextWrapped=true
status.TextYAlignment=Enum.TextYAlignment.Top
label(panel,"CIA SCRIPTS",20,758,340,12,9,C.green,true)
local launcher=button(gui,"CF",0,0,48,40)
launcher.AnchorPoint=Vector2.new(1,0)
launcher.Position=UDim2.new(1,-16,0,80)
launcher.BackgroundColor3=C.green
launcher.TextColor3=C.base
local function message(text,failed)
    if not alive then return end
    status.Text=text
    status.TextColor3=failed and C.error or C.muted
end
local calibrationCard=make("Frame",panel,{
    Position=UDim2.fromOffset(20,274),Size=UDim2.fromOffset(340,336),
    BackgroundColor3=C.card,BorderSizePixel=0,
})
corner(calibrationCard);outline(calibrationCard)
label(calibrationCard,"LIVE ALIGNMENT",14,10,210,20,12,C.text,true)
label(calibrationCard,"Studs · enable inversion to preview",14,32,310,16,10,C.muted)
local saveAlignment=button(panel,"SAVE MODEL",20,620,165,32)
local resetAlignment=button(panel,"RESET SLIDERS",195,620,165,32)
local sliders={}
local alignmentModel, alignmentProfile
local pendingAlignment=false
local sliderDrag
local sliderSpecs={
    {key="forward",title="FORWARD / BACK"},
    {key="up",title="UP / DOWN"},
    {key="side",title="RIGHT / LEFT"},
    {key="pivotForward",title="PIVOT FORWARD / BACK"},
    {key="pivotUp",title="PIVOT UP / DOWN"},
}
local function drawSlider(slider,value)
    local ratio=(value+3)/6
    slider.fill.Size=UDim2.fromScale(ratio,1)
    slider.knob.Position=UDim2.fromScale(ratio,0.5)
    if not slider.input:IsFocused() then slider.input.Text=string.format("%+.2f",value) end
end
local function setAlignment(key,value)
    if busy or not alignmentProfile then return end
    local n=tonumber(value)
    if not n or n~=n or math.abs(n)==math.huge then return end
    n=math.floor(math.clamp(n,-3,3)*100+0.5)/100
    settingsFor(alignmentProfile)[key]=n
    drawSlider(sliders[key],n)
    pendingAlignment=true
end
local function sliderAt(slider,x)
    local width=slider.hit.AbsoluteSize.X
    if width>0 then
        setAlignment(slider.key,-3+6*math.clamp((x-slider.hit.AbsolutePosition.X)/width,0,1))
    end
end
for i,spec in ipairs(sliderSpecs) do
    local y=56+(i-1)*54
    label(calibrationCard,spec.title,14,y,220,18,10,C.muted,true)
    local input=make("TextBox",calibrationCard,{
        Position=UDim2.fromOffset(254,y-2),Size=UDim2.fromOffset(72,22),
        BackgroundColor3=C.base,BorderSizePixel=0,Font=Enum.Font.GothamBold,
        TextColor3=C.green,TextSize=12,Text="+0.00",ClearTextOnFocus=false,
    })
    corner(input,4)
    local hit=make("TextButton",calibrationCard,{
        Position=UDim2.fromOffset(20,y+20),Size=UDim2.fromOffset(300,24),
        BackgroundTransparency=1,Text="",AutoButtonColor=false,
    })
    local track=make("Frame",hit,{Position=UDim2.new(0,0,0.5,-2),Size=UDim2.new(1,0,0,4),BackgroundColor3=C.border,BorderSizePixel=0})
    corner(track,2)
    local fill=make("Frame",track,{Size=UDim2.fromScale(0.5,1),BackgroundColor3=C.green,BorderSizePixel=0})
    corner(fill,2)
    make("Frame",track,{Position=UDim2.new(0.5,0,0,-3),Size=UDim2.fromOffset(1,10),BackgroundColor3=C.muted,BorderSizePixel=0})
    local knob=make("Frame",track,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(14,14),BackgroundColor3=C.text,BorderSizePixel=0})
    corner(knob,7)
    local slider={key=spec.key,input=input,hit=hit,fill=fill,knob=knob}
    sliders[spec.key]=slider
    hit.InputBegan:Connect(function(event)
        if busy then return end
        if event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch then
            sliderDrag={slider=slider,event=event}
            sliderAt(slider,event.Position.X)
        end
    end)
    input.FocusLost:Connect(function()
        setAlignment(spec.key,input.Text)
        drawSlider(slider,alignmentProfile and settingsFor(alignmentProfile)[spec.key] or 0)
    end)
end
table.insert(connections,UIS.InputChanged:Connect(function(input)
    if sliderDrag and (input==sliderDrag.event or (sliderDrag.event.UserInputType==Enum.UserInputType.MouseButton1
        and input.UserInputType==Enum.UserInputType.MouseMovement)) then sliderAt(sliderDrag.slider,input.Position.X) end
end))
table.insert(connections,UIS.InputEnded:Connect(function(input)
    if sliderDrag and input==sliderDrag.event then sliderDrag=nil end
end))
local function syncAlignment(scooter,profile)
    if scooter~=alignmentModel or profile~=alignmentProfile then
        pendingAlignment=false
        sliderDrag=nil
        alignmentModel,alignmentProfile=scooter,profile
        if profile and scooter then
            local fork=scooter:FindFirstChild("FrontFork")
            local swing=fork and fork:FindFirstChild("FrontSwingMotor")
            local encoded=swing and swing:GetAttribute(valuesKey)
            if state(scooter) and type(encoded)=="string" then
                local ok,data=pcall(function() return HttpService:JSONDecode(encoded) end)
                if ok then workingCalibration[profile]=cleanCalibration(data) end
            end
        end
        for key,slider in pairs(sliders) do
            drawSlider(slider,profile and settingsFor(profile)[key] or 0)
        end
    end
end
saveAlignment.Activated:Connect(function()
    if busy or not alignmentProfile then return end
    savedCalibration[alignmentProfile]=cleanCalibration(settingsFor(alignmentProfile))
    _G.CiaForkSavedCalibration=savedCalibration
    if type(writefile)=="function" then
        local ok,err=pcall(function() writefile(calibrationFile,HttpService:JSONEncode(savedCalibration)) end)
        if ok then message("Saved alignment for "..alignmentProfile..".")
        else message("Saved this session; file save failed: "..tostring(err),true) end
    else
        message("Saved for "..alignmentProfile.." this session (file saving unavailable).")
    end
end)
resetAlignment.Activated:Connect(function()
    if busy or not alignmentProfile then return end
    workingCalibration[alignmentProfile]=cleanCalibration(nil)
    for _,slider in pairs(sliders) do drawSlider(slider,0) end
    pendingAlignment=true
    message("Sliders reset. Save Model to keep these values.")
end)
local alignmentClock=0
table.insert(connections,game:GetService("RunService").Heartbeat:Connect(function(dt)
    alignmentClock=alignmentClock+dt
    if alignmentClock<0.06 or not pendingAlignment or busy or not alive then return end
    alignmentClock=0
    pendingAlignment=false
    local scooter=alignmentModel
    if not scooter or not scooter:IsDescendantOf(workspace) or not alignmentProfile then return end
    if not state(scooter) then message("Values ready. Enable Invert Suspension to preview.");return end
    local ok,err=pcall(applyCalibration,scooter,settingsFor(alignmentProfile))
    if ok then message("Preview updated. Save Model when aligned.")
    else message(tostring(err),true);warn("[CiaFork] "..tostring(err)) end
end))

local shown={}
local function paint(b,on)
    local marker=(on and "ON" or "OFF")..tostring(busy)
    if shown[b]==marker then return end
    shown[b]=marker
    b.Text=busy and "…" or (on and "ON" or "OFF")
    TweenService:Create(b,TweenInfo.new(0.15),{
        BackgroundColor3=on and C.green or C.base,
        TextColor3=on and C.base or C.muted,
    }):Play()
end
local current
local function refresh(rescan)
    if not alive then return end
    if rescan or not current or not current:IsDescendantOf(workspace) then current=findScooter() end
    local forkOn,wheelOn=state(current)
    paint(forkButton,forkOn);paint(wheelButton,wheelOn)
    scooterLabel.Text=current and current.Name or "Spawn your scooter to use these controls."
    local profile=forkProfile(current)
    syncAlignment(current,profile)
    forkCaption.Text=profile and ("Fork + spring · "..profile.." layout")
        or (current and "Unsupported fork layout" or "Waiting for scooter")
end
local function restoreScooter(scooter)
    local forkOn,wheelOn=state(scooter)
    local errors={}
    if wheelOn then
        local ok,err=pcall(toggleWheel,scooter)
        if not ok then table.insert(errors,tostring(err)) end
    end
    if forkOn then
        local ok,err=pcall(toggleFork,scooter)
        if not ok then table.insert(errors,tostring(err)) end
    end
    assert(#errors==0,table.concat(errors," | "))
end
local function perform(action,success,closing)
    if busy or not alive then return end
    local scooter=findScooter()
    if not scooter and not closing then message("Spawn your scooter first.",true);return end
    busy=true;refresh()
    task.spawn(function()
        local ok,err=true,nil
        if scooter then ok,err=pcall(action,scooter) end
        busy=false
        if not alive then return end
        refresh(true)
        if ok then
            if closing then gui:Destroy() else message(success) end
        else
            message(tostring(err),true)
            warn("[CiaFork] "..tostring(err))
        end
    end)
end
forkButton.Activated:Connect(function() perform(toggleFork,"Suspension setting updated.") end)
wheelButton.Activated:Connect(function() perform(toggleWheel,"Front-wheel setting updated.") end)
restore.Activated:Connect(function() perform(restoreScooter,"Both controls restored.") end)
close.Activated:Connect(function() perform(restoreScooter,"",true) end)
hide.Activated:Connect(function() panel.Visible=false end)
launcher.Activated:Connect(function() panel.Visible=not panel.Visible end)
local dragging,startPointer,startPosition
local function dragTo(position)
    if not dragging then return end
    local delta=position-startPointer
    panel.Position=UDim2.new(startPosition.X.Scale,startPosition.X.Offset+delta.X,
        startPosition.Y.Scale,startPosition.Y.Offset+delta.Y)
end
dragBar.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        dragging=input;startPointer=input.Position;startPosition=panel.Position
    end
end)
table.insert(connections,UIS.InputChanged:Connect(function(input)
    if dragging and (input==dragging or (dragging.UserInputType==Enum.UserInputType.MouseButton1
        and input.UserInputType==Enum.UserInputType.MouseMovement)) then dragTo(input.Position) end
end))
table.insert(connections,UIS.InputEnded:Connect(function(input) if input==dragging then dragging=nil end end))
gui.Destroying:Connect(function()
    alive=false
    for _,connection in ipairs(connections) do connection:Disconnect() end
end)
refresh(true)
task.spawn(function()
    while alive do
        task.wait(1)
        if alive then refresh(true);fit() end
    end
end)
