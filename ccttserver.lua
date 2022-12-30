if not fs.exists("etc/ccttserver.d") then
    fs.makeDir("etc/ccttserver.d")
    print("Place files in etc/ccttserver.d.")
    print("CCTT files (*.cctt) will be read.")
    print("Lua files (*.lua) will be executed.")
    error(nil,0)
end

fs.makeDir("lib")
if not package.path:find("/lib/?") then
    package.path=package.path..";/lib/?;/lib/?.lua;/lib/?/init.lua"
end
cctt=require"cctt"

hostname=...
local lpages
local function load_pages()
    pages={}
    local ccttserverd=fs.list("etc/ccttserver.d")
    table.sort(ccttserverd)
    for i=1,#ccttserverd do
        local item=ccttserverd[i]
        if item:match("^.*%.cctt$") then
            local h=assert(fs.open(fs.combine("etc/ccttserver.d",item),"rb"))
            local ok,frame=pcall(cctt.load_frame,h.readAll())
            h.close()
            assert(ok,frame)
            if frame:header()=="        " and hostname then
                frame:set_header(hostname:upper())
            end
            pages[frame:page_number()]=function() return frame:encode() end
        elseif item:match("^.*%.lua$") then
            local h=assert(fs.open(fs.combine("etc/ccttserver.d",item),"r"))
            local code=h.readAll()
            h.close()
            local f=assert(load(code,"="..item,"t",_ENV))
            assert(xpcall(f,debug.traceback))
        end
    end
    lpages={}
    for k,v in pairs(pages) do
        lpages[#lpages+1]=k
    end
    table.sort(lpages)
end
load_pages()
local function draw()
    term.clear()
    term.setCursorPos(1,1)
    print(string.format("Serving %d page(s)",#lpages))
    print("Press q to quit")--, press r to reload")
    for i=1,#lpages do
        print(lpages[i])
    end
end
draw()
local function mainloop()
    local ipages=1
    local serve_timer=os.startTimer(1)
    while true do
        local tEvent={os.pullEventRaw()}
        if tEvent[1]=="terminate" then return end
        if tEvent[1]=="char" then
            if tEvent[2]:lower()=="q" then return end
            --if tEvent[2]:lower()=="r" then load_pages() draw() end
        end
        if tEvent[1]=="timer" and tEvent[2]==serve_timer then
            local end_point=math.min(#lpages,ipages+4)
            while ipages<=end_point do
                rednet.broadcast(
                    pages[lpages[ipages]]()
                ,"cctt")
                ipages=ipages+1
            end
            if ipages>#lpages then ipages=1 end
            serve_timer=os.startTimer(1)
        end
    end
end
if not rednet then error"requires rednet" end
local found=false
peripheral.find("modem",function(n) rednet.open(n) found=true end)
if not found then error"requires a modem" end
if hostname then rednet.host(hostname,"cctt") end
parallel.waitForAny(mainloop)
rednet.unhost("cctt")
rednet.close()
