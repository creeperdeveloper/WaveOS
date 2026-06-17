local W,H=term.getSize()
local NATIVE_TERM=term.current()
local REAL_REQUIRE=require
local S={
  screen="boot",accounts={},user="",pw="",theme=colors.blue,bg=1,
  setup=false,apps={},notifs={},windows={},nextId=1,volume=70,
  start=false,notifPanel=false,volPanel=false,sleeping=false,
  search="",spin=0,clockfmt="24h",dragWin=nil,running=true,
  loginUser="",loginPw="",loginErr=false,loginBusy=false,
}

local DATA="/.waveos_data"
local function saveData()
  local f=fs.open(DATA,"w")
  if not f then return end
  f.write(textutils.serialize({
    accounts=S.accounts,theme=S.theme,bg=S.bg,setup=S.setup,
    apps=S.apps,clockfmt=S.clockfmt,volume=S.volume,
  }))
  f.close()
end
local function loadData()
  if not fs.exists(DATA) then return end
  local f=fs.open(DATA,"r")
  if not f then return end
  local d=textutils.unserialize(f.readAll())
  f.close()
  if type(d)~="table" then return end
  for k,v in pairs(d) do S[k]=v end
end

local function hashpw(p)
  local h=5381
  for i=1,#p do h=((h*33)+string.byte(p,i))%16777216 end
  return string.format("%06x",h)
end

local function pset(x,y,c) if x>=1 and x<=W and y>=1 and y<=H then paintutils.drawPixel(x,y,c) end end
local function hline(x1,x2,y,c) if y>=1 and y<=H then paintutils.drawLine(math.max(1,x1),y,math.min(W,x2),y,c) end end
local function vline(x,y1,y2,c) if x>=1 and x<=W then paintutils.drawLine(x,math.max(1,y1),x,math.min(H,y2),c) end end
local function box(x1,y1,x2,y2,c)
  x1=math.max(1,x1) y1=math.max(1,y1) x2=math.min(W,x2) y2=math.min(H,y2)
  if x2>=x1 and y2>=y1 then paintutils.drawFilledBox(x1,y1,x2,y2,c) end
end
local function rect(x1,y1,x2,y2,c)
  hline(x1,x2,y1,c) hline(x1,x2,y2,c) vline(x1,y1,y2,c) vline(x2,y1,y2,c)
end
local function wp(x,y,s,fg,bg)
  if y<1 or y>H then return end
  if x<1 then s=s:sub(2-x) x=1 end
  if x+#s-1>W then s=s:sub(1,W-x+1) end
  if #s==0 then return end
  term.setCursorPos(x,y) term.setTextColor(fg) term.setBackgroundColor(bg) term.write(s)
end

local redrawDesktop

local function slideInNotifCard(title,msg,kind)
  if S.screen~="desktop" then return end
  local prevTerm=term.current()
  term.redirect(NATIVE_TERM)
  local cardW=24 local cardH=3 local cardY=2
  local restX=W-cardW-1
  local border=colors.lightGray
  if kind=="warn" then border=colors.orange end
  if kind=="error" then border=colors.red end
  local x=W+2
  while x>restX do
    x=math.max(restX,x-3)
    box(x,cardY,x+cardW-1,cardY+cardH-1,colors.gray)
    rect(x,cardY,x+cardW-1,cardY+cardH-1,border)
    wp(x+1,cardY,(title or ""):sub(1,cardW-2),colors.white,colors.gray)
    wp(x+1,cardY+1,(msg or ""):sub(1,cardW-2),colors.lightGray,colors.gray)
    sleep(0.03)
  end
  sleep(0.9)
  if redrawDesktop then redrawDesktop() end
  term.redirect(prevTerm)
end

local function notify(title,msg,kind)
  table.insert(S.notifs,1,{title=title,msg=msg or "",kind=kind})
  if #S.notifs>20 then table.remove(S.notifs) end
  slideInNotifCard(title,msg,kind)
end

local function getClock()
  local ep=os.epoch("utc")+9*3600000
  local sec=math.floor(ep/1000)%86400
  local hh=math.floor(sec/3600)
  local mm=math.floor((sec%3600)/60)
  local ss=sec%60
  if S.clockfmt=="12h" then
    local ampm=hh>=12 and "PM" or "AM"
    hh=hh%12 if hh==0 then hh=12 end
    return string.format("%d:%02d %s",hh,mm,ampm)
  end
  return string.format("%02d:%02d:%02d",hh,mm,ss)
end
local function getDate()
  local ep=os.epoch("utc")+9*3600000
  local sec=math.floor(ep/1000)
  local days=math.floor(sec/86400)+719468
  local era=math.floor((days>=0 and days or days-146096)/146097)
  local doe=days-era*146097
  local yoe=math.floor((doe-math.floor(doe/1460)+math.floor(doe/36524)-math.floor(doe/146096))/365)
  local y=yoe+era*400
  local doy=doe-math.floor((365*yoe+math.floor(yoe/4)-math.floor(yoe/100)))
  local mp=math.floor((5*doy+2)/153)
  local d=doy-math.floor((153*mp+2)/5)+1
  local m=mp<10 and mp+3 or mp-9
  if m<=2 then y=y+1 end
  return string.format("%04d/%02d/%02d",y,m,d)
end

local function hasInternet()
  return peripheral.find("modem",function(_,m) return m.isWireless and m.isWireless() end)~=nil
end

local ACCENT={
  {colors.blue,"Blue"},{colors.cyan,"Cyan"},{colors.purple,"Purple"},
  {colors.red,"Red"},{colors.green,"Green"},{colors.orange,"Orange"},
}

local function drawBackground()
  if S.bg==1 then
    for y=1,H-1 do
      local c=colors.blue
      if y<=math.floor((H-1)*0.4) then c=colors.cyan
      elseif y<=math.floor((H-1)*0.75) then c=colors.lightBlue
      else c=colors.blue end
      hline(1,W,y,c)
    end
    for x=2,W-2,4 do pset(x,2,colors.white) pset(x+1,2,colors.white) end
  elseif S.bg==2 then
    for y=1,H-1 do
      local c
      if y<=math.floor((H-1)*0.6) then c=colors.lightBlue else c=colors.cyan end
      hline(1,W,y,c)
    end
    local clouds={{4,2},{14,3},{W-10,2},{W-20,4}}
    for _,cl in ipairs(clouds) do
      local cx,cy=cl[1],cl[2]
      box(cx,cy,cx+5,cy,colors.white)
      box(cx+1,cy-1,cx+4,cy-1,colors.white)
      box(cx+2,cy+1,cx+7,cy+1,colors.white)
    end
  elseif S.bg==3 then
    local seaY=math.floor((H-1)*0.55)
    local groundY=math.floor((H-1)*0.8)
    for y=1,seaY-1 do hline(1,W,y,colors.lightBlue) end
    for y=seaY,groundY-1 do hline(1,W,y,colors.blue) end
    for y=groundY,H-1 do hline(1,W,y,colors.green) end
    for x=1,W,5 do pset(x,seaY,colors.cyan) pset(x+1,seaY,colors.cyan) end
    local sx,sy=W-6,2
    box(sx,sy,sx+2,sy+2,colors.yellow)
  end
  wp(2,1,"WaveOS",colors.white,S.bg==1 and colors.cyan or (S.bg==3 and colors.lightBlue or colors.lightBlue))
end

local TASKBAR_H=3
local function taskbarY() return H-TASKBAR_H+1 end

local function drawDesktopIcons()
  local cellW,cellH=7,4
  local startX,startY=2,3
  S.deskIcons={}
  local col,row=0,0
  for _,app in ipairs(S.apps) do
    local ix=startX+col*cellW
    local iy=startY+row*cellH
    if iy+2<=taskbarY()-1 then
      box(ix,iy,ix+4,iy+2,colors.white)
      wp(ix+2,iy+1,(app.icon or "\183"),colors.black,colors.white)
      wp(ix,iy+3,app.name:sub(1,cellW-1),colors.white,colors.blue)
      table.insert(S.deskIcons,{x1=ix,y1=iy,x2=ix+4,y2=iy+3,app=app})
      row=row+1
      if startY+row*cellH+2>taskbarY()-1 then row=0 col=col+1 end
    end
  end
end



local function drawMenuIcon(x,y)
  for i=0,2 do hline(x,x+4,y+i,colors.white) end
end

local function drawTaskbar()
  local ty=taskbarY()
  box(1,ty,W,H,colors.gray)
  hline(1,W,ty,colors.lightGray)
  box(2,ty+1,7,H-1,S.start and S.theme or colors.gray)
  drawMenuIcon(3,ty+2)

  local x=10
  for _,win in ipairs(S.windows) do
    local label=win.title:sub(1,8)
    local wbg=win.minimized and colors.gray or colors.lightGray
    if win.focused then wbg=S.theme end
    box(x,ty+1,x+10,H-1,wbg)
    wp(x+1,ty+2,(win.icon or "\183").." "..label,colors.white,wbg)
    win.taskX1=x win.taskX2=x+10
    x=x+12
  end

  local net=hasInternet()
  local netc=net and colors.white or colors.red
  wp(W-16,ty+2,"\183",netc,colors.gray)

  local volIcon=S.volume==0 and "\215" or (S.volume<50 and "\148" or "\149")
  wp(W-13,ty+2,volIcon,colors.white,colors.gray)

  local uc=#S.notifs
  wp(W-10,ty+2,uc>0 and ("\7"..uc) or "\7",uc>0 and colors.yellow or colors.lightGray,colors.gray)

  local clk=getClock()
  local dat=getDate()
  local cw=math.max(#clk,#dat)
  wp(W-cw,ty+1,clk,colors.white,colors.gray)
  wp(W-cw,ty+2,dat,colors.lightGray,colors.gray)
end

local MIN_W,MIN_H=16,6

local function findWin(id)
  for _,w in ipairs(S.windows) do if w.id==id then return w end end
end

local function focusWindow(win)
  for _,w in ipairs(S.windows) do w.focused=(w==win) end
  for i,w in ipairs(S.windows) do
    if w==win then table.remove(S.windows,i) table.insert(S.windows,w) break end
  end
end

local function closeWindow(win)
  for i,w in ipairs(S.windows) do
    if w==win then table.remove(S.windows,i) break end
  end
end

local function updateWinGeometry(win)
  local x,y,w,h=win.x,win.y,win.w,win.h
  win.closeBtn={x+w-3,x+w-2,y} win.minBtn={x+w-6,x+w-5,y}
  win.titleBar={x,x+w-7,y}
  win.resizeHandle={x+w-2,x+w-1,y+h-2,y+h-1}
  win.contentArea={x+1,y+1,x+w-1,y+h-1}
end

local function createWindow(title,icon,w,h,renderFn,clickFn,charFn,keyFn,onClose)
  w=w or 30 h=h or 12
  local x=math.floor((W-w)/2)+math.random(-2,2)
  local y=math.floor((H-TASKBAR_H-h)/2)
  x=math.max(1,math.min(W-w+1,x)) y=math.max(1,math.min(H-TASKBAR_H-h+1,y))
  local win={
    id=S.nextId,title=title,icon=icon or "\183",x=x,y=y,w=w,h=h,
    minimized=false,focused=true,render=renderFn,onClick=clickFn,
    onChar=charFn,onKey=keyFn,onClose=onClose,data={},
  }
  S.nextId=S.nextId+1
  for _,ow in ipairs(S.windows) do ow.focused=false end
  table.insert(S.windows,win)
  updateWinGeometry(win)
  return win
end

local function clampWin(win)
  win.w=math.max(MIN_W,win.w) win.h=math.max(MIN_H,win.h)
  win.x=math.max(1,math.min(W-win.w+1,win.x))
  win.y=math.max(1,math.min(H-TASKBAR_H-win.h+1,win.y))
  updateWinGeometry(win)
  if win.surface then win.surface.reposition(win.x+1,win.y+1,win.w-1,win.h-1) end
end

local function drawWindowFrame(win)
  local x,y,w,h=win.x,win.y,win.w,win.h
  box(x,y,x+w-1,y+h-1,colors.white)
  local tbg=win.focused and S.theme or colors.lightGray
  box(x,y,x+w-1,y,tbg)
  wp(x+1,y,(win.icon or "\183").." "..win.title:sub(1,w-7),colors.white,tbg)
  wp(x+w-3,y,"\215",colors.white,tbg)
  wp(x+w-6,y,"\176",colors.white,tbg)
  rect(x+w-2,y+h-2,x+w-1,y+h-1,colors.gray)
  updateWinGeometry(win)
end

local function drawWindows()
  for _,win in ipairs(S.windows) do
    if not win.minimized then
      drawWindowFrame(win)
      if win.render then win.render(win) end
      if win.surface then win.surface.redraw() end
    end
  end
end

local function drawStartMenu()
  local mw=math.min(40,W-2) local mh=math.min(20,H-TASKBAR_H-1)
  local mx=math.floor((W-mw)/2) local my=H-TASKBAR_H-mh
  box(mx,my,mx+mw-1,my+mh-1,colors.gray)
  rect(mx,my,mx+mw-1,my+mh-1,colors.lightGray)
  hline(mx,mx+mw-1,my,colors.lightGray)
  box(mx+1,my+1,mx+mw-2,my+1,colors.white)
  wp(mx+2,my+1,"Search apps",colors.gray,colors.white)
  if S.search~="" then wp(mx+2,my+1,S.search:sub(1,mw-4),colors.black,colors.white) end
  S.startSearchBox={mx+1,mx+mw-2,my+1}

  local items={}
  local q=S.search:lower()
  for _,a in ipairs(S.apps) do
    if q=="" or a.name:lower():find(q,1,true) then table.insert(items,a) end
  end

  local cols=3
  local cellW=math.floor((mw-4)/cols)
  local startY=my+3
  wp(mx+2,startY,"Apps",colors.white,colors.gray)
  S.startItems={}
  for i,app in ipairs(items) do
    local col=(i-1)%cols
    local row=math.floor((i-1)/cols)
    local ix=mx+2+col*cellW
    local iy=startY+1+row*4
    if iy+2<my+mh-2 then
      box(ix,iy,ix+4,iy+2,colors.lightGray)
      wp(ix+2,iy+1,(app.icon or "\183"),colors.black,colors.lightGray)
      wp(ix,iy+3,app.name:sub(1,cellW-1),colors.white,colors.gray)
      table.insert(S.startItems,{x1=ix,y1=iy,x2=ix+4,y2=iy+3,app=app})
    end
  end

  local py=my+mh-2
  hline(mx,mx+mw-1,py,colors.lightGray)
  wp(mx+2,py+1,"\30 "..(S.user or "User"),colors.white,colors.gray)
  box(mx+mw-12,py+1,mx+mw-10,py+1,colors.lightGray)
  wp(mx+mw-12,py+1,"\7",colors.black,colors.lightGray)
  box(mx+mw-9,py+1,mx+mw-7,py+1,colors.lightGray)
  wp(mx+mw-9,py+1,"\187",colors.black,colors.lightGray)
  box(mx+mw-6,py+1,mx+mw-4,py+1,colors.lightGray)
  wp(mx+mw-6,py+1,"\17",colors.black,colors.lightGray)
  S.powerBtns={
    sleep={mx+mw-12,mx+mw-10,py+1},
    restart={mx+mw-9,mx+mw-7,py+1},
    shutdown={mx+mw-6,mx+mw-4,py+1},
  }
  S.startBounds={mx,my,mw,mh}
end

local function drawVolumePanel()
  local pw,ph=20,7
  local px=W-pw-1 local py=taskbarY()-ph
  box(px,py,px+pw-1,py+ph-1,colors.gray)
  rect(px,py,px+pw-1,py+ph-1,colors.lightGray)
  wp(px+1,py+1,"Volume "..S.volume.."%",colors.white,colors.gray)
  local barY=py+3
  hline(px+1,px+pw-2,barY,colors.lightGray)
  local fillW=math.floor((pw-2)*S.volume/100)
  if fillW>0 then hline(px+1,px+fillW,barY,S.theme) end
  local handleX=px+1+fillW
  if S.volume>=100 then handleX=px+pw-2 end
  pset(handleX,barY,colors.white)
  S.volBar={px+1,px+pw-2,barY}
  wp(px+1,py+5,S.volume==0 and "Muted" or "Adjust by dragging",colors.lightGray,colors.gray)
  S.volBounds={px,py,pw,ph}
end

local function drawNotifPanel()
  local nw=24 local nx=W-nw+1 local ny=1 local nh=H-TASKBAR_H
  box(nx,ny,W,ny+nh-1,colors.gray)
  rect(nx,ny,W,ny+nh-1,colors.lightGray)
  hline(nx,W,ny,colors.lightGray)
  wp(nx+1,ny,"Notifications",colors.white,colors.gray)
  wp(W-2,ny,"\215",colors.white,colors.gray)
  if #S.notifs==0 then
    wp(nx+2,ny+2,"No new notifications",colors.lightGray,colors.gray)
  else
    for i,n in ipairs(S.notifs) do
      local iy=ny+1+(i-1)*3
      if iy+1<ny+nh-1 then
        box(nx+1,iy,W-1,iy+1,colors.lightGray)
        wp(nx+2,iy,n.title:sub(1,nw-4),colors.black,colors.lightGray)
        wp(nx+2,iy+1,n.msg:sub(1,nw-4),colors.gray,colors.lightGray)
      end
    end
  end
  wp(nx+1,ny+nh-1,"Clear all",S.theme,colors.gray)
  S.notifBounds={nx,ny,nw,nh}
end

local SPIN={"\183","\184","\185","\186"}

local function drawBoot()
  box(1,1,W,H,colors.black)
  local cy=math.floor(H/2)-1
  wp(math.floor((W-6)/2),cy,"WaveOS",colors.lightBlue,colors.black)
  local bw=math.floor(W*0.5) local bx=math.floor((W-bw)/2)
  box(bx,cy+2,bx+bw-1,cy+2,colors.gray)
  for i=1,bw do
    box(bx,cy+2,bx+i-1,cy+2,colors.lightBlue)
    if i%4==0 then sleep(0.03) end
  end
  sleep(0.2)
end

local function drawSleep()
  box(1,1,W,H,colors.black)
  local msg="Click to wake"
  wp(math.floor((W-#msg)/2),math.floor(H/2),msg,colors.white,colors.black)
end

local function showBlueScreen(appName,errMsg)
  box(1,1,W,H,colors.blue)
  local lines={
    ":(",
    "",
    "An app stopped working and WaveOS needs to restart.",
    "",
    "App: "..tostring(appName),
    "Error: "..tostring(errMsg),
    "",
    "Restarting in 10 seconds...",
  }
  local cy=math.floor(H/2)-#lines
  for i,l in ipairs(lines) do
    wp(3,cy+i,l:sub(1,W-4),colors.white,colors.blue)
  end
  for i=10,1,-1 do
    wp(3,cy+#lines+2,"Restarting in "..i.." seconds... ",colors.white,colors.blue)
    sleep(1)
  end
  saveData()
  os.reboot()
end

local function drawLoginScreen()
  box(1,1,W,H,colors.blue)
  for y=1,math.floor(H*0.5) do hline(1,W,y,colors.lightBlue) end
  wp(2,1,"WaveOS",colors.white,colors.lightBlue)
  local cx=math.floor(W/2)
  local cy=math.floor(H*0.25)
  box(cx-2,cy-1,cx+2,cy+1,colors.white)
  wp(cx,cy,"\30",colors.blue,colors.white)

  local names={}
  for name,_ in pairs(S.accounts) do table.insert(names,name) end
  table.sort(names)
  if S.loginUser=="" and names[1] then S.loginUser=names[1] end

  wp(cx-math.floor(#S.loginUser/2),cy+2,S.loginUser,colors.white,colors.blue)

  local fw=18 local fx=cx-math.floor(fw/2)
  local fy=cy+4
  box(fx,fy,fx+fw-1,fy,colors.white)
  local disp=string.rep("\7",#S.loginPw)
  if #disp>fw-2 then disp=disp:sub(#disp-fw+3) end
  wp(fx+1,fy,disp,colors.black,colors.white)
  S.loginPwBox={fx,fx+fw-1,fy}

  if S.loginBusy then
    S.spin=(S.spin%4)+1
    wp(cx,fy+2,SPIN[S.spin],colors.white,colors.blue)
  else
    box(fx,fy+2,fx+fw-1,fy+2,S.theme)
    wp(fx+math.floor((fw-6)/2),fy+2,"Sign in",colors.white,S.theme)
    S.loginBtn={fx,fx+fw-1,fy+2}
  end

  if S.loginErr then
    wp(fx,fy+4,"Incorrect password",colors.red,colors.blue)
  end

  if #names>1 then
    wp(fx,fy+6,"< Switch user >",colors.lightBlue,colors.blue)
    S.switchUserBtn={fx,fx+15,fy+6}
    S.accountNames=names
  end
end

local THEME_COLORS={colors.blue,colors.cyan,colors.purple,colors.red,colors.green,colors.orange}
local BG_NAMES={"Gradient","Sky & Clouds","Sea & Ground"}

local function drawSetup()
  box(1,1,W,H,colors.white)
  wp(2,1,"WaveOS",colors.gray,colors.white)
  local step=S.setupStep or 1
  box(2,3,W-1,3,colors.lightGray)
  wp(3,3,"Setup - Step "..step.."/3",colors.black,colors.lightGray)

  local cx=4 local cy=6
  if step==1 then
    wp(cx,cy,"Username",colors.gray,colors.white)
    box(cx,cy+1,cx+24,cy+1,colors.lightGray)
    wp(cx+1,cy+1,S.tmpUser or "",colors.black,colors.lightGray)
    wp(cx,cy+3,"Password",colors.gray,colors.white)
    box(cx,cy+4,cx+24,cy+4,colors.lightGray)
    wp(cx+1,cy+4,string.rep("\7",#(S.tmpPw or "")),colors.black,colors.lightGray)
    wp(cx,cy+6,"Confirm",colors.gray,colors.white)
    box(cx,cy+7,cx+24,cy+7,colors.lightGray)
    wp(cx+1,cy+7,string.rep("\7",#(S.tmpPw2 or "")),colors.black,colors.lightGray)
    if S.setupErr then wp(cx,cy+9,S.setupErr,colors.red,colors.white) end
    box(W-12,H-2,W-2,H-2,S.theme)
    wp(W-9,H-2,"Next",colors.white,S.theme)
  elseif step==2 then
    wp(cx,cy,"Theme color",colors.gray,colors.white)
    for i,c in ipairs(THEME_COLORS) do
      local bx=cx+(i-1)*4
      box(bx,cy+1,bx+2,cy+2,c)
      if c==S.theme then rect(bx,cy+1,bx+2,cy+2,colors.black) end
    end
    wp(cx,cy+4,"Background style",colors.gray,colors.white)
    for i,n in ipairs(BG_NAMES) do
      local by=cy+5+(i-1)*2
      box(cx,by,cx+2,by,S.bg==i and S.theme or colors.lightGray)
      wp(cx+4,by,n,colors.black,colors.white)
    end
    wp(cx,cy+12,"Clock format",colors.gray,colors.white)
    box(cx,cy+13,cx+6,cy+13,S.clockfmt=="24h" and S.theme or colors.lightGray)
    wp(cx+1,cy+13,"24h",colors.white,S.clockfmt=="24h" and S.theme or colors.lightGray)
    box(cx+8,cy+13,cx+14,cy+13,S.clockfmt=="12h" and S.theme or colors.lightGray)
    wp(cx+9,cy+13,"12h",colors.white,S.clockfmt=="12h" and S.theme or colors.lightGray)
    box(W-12,H-2,W-2,H-2,S.theme)
    wp(W-9,H-2,"Next",colors.white,S.theme)
  elseif step==3 then
    wp(cx,cy,"Setup complete!",colors.black,colors.white)
    wp(cx,cy+2,"Click Finish to start WaveOS.",colors.gray,colors.white)
    box(W-14,H-2,W-2,H-2,S.theme)
    wp(W-11,H-2,"Finish",colors.white,S.theme)
  end
  S.setupBtn={W-12,W-2,H-2}
  if step==3 then S.setupBtn={W-14,W-2,H-2} end
end

redrawDesktop=function()
  drawBackground()
  drawDesktopIcons()
  drawWindows()
  drawTaskbar()
  if S.start then drawStartMenu() end
  if S.volPanel then drawVolumePanel() end
  if S.notifPanel then drawNotifPanel() end
end

local function closeMenus()
  S.start=false S.notifPanel=false S.volPanel=false
end

local function setTheme(c) S.theme=c saveData() end
local function logout()
  S.screen="login" S.loginPw="" S.loginErr=false S.windows={}
  closeMenus()
end
local function shutdown() saveData() os.shutdown() end
local function restart() saveData() os.reboot() end
local function goSleep() S.sleeping=true closeMenus() end

local function listApps() return S.apps end
local function removeApp(name)
  for i,a in ipairs(S.apps) do
    if a.name==name then
      if a.protected then notify("App Manager","Cannot remove "..name) return false end
      table.remove(S.apps,i) saveData() notify("App removed",name) return true
    end
  end return false
end

local function buildAppEnv(win)
  local env=setmetatable({},{__index=_G})
  local loaded={}
  local function realRequire(name)
    local mod=REAL_REQUIRE(name)
    return mod
  end
  local function safePreload(name)
    local ok,mod=pcall(realRequire,name)
    if ok then loaded[name]=mod end
  end
  safePreload("cc.audio.dfpwm")
  safePreload("cc.expect")
  safePreload("cc.strings")
  safePreload("cc.pretty")
  safePreload("cc.shell.completion")
  safePreload("cc.completion")
  env.require=function(name)
    local cached=loaded[name]
    if cached~=nil then return cached end
    local mod=realRequire(name)
    loaded[name]=mod
    return mod
  end
  env.package={loaded=loaded,path=(package and package.path) or "?;?.lua"}
  env.term=win.surface
  env.notify=notify
  return env
end

local function runApp(app)
  local win=createWindow(app.name,app.icon,40,15,nil,nil,nil,nil,nil)
  win.surface=window.create(term.current(),win.contentArea[1],win.contentArea[2],win.w-1,win.h-1,false)
  win.app=app
  win.isAppHost=true
  win.filter=nil
  local path=app.file
  win.co=coroutine.create(function()
    local env=buildAppEnv(win)
    local fn,lerr=loadfile(path,nil,env)
    if not fn then error(lerr) end
    fn()
  end)
  win.surface.setVisible(true)
  local prev=term.redirect(win.surface)
  local ok,filterOrErr=coroutine.resume(win.co)
  term.redirect(prev)
  if not ok then
    closeWindow(win)
    redrawDesktop()
    showBlueScreen(app.name,filterOrErr)
    return
  end
  if coroutine.status(win.co)=="dead" then
    win.dead=true
  else
    win.filter=filterOrErr
  end
  redrawDesktop()
end

local function installApp(name,file,icon)
  for _,a in ipairs(S.apps) do if a.name==name then return false end end
  table.insert(S.apps,{name=name,file=file,icon=icon or "\183"})
  saveData() notify("App installed",name) return true
end

local function openFileExplorer()
  local win=createWindow("Explorer","\186",36,14)
  win.data.path="/"
  win.render=function(w)
    local x1,y1,x2,y2=w.contentArea[1],w.contentArea[2],w.contentArea[3],w.contentArea[4]
    box(x1,y1,x2,y2,colors.white)
    wp(x1+1,y1,w.data.path,colors.gray,colors.white)
    local files=fs.list(w.data.path)
    table.sort(files)
    w.data.files=files
    local row=y1+1
    if w.data.path~="/" then
      wp(x1+1,row,"\30 ..",colors.black,colors.white)
      w.data.upRow=row
      row=row+1
    end
    for _,f in ipairs(files) do
      if row>=y2 then break end
      local full=fs.combine(w.data.path,f)
      local isDir=fs.isDir(full)
      wp(x1+1,row,(isDir and "\186 " or "\184 ")..f,colors.black,colors.white)
      row=row+1
    end
  end
  win.onClick=function(w,x,y)
    local x1,y1=w.contentArea[1],w.contentArea[2]
    if w.data.upRow and y==w.data.upRow then
      w.data.path=fs.getDir(w.data.path) if w.data.path=="" then w.data.path="/" end
      return
    end
    local row=y1+1
    if w.data.path~="/" then row=row+1 end
    local idx=y-row+1
    if w.data.files and w.data.files[idx] then
      local f=w.data.files[idx]
      local full=fs.combine(w.data.path,f)
      if fs.isDir(full) then w.data.path="/"..full else notify("File",f) end
    end
  end
  redrawDesktop()
end

local function openAppManager()
  local win=createWindow("App Manager","\31",38,16)
  win.data.mode="list"
  win.data.urlInput=""
  win.render=function(w)
    local x1,y1,x2,y2=w.contentArea[1],w.contentArea[2],w.contentArea[3],w.contentArea[4]
    box(x1,y1,x2,y2,colors.white)
    if w.data.mode=="list" then
      wp(x1+1,y1,"Installed apps",colors.gray,colors.white)
      local row=y1+1
      w.data.rows={}
      for _,app in ipairs(S.apps) do
        if row+1>y2-2 then break end
        box(x1+1,row,x2-1,row+1,colors.lightGray)
        wp(x1+2,row,(app.icon or "\183").." "..app.name,colors.black,colors.lightGray)
        if app.protected then
          wp(x1+2,row+1,"Built-in",colors.gray,colors.lightGray)
        else
          wp(x2-9,row+1,"Remove",colors.red,colors.lightGray)
        end
        table.insert(w.data.rows,{y1=row,y2=row+1,app=app})
        row=row+3
      end
      box(x1+1,y2-1,x1+10,y2-1,S.theme)
      wp(x1+2,y2-1,"+ URL",colors.white,S.theme)
      w.data.urlBtn={x1+1,x1+10,y2-1}
    elseif w.data.mode=="url" then
      wp(x1+1,y1,"Install from Pastebin URL",colors.gray,colors.white)
      box(x1+1,y1+2,x2-1,y1+2,colors.lightGray)
      wp(x1+2,y1+2,w.data.urlInput,colors.black,colors.lightGray)
      w.data.inputBox={x1+1,x2-1,y1+2}
      box(x1+1,y1+4,x1+11,y1+4,S.theme)
      wp(x1+2,y1+4,"Install",colors.white,S.theme)
      box(x1+13,y1+4,x1+21,y1+4,colors.lightGray)
      wp(x1+14,y1+4,"Cancel",colors.black,colors.lightGray)
      w.data.installBtn={x1+1,x1+11,y1+4}
      w.data.cancelBtn={x1+13,x1+21,y1+4}
      if w.data.status then wp(x1+1,y1+6,w.data.status,colors.gray,colors.white) end
    end
  end
  win.onClick=function(w,x,y)
    if w.data.mode=="list" then
      local b=w.data.urlBtn
      if b and y==b[3] and x>=b[1] and x<=b[2] then
        w.data.mode="url" return
      end
      for _,r in ipairs(w.data.rows or {}) do
        if y==r.y2 and not r.app.protected then
          local x2=w.contentArea[3]
          if x>=x2-9 then removeApp(r.app.name) end
        end
      end
    elseif w.data.mode=="url" then
      local ib=w.data.installBtn local cb=w.data.cancelBtn
      if ib and y==ib[3] and x>=ib[1] and x<=ib[2] then
        local url=w.data.urlInput
        if url~="" then
          local id=url:match("([%w]+)$")
          local fname="/app_"..id
          w.data.status="Downloading..."
          redrawDesktop()
          local ok=shell.run("wget","https://pastebin.com/raw/"..id,fname)
          if ok then
            installApp(id,fname,"\31")
            w.data.status="Installed: "..id
          else
            w.data.status="Download failed"
          end
        end
        return
      end
      if cb and y==cb[3] and x>=cb[1] and x<=cb[2] then
        w.data.mode="list" w.data.status=nil return
      end
      local inb=w.data.inputBox
      if inb and y==inb[3] then w.data.focus=true end
    end
  end
  win.onChar=function(w,ch)
    if w.data.mode=="url" and w.data.focus then
      w.data.urlInput=w.data.urlInput..ch
    end
  end
  win.onKey=function(w,key)
    if w.data.mode=="url" and w.data.focus and key==keys.backspace then
      w.data.urlInput=w.data.urlInput:sub(1,-2)
    end
  end
  redrawDesktop()
end

local function openSettings()
  local win=createWindow("Settings","\159",36,16)
  win.data.tab=1
  win.render=function(w)
    local x1,y1,x2,y2=w.contentArea[1],w.contentArea[2],w.contentArea[3],w.contentArea[4]
    box(x1,y1,x2,y2,colors.white)
    local tabs={"Account","Personalization","System","Storage"}
    for i,name in ipairs(tabs) do
      local tx=x1+(i-1)*9
      box(tx,y1,tx+8,y1,w.data.tab==i and S.theme or colors.lightGray)
      wp(tx+1,y1,name:sub(1,7),colors.white,w.data.tab==i and S.theme or colors.lightGray)
    end
    w.data.tabW=9
    local cy=y1+2
    if w.data.tab==1 then
      wp(x1+1,cy,"User: "..S.user,colors.black,colors.white)
      wp(x1+1,cy+2,"New password",colors.gray,colors.white)
      box(x1+1,cy+3,x1+20,cy+3,colors.lightGray)
      wp(x1+2,cy+3,string.rep("\7",#(w.data.newPw or "")),colors.black,colors.lightGray)
      w.data.pwBox={x1+1,x1+20,cy+3}
      box(x1+1,cy+5,x1+9,cy+5,colors.green)
      wp(x1+2,cy+5,"Save",colors.white,colors.green)
      w.data.saveBtn={x1+1,x1+9,cy+5}
      box(x1+1,cy+8,x1+12,cy+8,colors.red)
      wp(x1+2,cy+8,"Sign out",colors.white,colors.red)
      w.data.logoutBtn={x1+1,x1+12,cy+8}
    elseif w.data.tab==2 then
      wp(x1+1,cy,"Accent color",colors.gray,colors.white)
      w.data.colorBtns={}
      for i,c in ipairs(THEME_COLORS) do
        local bx=x1+1+(i-1)*4
        box(bx,cy+1,bx+2,cy+2,c)
        if c==S.theme then rect(bx,cy+1,bx+2,cy+2,colors.black) end
        table.insert(w.data.colorBtns,{x1=bx,y1=cy+1,x2=bx+2,y2=cy+2,c=c})
      end
      wp(x1+1,cy+4,"Background",colors.gray,colors.white)
      w.data.bgBtns={}
      for i,n in ipairs(BG_NAMES) do
        local by=cy+5+(i-1)
        box(x1+1,by,x1+3,by,S.bg==i and S.theme or colors.lightGray)
        wp(x1+5,by,n,colors.black,colors.white)
        table.insert(w.data.bgBtns,{x1=x1+1,y1=by,x2=x1+3,y2=by,bg=i})
      end
    elseif w.data.tab==3 then
      wp(x1+1,cy,"Clock format",colors.gray,colors.white)
      box(x1+1,cy+1,x1+7,cy+1,S.clockfmt=="24h" and S.theme or colors.lightGray)
      wp(x1+2,cy+1,"24h",colors.white,S.clockfmt=="24h" and S.theme or colors.lightGray)
      box(x1+9,cy+1,x1+15,cy+1,S.clockfmt=="12h" and S.theme or colors.lightGray)
      wp(x1+10,cy+1,"12h",colors.white,S.clockfmt=="12h" and S.theme or colors.lightGray)
      w.data.clk24={x1+1,x1+7,cy+1} w.data.clk12={x1+9,x1+15,cy+1}
      box(x1+1,cy+4,x1+9,cy+4,S.theme)
      wp(x1+2,cy+4,"Restart",colors.white,S.theme)
      w.data.restartBtn={x1+1,x1+9,cy+4}
      box(x1+11,cy+4,x1+21,cy+4,colors.red)
      wp(x1+12,cy+4,"Shut down",colors.white,colors.red)
      w.data.shutdownBtn={x1+11,x1+21,cy+4}
    elseif w.data.tab==4 then
      local free=fs.getFreeSpace("/")
      local cap=fs.getCapacity and fs.getCapacity("/") or nil
      wp(x1+1,cy,"Free space",colors.gray,colors.white)
      if free=="unlimited" then
        wp(x1+1,cy+1,"Unlimited",colors.black,colors.white)
      else
        local freeKB=math.floor(free/1024)
        wp(x1+1,cy+1,freeKB.." KB free",colors.black,colors.white)
        if cap and type(cap)=="number" then
          local capKB=math.floor(cap/1024)
          local usedPct=math.floor((1-(free/cap))*100)
          wp(x1+1,cy+2,"of "..capKB.." KB total ("..usedPct.."% used)",colors.gray,colors.white)
          local barW=x2-x1-2
          local fillW=math.floor(barW*usedPct/100)
          box(x1+1,cy+4,x1+barW,cy+4,colors.lightGray)
          if fillW>0 then
            box(x1+1,cy+4,x1+fillW,cy+4,usedPct>90 and colors.red or S.theme)
          end
        end
      end
    end
  end
  win.onClick=function(w,x,y)
    local x1,y1=w.contentArea[1],w.contentArea[2]
    if y==y1 then
      for i=1,4 do
        local tx=x1+(i-1)*9
        if x>=tx and x<=tx+8 then w.data.tab=i return end
      end
    end
    if w.data.tab==1 then
      local pb=w.data.pwBox
      if pb and y==pb[3] then w.data.focus="pw" return end
      local sb=w.data.saveBtn
      if sb and y==sb[3] and x>=sb[1] and x<=sb[2] then
        if w.data.newPw and #w.data.newPw>0 then
          S.accounts[S.user].pw=hashpw(w.data.newPw)
          saveData() notify("Settings","Password updated")
          w.data.newPw=""
        end
        return
      end
      local lb=w.data.logoutBtn
      if lb and y==lb[3] and x>=lb[1] and x<=lb[2] then logout() return end
    elseif w.data.tab==2 then
      for _,b in ipairs(w.data.colorBtns or {}) do
        if x>=b.x1 and x<=b.x2 and y>=b.y1 and y<=b.y2 then S.theme=b.c saveData() return end
      end
      for _,b in ipairs(w.data.bgBtns or {}) do
        if x>=b.x1 and x<=b.x2 and y==b.y1 then S.bg=b.bg saveData() return end
      end
    elseif w.data.tab==3 then
      local c24,c12=w.data.clk24,w.data.clk12
      if c24 and y==c24[3] and x>=c24[1] and x<=c24[2] then S.clockfmt="24h" saveData() return end
      if c12 and y==c12[3] and x>=c12[1] and x<=c12[2] then S.clockfmt="12h" saveData() return end
      local rb=w.data.restartBtn
      if rb and y==rb[3] and x>=rb[1] and x<=rb[2] then restart() return end
      local sd=w.data.shutdownBtn
      if sd and y==sd[3] and x>=sd[1] and x<=sd[2] then shutdown() return end
    end
  end
  win.onChar=function(w,ch)
    if w.data.focus=="pw" then w.data.newPw=(w.data.newPw or "")..ch end
  end
  win.onKey=function(w,key)
    if w.data.focus=="pw" and key==keys.backspace then
      w.data.newPw=(w.data.newPw or ""):sub(1,-2)
    end
  end
  redrawDesktop()
end

local function inBox(x,y,b)
  return b and x>=b[1] and x<=b[2] and y==b[3]
end
local function inRect(x,y,b)
  return b and x>=b[1] and x<=b[2] and y>=b[3] and y<=b[4]
end

local openEaveChat,openSaveChat

local MAX_WINDOWS=3
local function launchApp(app)
  if #S.windows>=MAX_WINDOWS then
    notify("WaveOS","Close a window first (max "..MAX_WINDOWS..")")
    return
  end
  if app.name=="App Manager" then openAppManager()
  elseif app.name=="Settings" then openSettings()
  elseif app.name=="Explorer" then openFileExplorer()
  elseif app.name=="EaveChat" then openEaveChat()
  elseif app.name=="SaveChat" then openSaveChat()
  else runApp(app) end
end

local function handlePower(key)
  if key=="sleep" then goSleep() S.start=false return true
  elseif key=="restart" then restart() return true
  elseif key=="shutdown" then shutdown() return true
  end
  return false
end

local function pointInWindow(win,x,y)
  return x>=win.x and x<=win.x+win.w-1 and y>=win.y and y<=win.y+win.h-1
end

local function topWindowAt(x,y)
  for i=#S.windows,1,-1 do
    local w=S.windows[i]
    if not w.minimized and pointInWindow(w,x,y) then return w end
  end
end

local function eventMatchesFilter(win,name)
  if name=="terminate" then return true end
  if win.filter==nil then return true end
  return win.filter==name
end

local function dispatchAppEvents(ev)
  if S.screen~="desktop" then return end
  local e=ev[1]
  local mouseEvt=(e=="mouse_click" or e=="mouse_drag" or e=="mouse_up" or e=="mouse_scroll")
  local modalOpen=(S.start or S.notifPanel or S.volPanel)
  local mouseTarget=nil
  if mouseEvt and not modalOpen then
    mouseTarget=topWindowAt(ev[3],ev[4])
  end
  local anyDelivered=false
  for i=#S.windows,1,-1 do
    local win=S.windows[i]
    if win.co and coroutine.status(win.co)~="dead" then
      local fwd=nil
      if mouseEvt then
        if win==mouseTarget and win.contentArea and not win.minimized then
          local x,y=ev[3],ev[4]
          if x>=win.contentArea[1] and x<=win.contentArea[3]
             and y>=win.contentArea[2] and y<=win.contentArea[4] then
            fwd={e,ev[2],x-win.contentArea[1]+1,y-win.contentArea[2]+1}
          end
        end
      elseif e=="key" or e=="char" or e=="key_up" or e=="paste" then
        if win.focused then fwd=ev end
      else
        fwd=ev
      end
      if fwd and eventMatchesFilter(win,fwd[1]) then
        local prev=term.redirect(win.surface)
        local ok,filterOrErr=coroutine.resume(win.co,table.unpack(fwd))
        term.redirect(prev)
        if not ok then
          local appName=win.app and win.app.name or "App"
          closeWindow(win)
          redrawDesktop()
          showBlueScreen(appName,filterOrErr)
        elseif coroutine.status(win.co)=="dead" then
          win.dead=true
        else
          win.filter=filterOrErr
          anyDelivered=true
        end
      end
    end
  end
  if anyDelivered then redrawDesktop() end
end

local function handleDesktopClick(b,x,y)
  local ty=taskbarY()
  if y>=ty then
    if x>=2 and x<=7 then
      S.start=not S.start S.notifPanel=false S.volPanel=false redrawDesktop() return
    end
    if S.start or S.notifPanel or S.volPanel then closeMenus() redrawDesktop() return end
    if x==W-16 then notify("Network",hasInternet() and "Connected" or "No internet") return end
    if x==W-13 then S.volPanel=not S.volPanel redrawDesktop() return end
    if x==W-10 or x==W-9 then S.notifPanel=not S.notifPanel redrawDesktop() return end
    for _,win in ipairs(S.windows) do
      if win.taskX1 and x>=win.taskX1 and x<=win.taskX2 then
        if win.minimized then win.minimized=false focusWindow(win)
        elseif win.focused then win.minimized=true
        else focusWindow(win) end
        redrawDesktop() return
      end
    end
    return
  end

  if S.start then
    if S.startBounds then
      local mx,my,mw,mh=S.startBounds[1],S.startBounds[2],S.startBounds[3],S.startBounds[4]
      if x<mx or x>mx+mw-1 or y<my or y>my+mh-1 then
        S.start=false redrawDesktop() return
      end
    end
    if inBox(x,y,S.startSearchBox) then S.startFocus=true return end
    for _,it in ipairs(S.startItems or {}) do
      if x>=it.x1 and x<=it.x2 and y>=it.y1 and y<=it.y2 then
        S.start=false
        launchApp(it.app)
        return
      end
    end
    for k,b2 in pairs(S.powerBtns or {}) do
      if inBox(x,y,b2) then handlePower(k) return end
    end
    return
  end

  if S.volPanel then
    if S.volBounds then
      local px,py,pw,ph=S.volBounds[1],S.volBounds[2],S.volBounds[3],S.volBounds[4]
      if x<px or x>px+pw-1 or y<py or y>py+ph-1 then S.volPanel=false redrawDesktop() return end
    end
    if S.volBar and y==S.volBar[3] then
      local frac=(x-S.volBar[1])/(S.volBar[2]-S.volBar[1])
      S.volume=math.max(0,math.min(100,math.floor(frac*100+0.5)))
      saveData() redrawDesktop()
    end
    return
  end

  if S.notifPanel then
    if S.notifBounds then
      local nx,ny,nw,nh=S.notifBounds[1],S.notifBounds[2],S.notifBounds[3],S.notifBounds[4]
      if x<nx or x>nx+nw-1 or y<ny or y>ny+nh-1 then S.notifPanel=false redrawDesktop() return end
      if y==ny and x>=W-2 then S.notifPanel=false redrawDesktop() return end
      if y==ny+nh-1 then S.notifs={} redrawDesktop() return end
    end
    return
  end

  local win=topWindowAt(x,y)
  if win then
    focusWindow(win)
    if y==win.y then
      if inBox(x,y,win.closeBtn) then
        closeWindow(win) redrawDesktop() return
      end
      if inBox(x,y,win.minBtn) then
        win.minimized=true redrawDesktop() return
      end
      if x>=win.titleBar[1] and x<=win.titleBar[2] then
        S.dragWin={win=win,mode="move",offX=x-win.x,offY=y-win.y}
        return
      end
    end
    if win.resizeHandle and x>=win.resizeHandle[1] and x<=win.resizeHandle[2]
       and y>=win.resizeHandle[3] and y<=win.resizeHandle[4] then
      S.dragWin={win=win,mode="resize",startW=win.w,startH=win.h,startX=x,startY=y}
      return
    end
    if win.onClick and x>=win.contentArea[1] and x<=win.contentArea[3] and y>=win.contentArea[2] and y<=win.contentArea[4] then
      win.onClick(win,x,y)
    end
    redrawDesktop()
    return
  end

  for _,ic in ipairs(S.deskIcons or {}) do
    if x>=ic.x1 and x<=ic.x2 and y>=ic.y1 and y<=ic.y2 then
      closeMenus()
      launchApp(ic.app)
      return
    end
  end

  closeMenus() redrawDesktop()
end

local function handleDesktopDrag(x,y)
  if not S.dragWin then return end
  local d=S.dragWin local win=d.win
  if d.mode=="move" then
    win.x=x-d.offX win.y=y-d.offY
    clampWin(win)
  elseif d.mode=="resize" then
    win.w=d.startW+(x-d.startX) win.h=d.startH+(y-d.startY)
    clampWin(win)
  end
  redrawDesktop()
end

local function handleDesktopKey(key)
  if S.start and S.startFocus then
    if key==keys.backspace then S.search=S.search:sub(1,-2) redrawDesktop() end
    return
  end
  for _,win in ipairs(S.windows) do
    if win.focused and win.onKey then win.onKey(win,key) redrawDesktop() end
  end
end

local function handleDesktopChar(ch)
  if S.start and S.startFocus then
    S.search=S.search..ch redrawDesktop() return
  end
  for _,win in ipairs(S.windows) do
    if win.focused and win.onChar then win.onChar(win,ch) redrawDesktop() end
  end
end

local function handleLoginClick(x,y)
  if inBox(x,y,S.switchUserBtn) and S.accountNames then
    for i,n in ipairs(S.accountNames) do
      if n==S.loginUser then
        S.loginUser=S.accountNames[(i%#S.accountNames)+1] break
      end
    end
    S.loginPw="" S.loginErr=false drawLoginScreen() return
  end
  if inBox(x,y,S.loginPwBox) then return end
  if not S.loginBusy and inBox(x,y,S.loginBtn) then
    S.loginBusy=true drawLoginScreen()
    sleep(0.1)
    local acc=S.accounts[S.loginUser]
    if acc and hashpw(S.loginPw)==acc.pw then
      S.user=S.loginUser S.theme=acc.theme or S.theme
      S.screen="desktop" S.loginBusy=false
      notify("WaveOS","Welcome, "..S.user)
      redrawDesktop()
    else
      S.loginErr=true S.loginPw="" S.loginBusy=false
      drawLoginScreen()
    end
  end
end

local function handleLoginKey(key)
  if key==keys.backspace then S.loginPw=S.loginPw:sub(1,-2) drawLoginScreen()
  elseif key==keys.enter then handleLoginClick(S.loginBtn and S.loginBtn[1] or 0,S.loginBtn and S.loginBtn[3] or 0)
  end
end
local function handleLoginChar(ch)
  S.loginPw=S.loginPw..ch drawLoginScreen()
end

local function handleSetupClick(x,y)
  local step=S.setupStep or 1
  local cx,cy=4,6
  if step==1 then
    if y==cy+1 then S.setupFocus="user"
    elseif y==cy+4 then S.setupFocus="pw"
    elseif y==cy+7 then S.setupFocus="pw2"
    elseif inBox(x,y,S.setupBtn) then
      local u,p,p2=S.tmpUser or "",S.tmpPw or "",S.tmpPw2 or ""
      if #u<1 then S.setupErr="Username required" drawSetup() return end
      if p~=p2 then S.setupErr="Passwords do not match" drawSetup() return end
      if #p<3 then S.setupErr="Password too short" drawSetup() return end
      S.setupErr=nil S.setupStep=2
    end
    drawSetup()
  elseif step==2 then
    for i,c in ipairs(THEME_COLORS) do
      local bx=cx+(i-1)*4
      if y==cy+1 and x>=bx and x<=bx+2 then S.theme=c drawSetup() return end
    end
    for i=1,3 do
      local by=cy+5+(i-1)*2
      if y==by and x>=cx and x<=cx+2 then S.bg=i drawSetup() return end
    end
    if y==cy+13 then
      if x>=cx and x<=cx+6 then S.clockfmt="24h" drawSetup() return end
      if x>=cx+8 and x<=cx+14 then S.clockfmt="12h" drawSetup() return end
    end
    if inBox(x,y,S.setupBtn) then S.setupStep=3 drawSetup() return end
    drawSetup()
  elseif step==3 then
    if inBox(x,y,S.setupBtn) then
      S.accounts[S.tmpUser]={pw=hashpw(S.tmpPw or ""),theme=S.theme}
      S.setup=true
      saveData()
      local sf=fs.open("startup","w")
      if sf then sf.writeLine('shell.run("waveos2")') sf.close() end
      S.screen="login" S.loginUser=S.tmpUser S.loginPw="" S.loginErr=false
      drawLoginScreen()
    end
  end
end

local function handleSetupKey(key)
  local f=S.setupFocus
  if key==keys.backspace then
    if f=="user" then S.tmpUser=(S.tmpUser or ""):sub(1,-2)
    elseif f=="pw" then S.tmpPw=(S.tmpPw or ""):sub(1,-2)
    elseif f=="pw2" then S.tmpPw2=(S.tmpPw2 or ""):sub(1,-2)
    end
    drawSetup()
  elseif key==keys.tab then
    local order={"user","pw","pw2"}
    for i,o in ipairs(order) do if o==f then S.setupFocus=order[i%3+1] break end end
    drawSetup()
  end
end
local function handleSetupChar(ch)
  local f=S.setupFocus
  if f=="user" then S.tmpUser=(S.tmpUser or "")..ch
  elseif f=="pw" then S.tmpPw=(S.tmpPw or "")..ch
  elseif f=="pw2" then S.tmpPw2=(S.tmpPw2 or "")..ch
  end
  drawSetup()
end

local function registerBuiltins()
  if #S.apps>0 then return end
  table.insert(S.apps,{name="Explorer",file="",icon="\186",builtin=true,protected=true})
  table.insert(S.apps,{name="Settings",file="",icon="\159",builtin=true,protected=true})
  table.insert(S.apps,{name="App Manager",file="",icon="\31",builtin=true,protected=true})
  table.insert(S.apps,{name="EaveChat",file="",icon="\206",builtin=true,protected=true})
  table.insert(S.apps,{name="SaveChat",file="",icon="\207",builtin=true,protected=true})
end

loadData()
if not S.theme then S.theme=colors.blue end
if not S.bg then S.bg=1 end
if not S.clockfmt then S.clockfmt="24h" end
if not S.volume then S.volume=70 end
registerBuiltins()

S.tmpUser="" S.tmpPw="" S.tmpPw2="" S.setupFocus="user" S.setupStep=1

drawBoot()

if S.setup and next(S.accounts) then
  S.screen="login"
  drawLoginScreen()
else
  S.screen="setup"
  drawSetup()
end

local clockTimer=os.startTimer(1)

while S.running do
  local ev={os.pullEventRaw()}
  local e=ev[1]

  if S.sleeping then
    if e=="mouse_click" or e=="key" then
      S.sleeping=false redrawDesktop()
    end
  elseif e=="timer" and ev[2]==clockTimer then
    clockTimer=os.startTimer(1)
    S.storageTick=(S.storageTick or 0)+1
    if S.storageTick>=30 then
      S.storageTick=0
      local free=fs.getFreeSpace("/")
      if type(free)=="number" then
        local lowThreshold=51200
        if free<lowThreshold and not S.lowStorageWarned then
          S.lowStorageWarned=true
          notify("Low storage",math.floor(free/1024).." KB free","warn")
        elseif free>=lowThreshold*2 then
          S.lowStorageWarned=false
        end
      end
    end
    if S.screen=="desktop" then drawTaskbar() if S.start then drawStartMenu() end end
  elseif e=="mouse_click" then
    local b,x,y=ev[2],ev[3],ev[4]
    if S.screen=="desktop" then handleDesktopClick(b,x,y)
    elseif S.screen=="login" then handleLoginClick(x,y)
    elseif S.screen=="setup" then handleSetupClick(x,y)
    end
  elseif e=="mouse_drag" then
    local b,x,y=ev[2],ev[3],ev[4]
    if S.screen=="desktop" then handleDesktopDrag(x,y) end
  elseif e=="mouse_up" then
    if S.screen=="desktop" then S.dragWin=nil end
  elseif e=="mouse_scroll" then
  elseif e=="key" then
    local key=ev[2]
    if S.screen=="desktop" then handleDesktopKey(key)
    elseif S.screen=="login" then handleLoginKey(key)
    elseif S.screen=="setup" then handleSetupKey(key)
    end
  elseif e=="char" then
    local ch=ev[2]
    if S.screen=="desktop" then handleDesktopChar(ch)
    elseif S.screen=="login" then handleLoginChar(ch)
    elseif S.screen=="setup" then handleSetupChar(ch)
    end
  elseif e=="terminate" then
    S.running=false
  end

  dispatchAppEvents(ev)
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1,1)
