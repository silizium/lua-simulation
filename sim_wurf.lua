#!/usr/bin/env luajit
require"imlib2" -- graphics
local c=imlib2.color
local yield=coroutine.yield
--local pi,abs,deg,rad,sin,cos,atan,sqrt=math.pi,math.abs,math.deg,math.rad,math.sin,math.cos,math.atan,math.sqrt

local printf=function(fmt,...) return io.write(string.format(fmt,...)) end
local bgcolor=c.WHITE
local fgcolor=c.BLACK
--local palette=nextcolor()

local function nextcolor()
	local colors={
--		["White"]=c.WHITE,
		["Black"]=c.BLACK,	["Dark Gray"]=c.DARKGRAY,	["Gray"]=c.GRAY,	
		["Light Gray"]=c.LIGHTGRAY,	["Red"]=c.RED,		["Green"]=c.GREEN,			
		["Blue"]=c.BLUE,	["Yellow"]=c.YELLOW,		["Orange"]=c.ORANGE,
		["Brown"]=c.BROWN,	["Magenta"]=c.MAGENTA,		["Violet"]=c.VIOLET,
		["Purple"]=c.PURPLE,["Indigo"]=c.INDIGO,		["Cyan"]=c.CYAN,		
		["Azure"]=c.AZURE,	["Teal"]=c.TEAL,			["Dark Red"]=c.DARKRED,		
		["Dark Green"]=c.DARKGREEN,	["Dark Blue"]=c.DARKBLUE, ["Dark Yellow"]=c.DARKYELLOW,	
		["Dark Brown"]=c.DARKBROWN,	["Dark Magenta"]=c.DARKMAGENTA,	["Dark Violet"]=c.DARKVIOLET,
		["Dark Purple"]=c.DARKPURPLE,	["Dark Indigo"]=c.DARKINDIGO,["Dark Cyan"]=c.DARKCYAN,	
		["Dark Aqua"]=c.DARKAQUA,	["Dark Azure"]=c.DARKAZURE,	["Dark Teal"]=c.DARKTEAL,
	}
	return coroutine.wrap(function()
		repeat
			for text,color in pairs(colors) do
				yield(color,text)
			end
		until false
	end)
end
local palette=nextcolor()

local function grid(im, xstep, ystep, color, colorf)
	local width,height=im:get_width(),im:get_height()
	im:fill_rectangle(0, 0, width, height, bgcolor)
	for x=0,width,xstep/10 do
		im:draw_line(x, height, x, height-ystep*.1, colorf)
	end
	local ten=1
	for x=xstep,width,xstep do
		im:draw_line(x, 0, x, height, color)
		if ten==10 then
			ten=1
			im:draw_line(x+1,0,x+1,height, color)
		else
			ten=ten+1
		end
	end
	ten=1
	for y=height,0,-ystep do
		im:draw_line(0,y,width,y, color)
		if ten==10 then
			ten=1
			im:draw_line(0,y+1,width,y+1, color)
		else
			ten=ten+1
		end
	end
end

local function plot(im, V0, alpha, scale, font, color)
	local width,height=im:get_width(),im:get_height()
	local alphar=math.rad(alpha)
	local G=9.80665 -- m/s^2
	local maxt=2*V0/G
	local x,y
	local t=0
	repeat
		y=math.sin(alphar)*V0*t-G/2*t^2
		if y<0 then break end
		x=math.cos(alphar)*V0*t
		im:draw_pixel(scale*x,height-scale*y,color)
		t=t+maxt/(width+1)
	until y<0
	local x=V0^2/G*math.sin(2*alphar)
	im:draw_text(font,string.format("%.0f",x), scale*x, height-20, color)
	printf("V0=%3.0f m/s Alpha=%5.2f° x=%7.2f m yH=%3.0f m t=%4.1f s\n", 
		V0, alpha, x, .5*V0^2*math.sin(alphar)^2/G, 2*V0/G*math.sin(alphar))
end

local function airF(v, area, cw, density)
	cw=cw or 0.45 -- long cylinder 0.82, sphere: 0.45
	density=density or 1.204 -- T20 kg/m³
	return 0.5*density*cw*area*v^2
end

local function calcsim(shot, alpha, dt)
	-- missle for air resistance
	local mass=shot.mass or 0.027539537 -- 450 grain bolt
	local diameter=shot.diameter or 8.5 -- mm
	local area=(diameter/2000)^2*math.pi -- arrow factor and 8.5mm arrow
	local cw=shot.cw or 0.82 -- cw of long cylinder
	-- flight simulation
	local alphar=math.rad(alpha)
	local dt=dt or 0.001 --*maxt/(width+1)
	local G=9.80665 -- m/s^2
	local maxt=2*shot.speed/G
	local x,y=0,0
	local vx,vy=math.cos(alphar)*shot.speed,math.sin(alphar)*shot.speed
	local air, vges=1.0
	return coroutine.wrap(function()
		repeat
			vy=vy*air-G*dt
			y=y+vy*dt
			if y<0 then break end
			vx=vx*air
			x=x+vx*dt
			alphar=vy~=0 and math.atan(vx/vy) or math.rad(-90)
			vges=math.sqrt(vx^2+vy^2)
			air=(vges-airF(vges,area,cw)/mass*dt)/vges
			yield(x,y,vx,vy)
		until y<=0
	end)
end

local function findalpha(shot, dt)
	local oalpha,oxmax,dec,ret,x=45,0,10,45
	local i=oalpha
	repeat -- for i=oalpha,1,-.1 do
		for ret in calcsim(shot, i, dt) do x=ret end
		--print(i,x,oalpha,oxmax,dec)
		if x>oxmax then 
			oxmax=x
			oalpha=i
		else
			if math.abs(dec)<=0.001 then
				break
			else
				i=i+dec
				dec=-dec/10
			end
		end
		i=i-dec
	until i<=0

	return oalpha,oxmax
end

local function plotsim(im, shot, alpha, scale, font, dt)
	local width,height=im:get_width(),im:get_height()
	dt=dt or 0.001
	local step=0
	local ymax=1
	local xe,ye,vxe,vye
	local color,colorname=palette()
	for x,y,vx,vy in calcsim(shot, alpha, dt) do
		xe,ye,vxe,vye=x,y,vx,vy
		ymax=y>ymax and y or ymax
		step=step+1
		im:draw_pixel(scale*x,height-scale*y,color)
	end
	im:draw_text(font,string.format("%.0f",xe), scale*xe, im:get_height()-20, color)
	printf("V0=%3.0f m/s Alpha=%5.2f° Ve=%3.0f m/s AlphaE=%5.2f° x=%7.2f m y=%3.1f m yH=%3.0f m t=%4.1f s dt=%.1f ms\n", 
		shot.speed, alpha, math.sqrt(vxe^2+vye^2), math.deg(math.atan(vye/vxe)), xe, ye, ymax, step*dt, dt*1000)
	if shot.mass then 
		local e0,ee=.5*shot.mass*shot.speed^2, .5*shot.mass*(vxe^2+vye^2)  -- 1/2 mv²
		local k0,ke=shot.mass*shot.speed, shot.mass*math.sqrt(vxe^2+vye^2) -- m*v
		if e0<10000 then
			printf("E0=%.1f J Ee=%.1f J  K0=%.1f Ns Ke=%.1f Ns", e0, ee, k0, ke) 
		else
			printf("E0=%.0f kJ Ee=%.0f kJ K0=%.1f Ns Ke=%.1f Ns", e0/1000, ee/1000, k0, ke) 
		end
		printf(" (%s)\n",colorname)
	end
end

local width,height = 1280,480
local im = imlib2.image.new(width, height)
imlib2.font.add_path("/usr/share/fonts/truetype/liberation")
local font=assert(imlib2.font.load("LiberationMono-Regular/12"))
local scale=tonumber(arg[1]) or 1/1.85
grid(im, 100*scale, 100*scale, c.GRAY, c.LIGHTGRAY)

print("150 m/s reference shot without wind resistence, parabolic")
plot(im, 150, 45, scale, font, c.LIGHTGRAY)

shots={
   	{
	name="parabolic reference shot",
    speed=150,
	angle=45,
   	},
   	{
	name="Bruce Odle record 984.89",
	speed=134.5,
	mass=0.0126,
	diameter=5.7,
	cw=.58,
   	},
   	{
	name="Don Brown record 1222.02 Recurve",
	speed=141.4,
	mass=0.0189,
	diameter=5.7,
	cw=.59,
  	},
   	{
	name="Kevin Strother record 1207.39 Compound",
	speed=140.0,
	mass=0.0189,
	diameter=5.7,
	cw=.59,
   	},
   	{
	name="Don Brown record 1222.02 Recurve",
	speed=141.4, 
	mass=0.0189, 
	diameter=5.7, 
	cw=.59,
	},
	{
	name="Kevin Strother record 1207.39 Compound",
	speed=140.0, 
	mass=0.0189, 
	diameter=5.7, 
	cw=.59,
	},
	{
	name="Harry Drake record 1854.4 Fußbogen",
	speed=197.8, 
	mass=0.021, 
	diameter=5.7, 
	cw=.59,
	},
	{
	name=[[Shot in air with crossbow and whistle
	https://www.youtube.com/watch?v=RKUMqv88MG0
	Shot straight in the air: 19.x sec flight time]],
	speed=121, 
	alpha=87, 
	mass=0.027539537, 
	diameter=7.94, 
	cw=.82,
	},
	{
	name=[[Same shot maximal distance]],
	speed=121, 
	mass=0.027539537, 
	diameter=7.94, 
	cw=.82,
	},
	{
	name=[[Medieval Windlass Crossbow
	567 kg, 88g-96g bolt (350mm), 207.5-214.8 m 47.9 m/s
	Draw 6"=15.24 cm
	compare https://www.youtube.com/watch?v=kHnZo6ELEV0]],
	speed=47.9, 
	mass=0.096, 
	diameter=10, 
	cw=.6,
	},
	{
	name=[[Easy Slingshot 96 m/s  10mm steel 4.1g
	desity steel 7860 kg/m³ 
	https://www.youtube.com/watch?v=E4Xdk1tTSPk]],
	speed=96, 
	mass=0.0041, 
	diameter=10, 
	cw=.45,
	},
	{
	name=[[Foot Slingshot 24mm 82g lead foot slingshot 185.5 m/s 
	https://www.youtube.com/watch?v=Bm5YOYrRejY]],
	speed=56, 
	mass=0.082, 
	diameter=24, 
	cw=.45,
	},
	{
	name="Medieval Crossbow 450 lbs",
	speed=42.37,
	mass=0.060,
	diameter=10,
	cw=.6,
	},
	{
	name="Medieval Crossbow 860 lbs",
	speed=47.46,
	mass=0.087,
	diameter=10,
	cw=.6,
	},
	{
	name="Medieval Longbow 95 lbs",
	speed=43,
	mass=0.0445,
	diameter=10,
	cw=.65,
	},
	{
	name="Modern Compound Bow 75 lbs",
	speed=64.62,
	mass=0.034,
	diameter=5.7,
	cw=.59,
	},
	{
	name="Modern Compound Crossbow 175 lbs",
	speed=94.67,
	mass=0.031,
	diameter=7.94,
	cw=.59,
	},
	{
	name="Warwick Trebuchet record shot 2006",
	speed=54,
	mass=13,
	diameter=1000*2*math.pow(3*13/(4*math.pi*2300),1/3), -- Granit 2620 kg/m³, Beton 2300
	cw=.48, -- rough spere
	},
}
local oalpha,oxmax

for k,shot in ipairs(shots) do
	printf("\n%s\n",shot.name)
	if shot.alpha then
		oalpha=shot.alpha
	else
		oalpha,oxmax=findalpha(shot) 
	end
	plotsim(im, shot, oalpha, scale, font)
end
--[[
for ret in calcsim(121, oalpha-10/60, 0.027539537, 7.94, .82) do 
	oxmoa=ret 
end
printf("10 MOA makes %.2f m difference.\n", math.abs(oxmoa-oxmax))
]]

-- GoT Scorpion
print(("*"):rep(60).."\n"..[[
GoT Scorpion
Data: 
5 seconds from release to miss Dany on Drogon
29 seconds Dany launching an attack on the ships (at minimum 50 kmh=400 m distance)
bolts at a minimum mass of 15 kg with lousy CW of at least 0.82, 1.5 more realistic
Rhaegal gets hit at peak point of scorpions if we want to assume maximum range
Bolts are at least 7-10 cm in diameter, length of at least 3 meter
with a specific mass of 870 kg/m³ that's about 10-20 kg per bolt 
plus 5 kg for the iron head = ~15 kg
at attack of fleet bolts hit with less than 10° and were never higher than 50 m over water

a man tops out at 600 J/s when working like a madman
Comparison: man driving a 700W (J/s) toaster https://www.youtube.com/watch?v=S4O5voOCqAQ
reload time is about 30 seconds for the scorpions
]])
local bolt={speed=175, diameter=70, cw=1.5}
bolt.mass=870*(bolt.diameter/2000)^2*math.pi*3+5
printf("Bolt mass %.1f kg 3 m long, %.0f cm diameter\n\n",bolt.mass, bolt.diameter/10)
oalpha=findalpha(bolt)
plotsim(im, bolt, oalpha, scale, font)
local xe,ye,xve,yve=0,0,0,0
for x,y,xv,yv in calcsim(bolt, oalpha, 1e-3) do 
	if y>ye then xe,ye,xve,yve=x,y,xv,yv end
end
printf("\nGoT Scorpion E0 %.0f kJ Ehit %.0f kJ Impulse %.0f Ns\n",
	.5*bolt.speed^2*bolt.mass/1000,.5*(xve^2+yve^2)*bolt.mass/1000,math.sqrt(xve^2+yve^2)*bolt.mass)
printf("You need at the very least %.0d men to ready the scorpion in time with two men putting in the new bolt\n",
	.5*bolt.speed^2*bolt.mass/600/30+2)
printf("\nRange of shooting the fleet at less than 10° angle (estimated from impact on the ships)\n")
xe,ye,xve,yve=0,0,0,0
local oalphae
for oalpha=12,1,-0.01 do
	for x,y,xv,yv in calcsim(bolt, oalpha, 1e-3) do 
		xe,ye,xve,yve=x,y,xv,yv 
		oalphae=oalpha
	end
	if -math.atan(yve/xve)<=math.rad(10.0) then 
		break
	end
end
plotsim(im, bolt, oalphae, scale, font)
im:save("sim_wurf.png")

--[[
470 lbs=2090 N 15jhd hunting crossbow
43.86 m/s (143 fps)
50 g blunt bolt 48 J
42.67 m/s broadhead (30mm) 57g 53J

https://www.youtube.com/watch?v=XSNNSh4Fuh8
in gelblock ~55 cm
https://www.youtube.com/watch?v=TdB470lo6nM

Name              force-N   arrow-g   m/s         kgm/s    J    draw/mm  gelblock
med crossbow 450   2002       60      42.37       2.54    54      114.3
med crossbow 860   3825       87      47.46       4.2    101      114.3  59 cm (bolt length ~65 cm) 101 J impulse
med longbow         422.6     43-44.5 42.37-44.5  1.82    38.7-44 635    51 cm
compound bow        333.6     34      64.62       2.19    70.9    635    10 mm 64 cm 
compound crossbow   778.4     29-31   94.67-92.1  2.74    129-131 355.6  complete through 

https://www.youtube.com/watch?v=eM9t3Zk4KCs
Assassins Crossbow  943        7      36.9-39.2   0.26     4.77

JSprave
https://www.youtube.com/watch?v=1U7TRDFjnFM
1000 Joule Airspear          396      74.74      29.6    1106            300 bar 
https://www.youtube.com/watch?v=E4Xdk1tTSPk
Airdart Pistol                18      68.13               41.77
Slingshot                             96                                 40mm steel
Sling, lead shot/whisle       60/20                                      i4/16 mm lead

https://www.youtube.com/watch?v=DBxdTkddHaE
Arrowhead 7568/74mm 10mm socket 24.06g
Ajancourt Bow: 10m 80g 55.3m/s 123J 160@30in lb bow (711N/76.2cm)
               25m 80g 52.1m/s 109J

]]

