fs.makeDir"lib"
if not package.path:find("/lib/?") then
    package.path=package.path..";/lib/?;/lib/?.lua;/lib/?/init.lua"
end

local cctt=require"cctt"

local path=...
if not path then
    print("Usage: cctteditor <path>")
    error(nil,0)
end
local fullPath=shell.resolve(path)
if not fs.exists(fullPath) and not string.find(path,"%.") then
    path=path..".cctt"
end
path=fullPath

local frame=nil
if fs.exists(path) then
    local h=fs.open(path,"rb")
    frame=cctt.load_frame(h.readAll())
    h.close()
else
    write("Page width: ")
    local width=tonumber(read()) or error"invalid width"
    write("Page height: ")
    local height=tonumber(read()) or error"invalid height"
    frame=cctt.new_frame(width,height)
end

local red=frame:redirect_target()

local arrow_key={
    [keys.up]=true,
    [keys.down]=true,
    [keys.left]=true,
    [keys.right]=true
}

local w,h=term.getSize()
function redraw()
    term.setBackgroundColor(colors.gray)
    term.clear()
    term.setBackgroundColor(colors.black)
    frame:draw(1,1)
    term.setBackgroundColor(colors.gray)
    local pos=table.concat({red.getCursorPos()},", ")
    term.setCursorPos(w-#pos+1,1)
    term.write(pos)
end
local left_ctrl_down, right_ctrl_down, ctrl_down
local function ctrl()
    left_ctrl_down=false
    right_ctrl_down=false
    ctrl_down=false
    while true do
        local tEvent=table.pack(os.pullEvent())
        if tEvent[1]=="key" then
            if tEvent[2]==keys.leftCtrl then
                left_ctrl_down=true
                ctrl_down=true
            elseif tEvent[2]==keys.rightCtrl then
                right_ctrl_down=true
                ctrl_down=true
            end
        end
        if tEvent[1]=="key_up" then
            if tEvent[2]==keys.leftCtrl then
                left_ctrl_down=false
            elseif tEvent[2]==keys.rightCtrl then
                right_ctrl_down=false
            end
            ctrl_down=left_ctrl_down or right_ctrl_down
        end
    end
end
local function mainloop()
    local fw, fh = frame:size()
    redraw()
    while true do
        local tEvent=table.pack(os.pullEvent())
        if tEvent[1]=="char" then
            red.write(tEvent[2])
            local x,y=red.getCursorPos()
            if x>fw then
                x=x-fw
                y=y+1
                if y>fh then
                    y=y-fh
                end
                red.setCursorPos(x,y)
            end
            redraw()
        end
        if tEvent[1]=="key" then
            if tEvent[2]==keys.backspace then
                local x,y=red.getCursorPos()
                x=x-1
                if x==0 then
                    x=fw
                    y=y-1
                    if y==0 then
                        y=fh
                    end
                end
                red.setCursorPos(x,y)
                red.write(" ")
                red.setCursorPos(x,y)
                redraw()
            elseif ctrl_down then
                if tEvent[2]==keys.q then
                    return
                end
                if tEvent[2]==keys.s then
                    local h=fs.open(path,"wb")
                    h.write(frame:encode())
                    h.close()
                end
                if tEvent[2]==keys.p then
                    term.setCursorPos(41,2)
                    write("Page#:")
                    frame:set_page_number(tonumber(read()) or frame:page_number())
                    redraw()
                end
                if tEvent[2]==keys.h then
                    term.setCursorPos(1,h)
                    term.clearLine()
                    write("Header: ")
                    frame:set_header(read())
                    redraw()
                end
            else
                if arrow_key[tEvent[2]] then
                    local x,y=red.getCursorPos()
                    if tEvent[2]==keys.up then
                        y=y-1
                    elseif tEvent[2]==keys.down then
                        y=y+1
                    elseif tEvent[2]==keys.left then
                        x=x-1
                    elseif tEvent[2]==keys.right then
                        x=x+1
                    end
                    if x==0 then
                        x=fw
                        y=y-1
                    end
                    if x>fw then
                        x=x-fw
                        y=y+1
                    end
                    if y==0 then
                        y=fh
                    end
                    if y>fh then
                        y=y-fh
                    end
                    red.setCursorPos(x,y)
                    redraw()
                end
                if tEvent[2]==keys.enter then
                    local x,y=red.getCursorPos()
                    x=1
                    y=y+1
                    if y>fh then y=y-fh end
                    red.setCursorPos(x,y)
                    redraw()
                end
            end
        end
    end
end
parallel.waitForAny(mainloop,ctrl)
rednet.close()
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1,1)
