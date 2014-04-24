#!/usr/bin/python

__all__ = ["screen_writer", "MakeMode0Screen", "MakeMode1Screen", "MakeCPCScreen"]

import math
import random
import sys
from struct import pack
from struct import unpack
from cdt import *
import md5
import pickle

from PIL import Image

##############################################################################

def MakePalette(im,n=16):
	def f(a):
		if a<=0x55: return 0
		elif a<=0xaa: return 1
		else: return 2
	hw=[0x54,0x44,0x55,0x5c,0x58,0x5d,0x4c,0x45,
	    0x4d,0x56,0x46,0x57,0x5e,0x40,0x5f,0x4e,
	    0x47,0x4f,0x52,0x42,0x53,0x5a,0x59,0x5b,
	    0x4a,0x43,0x4b]

	assert im.mode=="P"
	lut=im.copy().resize((n,1))
	lut.putdata(range(n))
	lut=list(lut.convert("RGB").getdata())
	p=[]
	for (r,g,b) in lut:
		c=(f(b))+(3*f(r))+(9*f(g))
		#print "pal %2d: %02x%02x%02x -> %d%d%d -> %2d [%02x]"%(len(p),r,g,b,f(r),f(g),f(b),c,hw[c])
		p.append(hw[c])
	return p

def MakeMode0Screen(im,bpl=80,scrh=200):
	return MakeCPCScreen(im, [0x00,0xc0,0x0c,0xcc,
				  0x30,0xf0,0x3c,0xfc,
				  0x03,0xc3,0x0f,0xcf,
				  0x33,0xf3,0x3f,0xff], [0xaa,0x55], bpl, scrh)

def MakeMode1Screen(im,bpl=80,scrh=200):
	return MakeCPCScreen(im, [0,0xf0,0x0f,0xff], [0x88,0x44,0x22,0x11], bpl, scrh)

def MakeCPCScreen(im,cols,bits,bpl=80,scrh=200):
	(w,h)=im.size
	if im.mode <> "P": raise Exception("Image not palettised format: %s"%im.mode)
	lines = []
	ppb=len(bits)
	if pow(len(cols),ppb) != 256: raise Exception("Bits and cols not consistent (%d^%d=%d) %s - %s"%(len(cols),ppb,pow(len(cols),ppb),str(bits),str(cols)))
	(x,y)=(0,0)
	lines=[]
	line=bpl*[0]
	for i in im.getdata():
		ofs=x/ppb
		if i>=len(cols): i=0
		#print ofs,bpl,i,bits[x%ppb],cols[i]
		if ofs<bpl:
			line[ofs] = line[ofs] | (bits[x%ppb] & cols[i])
		x=x+1
		if x==w:
			x=0
			lines.append(line)
			line=bpl*[0]
			y=y+1
			if y==scrh: break
	for i in xrange(y,scrh):
		lines.append(bpl*[0])
	return lines

def interlace(lines,charheight=8):
	chlines = int(len(lines)/charheight)
	for cy in xrange(0,chlines):
		for py in xrange(0,charheight):
			y=cy+chlines*py
			if y<len(lines):
				out.append(lines[y])
			else:
				out.append(len(lines[0])*[0])
		print cy
	return out

def makeraw(lines):
	scr=bytearray(16384*chr(0))
	def conv(l): return "".join([chr(x) for x in l])
	for y in xrange(0,max(len(lines),200)):
		ofs=(y&7)*2048
		ofs = ofs+(y>>3)*80
		d=conv(lines[y])
		if len(d)>80: l=80
		else: l=len(d)
		#print y,ofs,l
		scr[ofs:ofs+l]=d[:l]
	return str(scr)

def makeraw_wideonly(lines):
	return makeraw_wide(lines,24,200)

def makeraw_wide(lines,top,mx):
	topadd = 0x800 - 92*(top>>3)
	scr=bytearray(32768*chr(0))
	def conv(l): return "".join([chr(x) for x in l])
	for y in xrange(0,max(len(lines),mx)):
		ofs=(y&7)*2048
		if y<top:
			ofs = ofs+(y>>3)*92+topadd
		else:
			ofs = ofs+((y-top)>>3)*92+0x4000
		try:
			d=conv(lines[y])
			if len(d)>92: l=92
			else: l=len(d)
			#print y,ofs,l
			scr[ofs:ofs+l]=d[:l]
		except:	pass
	return str(scr)

def makeraw_overscan(lines):
	return makeraw_wide(lines,80,256)

##############################################################################

class screen_writer:
	def __init__(self,cdt,picklename=None):
		self.cdt=cdt
		self.picklename=picklename
		self.screen_map = {}
		self.compress_map = {}

		self.lasthash = ""
		self.lastdata = ""

		try:
			with open(self.picklename,"rb") as f:
				self.screen_map = pickle.load(f)
				self.compress_map = pickle.load(f)
		except:
			pass

	def save(self):
		with open(self.picklename,"wb") as f:
			pickle.dump(self.screen_map, f, 1)
			pickle.dump(self.compress_map, f, 1)

	def encode(self,im):
		assert im.mode=="P"
		cols=im.getcolors()
		ncols=len(cols)
		assert ncols <= 16
		if ncols<=4:
			cpc=MakeMode1Screen(im)
			pal=MakePalette(im,4)
		else:
			cpc=MakeMode0Screen(im)
			pal=MakePalette(im,16)
		scr=makeraw(cpc)
		return (pal,scr,md5.new(scr).digest().encode("hex"))

	def reset(self,name,im):
		(pal,scr,hash)=self.encode(im)
		self.screen_map[hash]=name
		self.lasthash=hash
		self.lastdata = scr

	def add(self,name,im,splitlen=BLOCK_SIZE,gap=True):
		(pal,scr,hash)=self.encode(im)
		if gap:
			self.cdt.gap()
		self.cdt.palette(pal)
		self.screen_map[hash]=name
		self.send(scr,hash,splitlen)

	def send(self,scr,hash,splitlen=BLOCK_SIZE):
		total="%s-%s-%d"%(self.lasthash,hash,splitlen)
		self.lasthash=hash

		try:
			#raise Exception("")
			blocks = self.compress_map[total]
			print "In-cache: %s"%total
		except:
			print "Compress: %s"%total
			blocks=list(compressor(0xc000, self.lastdata).encode(scr,splitlen))
			self.compress_map[total]=blocks
			self.save()

		self.cdt.blocks(blocks)
		self.lastdata = scr

	def clear(self):
		self.send(16384*chr(0),"")

	def present(self,pause):
		self.cdt.gap(pause)
		self.clear()
#
	def encode_wideonly(self,im):
		assert im.mode=="P"
		cols=im.getcolors()
		ncols=len(cols)
		assert ncols <= 16
		if ncols<=4:
			cpc=MakeMode1Screen(im,92,200)
			pal=MakePalette(im,4)
		else:
			cpc=MakeMode0Screen(im,92,200)
			pal=MakePalette(im,16)
		scr=makeraw_wideonly(cpc)
		return (pal,scr,md5.new(scr).digest().encode("hex"))

	def add_wideonly(self,name,im,splitlen=BLOCK_SIZE,gap=True):
		(pal,scr,hash)=self.encode_wideonly(im)
		if gap:
			self.cdt.gap()
		self.cdt.palette(pal)
		self.screen_map[hash]=name
		self.send_wideonly(scr,hash,splitlen)

	def send_wideonly(self,scr,hash,splitlen=BLOCK_SIZE):
		total="%s-%s-%d"%(self.lasthash,hash,splitlen)
		self.lasthash=hash

		try:
			#raise Exception("")
			blocks = self.compress_map[total]
			print "In-cache: %s"%total
		except:
			print "Compress: %s"%total
			blocks=list(compressor(0x8000, self.lastdata).encode(scr,splitlen))
			self.compress_map[total]=blocks
			self.save()

		self.cdt.blocks(blocks)
		self.lastdata = scr

	def clear_wideonly(self):
		self.send_wideonly(32768*chr(0),"emptywideonly")
		self.lasthash=""

	def present_wideonly(self,pause):
		self.cdt.gap(pause)
		self.clear_wideonly()
#
	def encode_overscan(self,im):
		assert im.mode=="P"
		cols=im.getcolors()
		ncols=len(cols)
		assert ncols <= 16
		if ncols<=4:
			cpc=MakeMode1Screen(im,92,256)
			pal=MakePalette(im,4)
		else:
			cpc=MakeMode0Screen(im,92,256)
			pal=MakePalette(im,16)
		scr=makeraw_overscan(cpc)
		return (pal,scr,md5.new(scr).digest().encode("hex"))

	def add_overscan(self,name,im,splitlen=BLOCK_SIZE,gap=True):
		(pal,scr,hash)=self.encode_overscan(im)
		if gap:
			self.cdt.gap()
		self.cdt.palette(pal)
		self.screen_map[hash]=name
		self.send_overscan(scr,hash,splitlen)

	def send_overscan(self,scr,hash,splitlen=BLOCK_SIZE):
		total="%s-%s-%d"%(self.lasthash,hash,splitlen)
		self.lasthash=hash

		try:
			#raise Exception("")
			blocks = self.compress_map[total]
			print "In-cache: %s"%total
		except:
			print "Compress: %s"%total
			blocks=list(compressor(0x8000, self.lastdata).encode(scr,splitlen))
			self.compress_map[total]=blocks
			self.save()

		self.cdt.blocks(blocks)
		self.lastdata = scr

	def clear_overscan(self):
		self.send_overscan(32768*chr(0),"emptyoverscan")
		self.lasthash=""

	def present_overscan(self,pause):
		self.cdt.gap(pause)
		self.clear_overscan()
#
	def keys(self):
		return self.compress_map.keys()

	def translate(self,key):
		try:
			p1=key.index('-')
			p2=key.index('-',p1+1)
			n1=key[:p1]
			n2=key[p1+1:p2]
			try: n1=self.screen_map[n1]
			except: pass
			try: n2=self.screen_map[n2]
			except: pass
			return (n1,n2)
		except:
			return ("???","???")

	def get(self,key):
		return self.compress_map[key]

