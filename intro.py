#!/usr/bin/python

__all__ = ["intro", "outro", "texter", "post_intro"]

import math
import random
import sys
from struct import pack
from struct import unpack
from cdt import *
import md5
import pickle

from PIL import Image, ImageDraw, ImageFont
from screens import MakeMode0Screen, MakeMode1Screen, MakeCPCScreen 
from cdt import idgen

##############################################################################

def palette(x=False):
	if x:	return [0,0,0, 255,255,0,   127,255,127, 255,255,255] + 252*[0,0,0]
	else:	return [0,0,0, 0,0,127,     127,255,127, 255,255,255] + 252*[0,0,0]

class texter:
	done = False
	addr = None

	def __init__(self,cdt,text_base,font_base,text_out_base):
		self.cdt = cdt
		self.c = 1
		if texter.addr == None: texter.addr = text_out_base

		self.collate=[]
		self.collate_len=0

		if not texter.done:
			cdt.exec_code("build/textdraw-%d.bin"%(cdt.cycles_per_line), text_base)
			font = Image.open("fonts/dozfont.gif")
			#bins = MakeMode1Screen(font,160,16)
			bins = MakeCPCScreen(font, [0,0xff,0xff,0xff], [0x88,0x44,0x22,0x11], 160, 16)
			chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!.,?abcdefghijklmnopqrstuvwxyz[-()_|{}]'+=* "
			# [] are quotes, () are brackets, {} are corner pieces, |_ sides
			# * is crtc
		
			buf = bytearray(chr(0)*128*2*16)
			idx=0
			for c in chars:
				ptr=2*16*ord(c)
				for y in xrange(0,16):
					buf[ptr+y*2+0]=chr((bins[y])[idx+0])
					buf[ptr+y*2+1]=chr((bins[y])[idx+1])
				idx = idx+2
			texter.done = True
	
			cdt.datablock(font_base,str(buf))

			self.fontbuf=buf
			self.fontbins=bins
	
	def text(self,x,y,s,c=None):
		if x<0: raise Exception("x is off left of screen: %f",x)
		if (x+len(s))>40.0: raise Exception("x is off right of screen: %f",x+len(s))
		if c==None: c=self.c
		self.c = c
		self.y=y
		self.x=x+len(s)
		cols=[0x00,0xf0,0x0f,0xff]
		self.cdt.dataraw(8,pack("<HB",int(0xc000+160*y+x*2),cols[c]))
		self.cdt.dataraw(texter.addr,s)
		texter.addr=texter.addr+len(s)
		return self

	def centre(self,s,c=None):
		return self.text(20-0.5*len(s),self.y,s,c)

	def line(self,y=None):
		if y==None: y=self.y+1
		self.y=y
		return self

	def left(self,s,c=None):
		return self.text(19.5-len(s),self.y,s,c)

	def right(self,s,c=None):
		return self.text(20.5,self.y,s,c)

	def present(self,t=3000):
		self.cdt.gap(t)
		self.cdt.datablock(0xc000,16384*chr(0))
		self.y=0
		return self

	def credit(self,s=None):

		if s==None:
			if self.collate_len>0:
				x=19.5-self.collate_len*0.5
				for w in self.collate:
					if self.c == 2: c=3
					else: c=2
					self.text(x,self.y,w,c)
					x=x+len(w)+1
			self.y=self.y+1
			self.collate=[]
			self.collate_len=-1
		else:
			l=len(s)
			if self.collate_len+1+l > 35:
				self.credit(None)
			self.collate_len=self.collate_len+1+l
			self.collate.append(s)

		return self

def post_intro(cdt,writer,text_base,font_base,text_out_base):	
	t=texter(cdt,text_base,font_base,text_out_base)
	writer.present(1000)
	cdt.palette([0x54,0x4a,0x4b,0x53])

	#               "1234567890123456789012345678901234567890"
	t.line(6).centre("Disk drive not working?",2)
	t.present(500)
	t.line(6).centre("Pining for a tape demo?",2)
	t.present(500)
	t.line(6).centre("Well, you're in luck!",2)
	t.present(500)
	t.line(3).centre("Breaking Baud",2)
	t.line(5).centre("A turbo loader for the Amstrad CPC",1)
	cdt.gap(1000)
	t.line(8).centre("Everything is loaded direct from tape",3)
	t.line().centre("and decompressed in-place into memory...",3)
	t.present(1000)

	t.line(6).centre("Enjoy our tapestry...",1)
	cdt.gap(500)
	t.text(t.x-3-8,t.y,"TAPE",2)
	t.text(t.x,t.y,"story...",3)
	t.present(1000)

#	t.present()
#	t.line(6).centre("How about some art?",1)
#	t.text(2,8,"A [Turbo ",2)
#	t.text(t.x,8,"Tapes",3)
#	t.text(t.x,8,"try], you might say...",2)
#	t.present() # final clear

	#               "1234567890123456789012345678901234567890"

def outro(cdt,writer,text_base,font_base,text_out_base):	
	t=texter(cdt,text_base,font_base,text_out_base)
	cdt.palette([0x54,0x4a,0x4b,0x53])
	t.line(1).centre("Breaking Baud")
	t.line(3).centre("was presented at",2)
	t.line(5).centre("REVISION 2014",3)

	t.present()
	#               "1234567890123456789012345678901234567890"
	t.line(0).centre("| CREDITS |",2)
	t.line(1).centre("{_________}",2).line()
	t.line().centre("Tape loading and concept",2).line()
	t.line().left("Code",1).right("Doz",2).line()
	t.line().left("Encouragement",1).right("CPC Wiki",2).line() #.right("CRTC massive",3).line()
	t.line().left("Inspiration",1).right("TAP demo (ZX)",2).line().right("Ahh.. the tape",3).line().right("      loading era!",3)

	t.present()
	#               "1234567890123456789012345678901234567890"
	t.line(0).centre("| Intro section |",2)
	t.line(1).centre("{_______________}",2).line()
	t.line().left("Code + [art]",1).right("Doz",2).line()
	t.line().left("Music",1).right("McKlain",2).line().right("[Hard style]",3)

	t.present()
	#               "1234567890123456789012345678901234567890"
	t.line(0).centre("| Light Keeper |",2)
	t.line(1).centre("{______________}",2).line()
	t.line().left("Art",1).right("JulijanaM",2).line().right("Jelena",3).line()
	t.line().left("Music",1).right("McKlain",2).line().right("[Little sailor]",3).line()
	t.line().left("Coordination",1).right("MaV",2).line()

	t.present()
	#               "1234567890123456789012345678901234567890"
	t.line(0).centre("| Bin Renderin |",2)
	t.line(1).centre("{______________}",2).line()
	t.line().left("Art",1).right("Rexbeng",2).line()
	t.line().left("Music",1).right("McKlain",2).line().right("[CR4SH]",3)

	t.present()
	#               "1234567890123456789012345678901234567890"
	t.line(0).centre("| Rose and raindrops |",2)
	t.line(1).centre("{____________________}",2).line()
	t.line().left("Art",1).right("JulijanaM",2).line()
	t.line().left("Music",1).right("McKlain",2).line().right("[Bonito]",3)

	t.present()
	#               "1234567890123456789012345678901234567890"
	t.line(0).centre("| Credits section |",2)
	t.line(1).centre("{_________________}",2).line()
	t.line().left("Code",1).right("Doz",2).line().right("MaV",3).line()
	t.line().left("Font",1).right("Tunk",2).line()
	t.line().left("Music",1).right("McKlain",2).line().right("[Seagulls]",3)


	t.present()
	#               "1234567890123456789012345678901234567890"
	t.line(0).centre("| GREETINGS |",2)
	t.line(1).centre("{___________}",2).line()

	t.line().centre("Revision",1).line().line()
	t.credit("DFox")
	t.credit("Styx")
	t.credit("FRaNKy")
	t.credit("Okkie")
	t.credit("Moqui")
	#t.credit()
	t.credit("Charlie")
	t.credit("The beam team")
	t.credit("All the orgas")
	t.credit()
	t.line().centre("Scene friends",1).line().line()
	t.credit("gasman")
	t.credit("h0ffman")
	t.credit("SaVannaH")
	t.credit("TCM")
	t.credit("Topy44")
	t.credit("cgi")
	t.credit("dotwaffle")
	t.credit("stavs")
	t.credit("LNX")
	t.credit("ne7")
	t.credit("lft")
	t.credit()
	#t.credit("")
	#t.credit("")

	t.present()
	t.line().centre("CPC scene friends",1).line().line()
	for i in [
			'Gryzor',
			"mr_lou",
			'Bryce', 
			'Kevin Thacker',
			'DevilMarkus',
			'Optimus', 
			'Octoate',
			'Nilquader',
			'Kangaroo Musique',
			'Axelay',
			'BSC',
			'tastefulmrship', #'Jonah (Tasteful Mr) Ship',
			'Targan',
			'Hicks',
			'Toms',
			'Eliot',
			'TotO',
			'SyX',
			'Carnivac',
			'AMSDOS',
			'Executioner',
			'Flynn',
			'Prodatron',
			'phi2x'
			]: t.credit(i)
	t.credit().line().centre('All at CPC Wiki',1)
	t.credit()

	t.present()
	t.line().centre("Parties we like",1).line().line()
	for i in [
			'Sundown', 'Forever', 'Evoke', 'TUM',
			'XzentriX',
			]: t.credit(i)
	t.credit()
	t.centre('And of course, Revision!',3).line()
	t.line().centre("Other friends",1).line().line()
	for i in [
			'Megmeg',
			'Puppeh',
			'Deltafire',
			'Ruairi',
			'Tunk',
			'Kabuto',
			'alegend45',
			'reenigne',
			'psonice'
			]: t.credit(i)
	t.credit()
	for i in [
			'bonefish',
			'mikezt',
			'ellvis'
			]: t.credit(i)
	t.credit()
	for i in [
			'All cyber chicken'
			]: t.credit(i)
	t.credit()


	t.present().line()
	#               "1234567890123456789012345678901234567890"
	t.line(5).centre("Thanks for watching!",3)


def intro():
	i=Image.new("P", (320,200))
	i.putpalette(palette())
	draw=ImageDraw.Draw(i)
	(d,s,p)=(0,48,1.5)

	def downleft(c=1):
		for y in xrange(0,200):
			for x in xrange(int(-y*p),320,s):
				draw.line([(x,y), (x+3,y) ], c)

	def downright(c=1):
		for y in xrange(0,200):
			for x in xrange(int((y-320)*p),320,s):
				draw.line([(x,y), (x+3,y) ], c)
	downleft()
	yield i
	downright()
	yield i

	#return 

	def grid(c=1):
		downleft(c)
		downright(c)

	def lookup(x,y):
		y=y-1
		bx=int(3*s+(x-y)*0.5*s)+2
		by=int(0+(x+y)*0.5*s/p)
		return (bx,by)

	def fillsquare(x,y,c):
		coords=[ lookup(x,y), lookup(x+1,y), lookup(x+1,y+1), lookup(x,y+1), lookup(x,y) ]
		draw.polygon(coords,fill=c)

	coords = [ (2,0), (1,0), (0,1), (0,2), (1,2), (2,2), #c
		   (4,2), (4,1), (5,0), (6,0),		     #r
		   (0,4), (1,4), (2,4), (1,5), (1,6),	     #t
		   (6,4), (5,4), (4,5), (4,6), (5,6), (6,6)] #c

	for (x,y) in coords:
		c=(x+y)%2+2
		fillsquare(x,y,c)
		grid()
		yield i

	# remove grid
	yield None
	grid(0)
	yield i

	# redefine old blue to yellow
	i.putpalette(palette(True))

#	fillsquare(-2,4,1)
#	grid(0)
#	yield i
#
#	fillsquare(-2,3,1)
#	grid(0)
#	yield i

	#load font
	b=1
	font=ImageFont.truetype("fonts/amstrad_cpc464.ttf", 32, encoding="unic")
	for x in xrange(-b,b+1):
		for y in xrange(-b,b+1):
			draw.text( (16+x,16+y), "PRESENTS", fill=0, font=font)
	draw.text( (16,16), "PRESENTS", fill=1, font=font)
	yield i

	yield None

	# 16->48 , 60->124, 130->194

	# boxes
	ofs=-29
	ofs2=-11
	b=1
	bb=2
	draw.rectangle( [(64-bb+ofs,60-bb), (136+bb+ofs,116+bb)], outline=0, fill=0)
	draw.rectangle( [(64+ofs,60), (136+ofs,116)], outline=3, fill=0)
	yield i
	draw.rectangle( [(80-bb+ofs2,128-bb), (152+bb+ofs2,184+bb)], outline=0, fill=0)
	draw.rectangle( [(80+ofs2,128), (152+ofs2,184)], outline=3, fill=0)
	yield i

	font2=ImageFont.truetype("fonts/amstrad_cpc464.ttf", 8, encoding="unic")
	draw.text( (72+ofs,74), "Br", fill=2, font=font)
	draw.text( (72+30+ofs,74-8), "2688", fill=3, font=font2)
	yield i

	draw.text( (88+ofs2,142), "Ba", fill=2, font=font)
	draw.text( (88+30+ofs2,142-8), "2688", fill=3, font=font2)
	yield i

	for x in xrange(-b,b+1):
		for y in xrange(-b,b+1):
			draw.text( (72+64+x+ofs,74+y), "eaking", fill=0, font=font)
			draw.text( (88+64+x+ofs2,142+y), "ud", fill=0, font=font)
	draw.text( (72+64+ofs,74), "eaking", fill=1, font=font)
	draw.text( (88+64+ofs2,142), "ud", fill=1, font=font)
	yield i

	if False:
		for pause in xrange(0,2): yield None
		for scroll in xrange(1,10):
			draw.rectangle([0,0,320,200],outline=0,fill=0)
			for (x,y) in coords:
				c=(x+y)%2+2
				fillsquare(x-scroll,y,c)
				grid()
			yield i

##############################################################################

