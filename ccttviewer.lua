if not rednet then error"requires rednet" end
local server_id=...

fs.makeDir"lib"
if not package.path:find("/lib/?") then
    package.path=package.path..";/lib/?;/lib/?.lua;/lib/?/init.lua"
end

local cctt=require"cctt"

local loading=cctt.new_frame(40,18)
local red,nat=loading:redirect_target(),term.current()
term.redirect(red)
term.setCursorPos(16,9)
print("Loading...")
term.redirect(nat)

local current_frame=nil
local pagecache={}

local function getPage(pagenum)
    if pagecache[pagenum]~=nil then
        current_frame=pagecache[pagenum]
        return
    end
    local tmp=cctt.load_frame(loading:encode())
    tmp:set_page_number(pagenum)
    pagecache[pagenum]=tmp
    getPage(pagenum)
end
getPage(0)

local function comms()
    while true do
        local from,msg=rednet.receive("cctt")
        if from==server_id then
            local ok,frame=pcall(cctt.load_frame,msg)
            if ok then
                pagecache[frame:page_number()]=frame
                if current_frame:page_number()==frame:page_number() then
                    current_frame=frame
                    os.queueEvent("cctt_redraw")
                end
            end
        end
    end
end

local pagenum_typing=""
local pagenum_istyping=false
local pagenum_legal={}
for i=0,9 do pagenum_legal[tostring(i)]=true end

local w,h=term.getSize()
local redrawtime=0
local redraw
local function drawClock()
    term.setCursorPos(w-7,1)
    if os.date("%T")=="00:00:00" then
        local time=os.epoch("utc")
        if time-redrawtime>1000 then
            redraw()
            redrawtime=time
        end
    end
    term.write(os.date("%T"))
end
function redraw()
    local fw,fh=current_frame:size()
    term.setBackgroundColor(colors.gray)
    term.clear()
    term.setBackgroundColor(colors.black)
    local x=math.floor(w/2)-math.floor(fw/2)+1
    local y=math.floor((h-1)/2)-math.floor(fh/2)+2
    current_frame:draw(x,y)
    term.setCursorPos(1,1)
    term.clearLine()
    term.write(pagenum_istyping and (pagenum_typing.."------"):sub(1,6) or string.format("%06d",current_frame:page_number()))
    local header=current_frame:header()
    if header=="        " then header="" end
    if header~="" then header=header.." " end
    local mid=header..os.date("%a  %d  %h")
    term.setCursorPos(math.floor(w/2)-math.floor(#mid/2)+1,1)
    term.write(mid)
    drawClock()
end
local function mainloop()
    redraw()
    local drawClock_timer=os.startTimer(1)
    while true do
        local tEvent=table.pack(os.pullEvent())
        if tEvent[1]=="char" then
            if tEvent[2]=="q" then
                return
            elseif pagenum_legal[tEvent[2]] then
                pagenum_typing=pagenum_typing..tEvent[2]
                pagenum_istyping=true
                if #pagenum_typing==6 then
                    getPage(tonumber(pagenum_typing))
                    pagenum_typing=""
                    pagenum_istyping=false
                end
                redraw()
            end
        end
        if tEvent[1]=="key" then
            if tEvent[2]==keys.enter and pagenum_istyping then
                getPage(tonumber(pagenum_typing))
                pagenum_typing=""
                pagenum_istyping=false
                redraw()
            end
        end
        if tEvent[1]=="timer" and tEvent[2]==drawClock_timer then
            drawClock()
            drawClock_timer=os.startTimer(1)
        end
        if tEvent[1]=="cctt_redraw" then
            redraw()
        end
    end
end
local found=false
peripheral.find("modem",function(n) rednet.open(n) found=true end)
if not found then error"requires modem" end
server_id=tonumber(server_id) or rednet.lookup("cctt",server_id) or error"invalid server ID/hostname"
parallel.waitForAny(mainloop,comms)
rednet.close()
term.clear()
term.setCursorPos(1,1)
