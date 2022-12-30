fs.makeDir"lib"
if not package.path:find("/lib/?") then package.path=package.path..";/lib/?;/lib/?.lua;/lib/?/init.lua" end

if not pcall(require,"cbor") then
    if not http then
        error"Requires CBOR library (not found, cannot download (no HTTP))\n\nDownload a copy from https://github.com/MineRobber9000/cctt/raw/main/lib/cbor.lua and place it in the lib/ directory."
    end
    local h=http.get"https://github.com/MineRobber9000/cctt/raw/main/lib/cbor.lua"
    local f=fs.open("lib/cbor.lua","w")
    f.write(h.readAll())
    f.close()
    h.close()
    require"cbor"
end
local cbor=package.loaded.cbor

local expect=require("cc.expect").expect

local function mt_type(o)
    if type(o)=="table" then
        local mt=getmetatable(o)
        if mt and mt.__type then
            if mt_type(mt.__type)=="function" then
                return mt.__type(o)
            else
                return mt.__type
            end
        end
    end
    return io.type(o) or type(o)
end
for i=1,debug.getinfo(expect,"u").nups do
    if debug.getupvalue(expect,i)=="native_type" then
        debug.setupvalue(expect,i,mt_type)
    end
end

local function strw(s,w,c)
    c=c or " "
    return (s..c:rep(w)):sub(1,w)
end

local frame__mt = {}
local frame_methods = {}
frame__mt.__index=function(t,k)
    if k==1 or k==2 or k==3 then
        t[k]=0
        return t[k]
    end
    if k==4 then
        t[k]=strw("",8)
        return t[k]
    end
    if k==5 or k==6 then
        t[k]={}
        return t[k]
    end
    return frame_methods[k]
end
frame__mt.__type="frame"

function frame_methods.page_number(frame)
    expect(1,frame,"frame")
    return frame[1]
end

function frame_methods.set_page_number(frame,num)
    expect(1,frame,"frame")
    expect(2,num,"number")
    assert(num>=0 and num<=999999,"bad argument #2 to set_page_number (number out of range)")
    frame[1]=num
end

function frame_methods.size(frame)
    expect(1,frame,"frame")
    return frame[2], frame[3]
end

function frame_methods.set_size(frame,width,height)
    expect(1,frame,"frame")
    expect(2,width,"number")
    expect(3,height,"number")
    assert(width>0 and height>0, "invalid size")
    frame[2]=width
    frame[3]=height
    for i=1,height do
        i=((i-1)*3)+1
        frame[5][i]=strw(frame[5][i] or "",width)
        frame[5][i+1]=strw(frame[5][i+1] or "",width,"0")
        frame[5][i+2]=strw(frame[5][i+2] or "",width,"f")
    end
end

function frame_methods.header(frame)
    expect(1,frame,"frame")
    return frame[4]
end

function frame_methods.set_header(frame,header)
    expect(1,frame,"frame")
    expect(2,header,"string")
    frame[4]=strw(header,8)
end

function frame_methods.add_palette_color(frame,color,rgb)
    expect(1,frame,"frame")
    expect(2,color,"number")
    expect(3,rgb,"number")
    if rgb==colors.packRGB(term.nativePaletteColor(color)) then
        for i=1,#frame[6] do
            if frame[6][i][1]==color then
                table.remove(frame[6],i)
                return
            end
        end
        return
    end
    for i=1,#frame[6] do
        local entry=frame[6][i]
        if entry[1]==color then
            entry[2]=rgb
            return
        end
    end
    frame[6][#frame[6]+1]={color,number}
end

function frame_methods.get_palette_color(frame,color)
    expect(1,frame,"frame")
    expect(2,color,"number")
    for i=1,#frame[6] do
        local entry=frame[6][i]
        if entry[1]==color then
            return colors.unpackRGB(entry[2])
        end
    end
    return term.nativePaletteColor(color)
end

local colorConversion={}
for i=0,15 do
    colorConversion[("%x"):format(i)]=2^i
    colorConversion[2^i]=("%x"):format(i)
end

function frame_methods.redirect_target(frame)
    expect(1,frame,"frame")
    local cursorX,cursorY,foregroundColor,backgroundColor=1,1,"0","f"
    local redirect={}
    function redirect.getCursorPos()
        return cursorX, cursorY
    end
    function redirect.setCursorPos(x,y)
        expect(1,x,"number")
        expect(2,y,"number")
        cursorX, cursorY = math.floor(x), math.floor(y)
    end
    local sub=string.sub
    local function _blit(text,fore,back)
        local _start=cursorX
        local _end=_start+#text-1
        local index=((cursorY-1)*3)+1
        if cursorY>=1 and cursorY<=frame[3] then
            if _start<=frame[2] and _end>=1 then
                if _start==1 and _end==frame[2] then
                    frame[5][index]=text
                    frame[5][index+1]=fore
                    frame[5][index+2]=back
                else
                    local clippedText,clippedFore,clippedBack=text,fore,back
                    if _start<1 then
                        local clipStart=1-_start+1
                        clippedText=sub(clippedText,clipStart)
                        clippedFore=sub(clippedFore,clipStart)
                        clippedBack=sub(clippedBack,clipStart)
                    end
                    if _end>frame[2] then
                        local clipEnd=frame[2]-_start+1
                        clippedText=sub(clippedText,1,clipEnd)
                        clippedFore=sub(clippedFore,1,clipEnd)
                        clippedBack=sub(clippedBack,1,clipEnd)
                    end
                    local oldText, oldFore, oldBack = frame[5][index], frame[5][index+1], frame[5][index+2]
                    local newText, newFore, newBack = clippedText, clippedFore, clippedBack
                    if _start>1 then
                        local old_end = _start-1
                        newText=sub(oldText,1,old_end)..newText
                        newFore=sub(oldFore,1,old_end)..newFore
                        newBack=sub(oldBack,1,old_end)..newBack
                    end
                    if _end<frame[2] then
                        local old_start = _end+1
                        newText=newText..sub(oldText,old_start,frame[2])
                        newFore=newFore..sub(oldFore,old_start,frame[2])
                        newBack=newBack..sub(oldBack,old_start,frame[2])
                    end
                    frame[5][index]=newText
                    frame[5][index+1]=newFore
                    frame[5][index+2]=newBack
                end
            end
        end
        cursorX=_end+1
    end
    function redirect.write(text)
        text=tostring(text)
        _blit(text,foregroundColor:rep(#text),backgroundColor:rep(#text))
    end
    function redirect.blit(text,fore,back)
        expect(1,text,"string")
        expect(2,fore,"string")
        expect(3,back,"string")
        if #text~=#fore or #text~=#back then
            error("Arguments must be the same length",2)
        end
        _blit(text,fore:lower(),back:lower())
    end
    function redirect.clear()
        for y=1,frame[3] do
            local index=((y-1)*3)+1
            frame[5][index]=(" "):rep(frame[2])
            frame[5][index+1]=foregroundColor:rep(frame[2])
            frame[5][index+2]=backgroundColor:rep(frame[2])
        end
    end
    function redirect.clearLine()
        local index=((cursorY-1)*3)+1
        frame[5][index]=(" "):rep(frame[2])
        frame[5][index+1]=foregroundColor:rep(frame[2])
        frame[5][index+2]=backgroundColor:rep(frame[3])
    end
    function redirect.getCursorBlink()
        return false
    end
    function redirect.setCursorBlink(blink)
        -- we don't support cursor blink
    end
    redirect.isColor=function() return true end
    redirect.isColour=function() return true end
    redirect.setTextColor=function(color)
        expect(1,color,"number")
        if not colorConversion[color] then
            error("invalid color (got "..color..")",2)
        end
        foregroundColor=colorConversion[color]
    end
    redirect.setTextColour=redirect.setTextColor
    redirect.setBackgroundColor=function(color)
        expect(1,color,"number")
        if not colorConversion[color] then
            error("invalid color (got "..color..")",2)
        end
        backgroundColor=colorConversion[color]
    end
    redirect.setBackgroundColour=redirect.setBackgroundColor
    redirect.setPaletteColor=function(color,r,g,b)
        expect(1,color,"number")
        if not colorConversion[color] then
            error("invalid color (got "..color..")",2)
        end
        if type(r)=="number" and not g and not b then
            frame:add_palette_color(color,r)
        else
            expect(2,r,"number")
            expect(3,g,"number")
            expect(4,b,"number")
            redirect.setPaletteColor(color,colors.packRGB(r,g,b))
        end
    end
    redirect.setPaletteColour=redirect.setPaletteColor
    redirect.getPaletteColor=function(color)
        expect(1,color,"number")
        if not colorConversion[color] then
            error("invalid color (got "..color..")",2)
        end
        return frame:get_palette_color(color)
    end
    redirect.getPaletteColour=redirect.getPaletteColor
    redirect.getTextColor=function()
        return colorConversion[foregroundColor]
    end
    redirect.getTextColour=redirect.getTextColor
    redirect.getBackgroundColor=function()
        return colorConversion[backgroundColor]
    end
    redirect.getBackgroundColour=redirect.getBackgroundColor
    redirect.scroll=function(n)
        -- crazy, we don't support scroll either
    end
    redirect.getSize=function()
        return frame:size()
    end
    return redirect
end

function frame_methods.apply_palette(frame)
    expect(1,frame,"frame")
    for i=1,#frame[6] do
        local entry=frame[6][i]
        term.setPaletteColor(table.unpack(entry))
    end
end

function frame_methods.draw(frame,x,y)
    expect(1,frame,"frame")
    expect(2,x,"number","nil")
    expect(3,y,"number","nil")
    x = x or 1
    y = y or 1
    for i=1,frame[3] do
        local _y=y+i-1
        local index=((i-1)*3)+1
        term.setCursorPos(x,_y)
        term.blit(frame[5][index],frame[5][index+1],frame[5][index+2])
    end
end

frame__mt.__tocbor=function(o)
    local tbl={}
    local i=1
    while o[i] do
        tbl[i]=o[i]
        i=i+1
    end
    return cbor.encode(tbl)
end
function frame_methods.encode(frame)
    expect(1,frame,"frame")
    return cbor.encode(frame)
end

function frame__mt.__tostring(frame)
    local tmp=getmetatable(frame)
    setmetatable(frame,nil)
    local ret=tostring(frame):gsub("^table:","frame:")
    setmetatable(frame,tmp)
    return ret
end

function frame__mt.__eq(lhs,rhs)
    if lhs[1]~=rhs[1] then return false end
    if lhs[2]~=rhs[2] then return false end
    if lhs[3]~=rhs[3] then return false end
    if lhs[4]~=rhs[4] then return false end
    if #lhs[5]~=#rhs[5] then return false end
    for i=1,#lhs[5] do
        if lhs[5][i]~=rhs[5][i] then return false end
    end
    if #lhs[6]~=#rhs[6] then return false end
    for i=1,#lhs[6] do
        local lhs_entry=lhs[6][i]
        local rhs_entry=rhs[6][i]
        if lhs_entry[1]~=rhs_entry[1] or lhs_entry[2]~=rhs_entry[2] then
            return false
        end
    end
    return true
end

local function new_frame(width,height)
    expect(1,width,"number")
    expect(2,height,"number")
    local frame=setmetatable({},frame__mt)
    frame:set_size(width,height)
    return frame
end

local function load_frame(s)
    return setmetatable(cbor.decode(s),frame__mt)
end

return {
    new_frame=new_frame,
    load_frame=load_frame
}
