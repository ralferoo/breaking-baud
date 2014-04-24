#!/usr/bin/python

__all__ = ["cdtfile", "mainfile", "compressor", "DEFAULT_CYCLE_COUNT", "DEFAULT_NUM_LINES", "BLOCK_SIZE", "idgen"]

import math
import random
import sys
from struct import pack
from struct import unpack

DEFAULT_CYCLE_COUNT  = 31  # us between each sampling of tape level
DEFAULT_NUM_LINES    = 3   # nominal number of samples for 0 bit
BLOCK_SIZE           = 512 # symbols per block

##############################################################################

def length_to_tstates(l):
	return int(3.5*l)

##############################################################################

def idgen(id=0,d=1):
	while True:
		yield id
		id = id+d

##############################################################################

def fastidgen(id=0):
	n=0
	while True:
#		print "%3d->%3x"%(n,id)
		yield id
		n=n+1
		if id<255: id=id+1
		elif id==255: id=256+12		# 4*(3..10) + (0,2)
		elif id==256+44-2: id=256+1	# 1 + 2*(0..3)
		elif id>256: id=id+2
		else: raise "Invalid id %d"%id

crcvals={}
crcvals_gen=fastidgen()
for i in xrange(0,277): crcvals[i]=next(crcvals_gen)%255

def genfastblock(l=16):
	g = idgen()
	a = {}
	def sub(l,path):
		if l==0: a[next(g)]=path
		if l>=1: sub(l-1,path+"0")
		if l>=3: sub(l-3,path+"1")
	sub(l,"")
	return a

def gencomb6(l=16):
	g = idgen()
	a = {}
	def sub(l,path):
		if l>3:		sub(l-1,path+"0")
		elif l==3:	a[next(g)]=path+"0"
		else:		raise Exception("a")

		if l>=6:	sub(l-3,path+"1")
		elif l>=3:	a[next(g)]=path+"1"
		else:		raise Exception("b")
	sub(l,"")
	return a

##############################################################################

class turboblock:
	def __init__(self,pilot,sync1,sync2,zero,one,pilotlen,pause):
		self.pilot = pilot
		self.sync1 = sync1
		self.sync2 = sync2
		self.zero = zero
		self.one = one
		self.pilotlen = pilotlen
		self.pause = pause
		self.bytes = ""

	def data(self,data):
		self.bytes = self.bytes + data

	def __str__(self):
		bytelen = len(self.bytes)
		data=pack("<BHHHHHHBHHB",0x11,self.pilot,self.sync1,self.sync2,
				self.zero,self.one,self.pilotlen,8,self.pause,
						bytelen&0xffff,bytelen>>16)
		return data+self.bytes

##############################################################################

class FletchCRC:
	def __init__(self):
		self.lo = 1
		self.hi = 1
		self.crc = 0xffff

	def add(self,buf):
		(lo,hi)=(self.lo,self.hi)
		for b in buf:
			lo = lo+crcvals[b] #(b%255)
			lo = (lo&0xff)+(lo>>8)

			hi = hi+lo
			hi = (hi&0xff)+(hi>>8)

			#print "%02X -> %02X:%02X"%(b,lo,hi)
		(self.lo,self.hi)=(lo,hi)

	def value(self):
		cb0 = 255-((self.lo+self.hi)%255)
		cb1 = 255-((self.lo+cb0)%255)
		return pack("BB", cb0,cb1)

##############################################################################

class fastblock:
	def __init__(self,comb,pilot,sync1,sync2,zero,one,pilotlen,pause):
		self.comb = comb
		self.pilot = pilot
		self.sync1 = sync1
		self.sync2 = sync2
		self.zero = zero
		self.one = one
		self.pilotlen = pilotlen
		self.pause = pause
		self.pp = []
		self.crc = FletchCRC()

	def pulses(self,pulses):
		bits = "".join(pulses)
		self.pp.append(bits)
		return self

	def dosymbols(self, s):
		self.crc.add(s)
		return self.pulses([self.comb[e] for e in s])

	def dobytes(self, s):
		return self.dosymbols([ord(e) for e in s])

	def data(self,data):
		self.dobytes(data)

	def __str__(self):
		bits="".join(self.pp)
		bytelen = (len(bits)+7)/8
		bitlen = ((7+len(bits))&7)+1
		bitextra = 8-bitlen
		bits = bits + bitextra*'0'
	
		data=pack("<BHHHHHHBHHB",0x11,self.pilot,self.sync1,self.sync2,
				self.zero,self.one,self.pilotlen,bitlen,self.pause,
						bytelen&0xffff,bytelen>>16)

		while len(bits)>0:
			(b,bits)=(bits[:8],bits[8:])
			data = data + chr(int(b,2))
		return data

	def header(self, sync1, sync2, addr, length):
		self.dobytes(pack("<BBHH",sync1,sync2,addr,length))
		self.dobytes(self.crc.value())

	def footer(self):
		self.dobytes(self.crc.value())
		self.dobytes(chr(0))	# force data to be flushed

##############################################################################

class CPC_CRC:
	def __init__(self):
		self.crc = 0xffff

	def add(self,buf):
		aux = self.crc
		for b in buf:
			aux = aux ^ (ord(b)<<8)
			for i in xrange(0,8):
				if (aux & 0x8000)==0:
					aux = aux<<1
				else:
					aux = (aux<<1) ^ (4129+65536)
			#print "%02X -> %04X"%(ord(b),aux)
		self.crc = aux

	def value(self):
		return pack(">H",self.crc ^ 0xffff)

##############################################################################
#
# note that addr increases on each block, length is generally 0x800 (2048) until
# the last block, totallen is the total file size
#
# type 2 = binary

def CPC_Header(name,block,length,typ=2,last=True,addr=0,runaddr=0,totallen=None):
	name=(name.upper()+(chr(0)*16))[:16]

	if last: lastb=0xff
	else: lastb=0
	if block==1: firstb=0xff
	else: firstb=0
	if totallen==None: totallen=length

	rest=pack("<BBBHHBHH",block,lastb,typ,length,addr,firstb,totallen,runaddr)
	return name+rest

##############################################################################

class cdtfile:
	def __init__(self,halfpulselen):
		self.out=[]
		self.header()
#		self.pause(250)
		self.halfpulselen=halfpulselen
		#self.comb=genfastblock()
		self.comb=gencomb6()

	def header(self):
		self.out.append('ZXTape!'+pack("BBB",26,1,10))
		return self

	def pause(self,ms):
		self.out.append(pack("<BH",0x20,ms))
		return self

	def turboblock(self,pause=1000,pilot=2168,sync1=667,sync2=735,zero=855,one=1710,pilotlen=8063):
		g=turboblock(pilot,sync1,sync2,zero,one,pilotlen,pause)
		self.out.append(g)
		return g

	def cpcblock(self,sync,data,pause=1000,zero=15*79,one=30*79,pilotlen=4096):
		g=turboblock(one,zero,zero,zero,one,pilotlen,pause)
		self.out.append(g)
		modlen = len(data)&0xff
		if len(data)==0 or modlen!=0:
			data = data + chr(0)*(256-modlen)
		g.data(chr(sync))
		while len(data)>0:
			blk = data[:256]
			data = data[256:]
			g.data(blk)

			crc=CPC_CRC()
			crc.add(blk)
			g.data(crc.value())
		g.data(chr(0xff)*4)
		return self

	def cpcfilefast(self,name,typ,data,addr,runaddr=0,pause=1000,zero=15*79,one=30*79,pilotlen=4096):
		self.cpcfile(name,typ,data,addr,runaddr,pause,8*79,16*79,pilotlen)

	def cpcfile(self,name,typ,data,addr,runaddr=0,pause=1000,zero=15*79,one=30*79,pilotlen=4096):
		b=1
		totallen=len(data)
		while len(data)>2048:
			self.cpcblock(44,CPC_Header(name,b,2048,typ,False,addr,runaddr,totallen))
			self.cpcblock(22,data[:2048])
			data=data[2048:]
			addr=addr+2048
			b=b+1
		self.cpcblock(44,CPC_Header(name,b,len(data),typ,True,addr,runaddr,totallen),0,zero,one,pilotlen)
		self.cpcblock(22,data,pause,zero,one,pilotlen)

	def fastblock(self,pause=1000,pilotlen=200):
		dpl =length_to_tstates(self.halfpulselen)
		dpl3=length_to_tstates(self.halfpulselen*3)
		dpl6=length_to_tstates(self.halfpulselen*6)
		g=fastblock(self.comb,dpl6,dpl,dpl,dpl,dpl3,pilotlen,pause)
		self.out.append(g)
		return g

	def fastpalette(self,sync1,sync2,pal,pause=0,pilotlen=200):
		pal2=[0x40|(p&0x1f) for p in pal]
		if len(pal)<=2: m=2
		elif len(pal)<=4: m=1
		else: m=0

		fast=self.fastblock(pause,pilotlen)
		fast.header(sync1,sync2,0x0f,1+len(pal2))
		fast.dosymbols([0x8c+m]+pal2)
		fast.footer()

	def write(self,dst):
		f = open(dst, "wb")
		for block in self.out:
			f.write(str(block))
		f.close()

##############################################################################

class mainfile:
	def __init__(self,cycles_per_line):
		self.cycles_per_line=cycles_per_line
		self.cdt = cdtfile(cycles_per_line * DEFAULT_NUM_LINES)
		self.sync1=1
		self.sync2=0
		self.pal=[]
		self.short = False;

	def loader(self,name,display,addr=0x8000,exaddr=0x8000):
		i = open(name,"rb")
		s = i.read()
		i.close()
		self.cdt.pause(250).cpcfile(display,2,s,addr,exaddr)
		return self

	def get_data_as_blocks(self,name,addr,blksz=BLOCK_SIZE):
		i = open(name,"rb")
		s = i.read()
		i.close()
		return compressor(addr).encode(s,blksz)

	def load_data(self,name,addr,blksz=BLOCK_SIZE):
		i = open(name,"rb")
		s = i.read()
		i.close()
		return self.datablock(addr,s,blksz)

	def exec_code(self,name,addr,blksz=BLOCK_SIZE):
		print "Adding executable code at %04x: %s"%(addr,name)
		return self.load_data(name,addr,blksz).end_multi_block(addr)

	def start_music(self,addr):
		return self.datablock(0x000c,pack("<HB",addr,1))

	def gap(self,pause=250):
		if self.sync2 <> 0:
			self.end_multi_block()
		if pause>0: self.cdt.pause(pause)
		return self

	def nextpilotlen(self):
		if self.sync2==0:
			if not self.short: return 1500
			self.short = False
		return 50
	
	def end_multi_block(self,addr=0):
		if addr <> 0:
			print "Code exec block %02x.%02x: %04X\n"%(self.sync1,self.sync2,addr)
		else:
			print "End block %02x.%02x\n"%(self.sync1,self.sync2)
		sys.stdout.flush()
		fast=self.cdt.fastblock(0,self.nextpilotlen())
		fast.header(self.sync1,self.sync2,addr,0)
		fast.footer()
		self.sync1=self.sync1+1
		self.sync2=0
		return self

	def block(self,start,end,symbs):
		print "Generating block %02x.%02x: %04X-%04X with %d symbols"%(self.sync1,self.sync2,start,end,len(symbs))
		sys.stdout.flush()
		fast=self.cdt.fastblock(0,self.nextpilotlen())
		fast.header(self.sync1,self.sync2,start,(end-start)&0xffff)
		fast.dosymbols(symbs)
		fast.footer()
		self.sync2=self.sync2+1
		if self.sync2==256:
			self.sync1=self.sync1+1
			self.sync2=0
		return self

	def blocks(self,blocks):
		for (start,end,symbs) in blocks:
			self.block(start,end,symbs)
		return self

	def palette(self,pal):
#		if self.pal <> pal:
		if len(self.pal) <> len(pal):
			same = False
		else:
			same = True
			for (a,b) in zip(self.pal,pal):
				if a<>b: same=False

		if not same:
			pal2=[0x40|(p&0x1f) for p in pal]
			if len(pal)<=2: m=2
			elif len(pal)<=4: m=1
			else: m=0

			self.block(0xf,0x10+len(pal2),[0x8c+m]+pal2)
			self.pal = pal
		return self

	def datablock(self,addr,s,blksz=BLOCK_SIZE):
		blocks=list(compressor(addr).encode(s,blksz))
		self.blocks(blocks)
		return self

	def dataraw(self,addr,s):
		return self.blocks( [(addr,addr+len(s),[ord(c) for c in s])] )

	def write(self,dst):
		print "Writing CDT file %s"%(dst)
		self.cdt.write(dst)
		return self
		

#	file.loader("","BLITZER pre-"+chr(0xb0),0x8000,0x8000)

##############################################################################

class compressor:
	def __init__(self,addr,prev=""):
		self.buf=""
		self.length=0
		self.cands={}
		self.addr=addr
		self.prev=prev
		#print "prev",len(self.prev)

	def range(self,outp,curp):
		c=0
		while outp<self.length and c<255:
			if self.buf[outp]<>self.buf[curp]: return c
			(outp,curp,c)=(outp+1,curp+1,c+1)
		return c

	def rangeprev(self,outp,curp):
		c=0
		lp=len(self.prev)
		while outp<self.length and curp<lp and c<255:
			if self.buf[outp]<>self.prev[curp]: return c
			(outp,curp,c)=(outp+1,curp+1,c+1)
		return c

	def maxrange_rev(self,outp,cand):
		(best,pos)=(0,0)
		maxp=self.length-outp
		if maxp>255: maxp=255
		for i in reversed(sorted(cand)):
			if i>=outp: continue
			if best>=maxp: return (best,pos)
			#print outp,i,best,pos
			c=self.range(outp,i)
			if best>=255 and c>=255 and i>pos: return (255,i) #(best,pos)=(255,i)
			if c>=best: (best,pos)=(c,i)
		return (best,pos)

	def maxrange(self,outp,cand):
		(best,pos)=(0,0)
		for i in sorted(cand):
			if i>=outp: break
			c=self.range(outp,i)
			#if best>=255 and c>=255 and i>pos: return (255,i) #(best,pos)=(255,i)
			if c>=best: (best,pos)=(c,i)
		return (best,pos)

	def maxrange_forward_to_prev(self,outp,cand):
		(best,pos)=(0,0)
		lp = len(self.prev)
		for i in sorted(cand):
			if i<=outp: continue
			if i>=lp: break
			c=self.rangeprev(outp,i)
			if c>=best: (best,pos)=(c,i)
		return (best,pos)

	def updatecands(self):
		self.cands={}
		for i in xrange(0,self.length-2):
			candidx=256*ord(self.buf[i])+ord(self.buf[i+1])
			try:
				cand=self.cands[candidx]
				cand.append(i)
			except:
				#cand=[]
				self.cands[candidx]=[i]

	def maxjump(self,idx):
		m=min(self.length,max(idx,len(self.prev)) )#,idx+255)
		for i in xrange(idx,m):
			if self.buf[i] <> self.prev[i]: return i-idx
		return m-idx

	def encode(self,buf,splitlen=65536):
		outp=self.length		# start encoding from previous
		self.buf=self.buf+buf
		self.length=self.length+len(buf)
		self.updatecands()

		outlist=[]
		out=[]
		rpt=[]
		start=outp

		while outp<self.length:
			jump=self.maxjump(outp)

			# don't ever start encoding with a jump!
			if outp==start and jump>0:
				start = start+jump
				outp = outp+jump
				continue

			# don't ever end with jump
			if outp+jump==self.length:
				break


			if len(out)>=splitlen:
				yield ((self.addr+start)&0xffff,(self.addr+outp)&0xffff,out)
				#outlist.append(((self.addr+start)&0xffff,(self.addr+outp)&0xffff,out))
				start=outp
				out=[]
				rpt=[]
			try:
				candidx=256*ord(self.buf[outp])+ord(self.buf[outp+1])
				cand=self.cands[candidx]
				if len(cand)>1000:
					(best,pos)=self.maxrange_rev(outp,cand)
				else:
					(best,pos)=self.maxrange(outp,cand)
			except:
				(best,pos)=(-1,-1)
				#raise

#			try:
#				(best2,pos2)=self.maxrange_forward_to_prev(outp,cand)
#				if best2>best+1:
#					(best,pos)=(best2,pos2)
#			except:
#				pass

			if best>255: best=255		# clamp to max search range
			skip=self.range(outp+1,outp)		# determine rle length

			ofshi = ((pos-outp)&0xff00)>>8
			ofslo =  (pos-outp)&0xff

			#print outp,jump

			if jump>=255 or (jump>2 and (jump>best and jump>skip)):
				if jump>255:
					#out.append(0x109)
					out.append(276)
					out.append(jump&0xff)
					out.append((jump&0xff00)>>8)
					outp=outp+jump
				else:
					#out.append(0x107)
					out.append(275)
					out.append(jump)
					outp=outp+jump
			elif best>=3 and skip>best:	# RLE is best
				out.append(ord(self.buf[outp]))
				#out.append(0x105)
				rpt.append((outp,len(out),2))
				out.append(273)
				out.append(skip)
				outp = outp+skip+1
			elif best==3 and outp-pos>=256:
				out.append(ord(self.buf[outp]))
				outp = outp+1
			elif best<3:
				out.append(ord(self.buf[outp]))
				outp = outp+1
			elif best<11:
				if outp-pos<256:
					#out.append(0x100+4*best)
					rpt.append((outp,len(out),2))
					out.append(0x100+(best-3)*2)
					out.append(ofslo)
					outp = outp+best
				else:
					#out.append(0x102+4*best)
					rpt.append((outp,len(out),3))
					out.append(0x101+(best-3)*2)
					out.append(ofslo)
					out.append(ofshi)
					outp = outp+best
			elif outp-pos==1:
				#out.append(0x101)
				rpt.append((outp,len(out),2))
				out.append(273)
				out.append(best)
				outp = outp+best
			else:
				if outp-pos<256:
					#out.append(0x101)
					rpt.append((outp,len(out),3))
					out.append(272)
					out.append(best)
					out.append(ofslo)
					outp = outp+best
				else:
					#out.append(0x103)
					rpt.append((outp,len(out),4))
					out.append(274)
					out.append(best)
					out.append(ofslo)
					out.append(ofshi)
					outp = outp+best
		#outlist.append(((self.addr+start)&0xffff,(self.addr+outp)&0xffff,out))

		#return outlist
		yield ((self.addr+start)&0xffff,(self.addr+outp)&0xffff,out)

	def copymem(self,src,dst,length):
		out=[]
		olen=length
		ofs=(src-dst)&0xffff
		ofslo=ofs&0xff
		ofshi=(ofs>>8)&0xff
		while length>255:
			out.append(274)		# copy(rpt8,ofs16)
			out.append(255)		# rpt=255
			out.append(ofslo)
			out.append(ofshi)
			length = length - 255
		if length>0:
			out.append(274)		# copy(rpt8,ofs16)
			out.append(length)
			out.append(ofslo)
			out.append(ofshi)
		yield (dst,dst+olen,out)

##############################################################################

def generate_compressed(src,addr):
	i = open(src,"rb")
	s = i.read()
	i.close()

	comp = compressor(addr)
	return comp.encode(s,312)

def process_compressed(src,dst,halfpulselen,addr=0xc000,sync1=0x12):
	emit_symbols(dst,generate_compressed(src,addr),halfpulselen,sync1)

def process_copy(src,dst,halfpulselen,addr=0xc000,sync1=0x12):
	comp=compress
	emit_symbols(dst,generate_compressed(src,addr),halfpulselen,sync1)

##############################################################################

def emit_symbols(dst,blocks,halfpulselen,sync1):
	cdt=cdtfile(halfpulselen)
	cdt.pause(500)
	pilots=1000
	block=0
	bksz=300
	tsyms=0
	for (start,end,symbs) in blocks:
		print "Generating block %2d: %04X-%04X with %d symbols"%(block,start,end,len(symbs))
		fast=cdt.fastblock(0,pilots)
		fast.header(sync1,block,start,(end-start)&0xffff)
		fast.dosymbols(symbs)
		fast.footer()
		block=block+1
		pilots=50
		tsyms=tsyms+len(symbs)
	cdt.write(dst)

	print "Total %d symbols"%(tsyms)

##############################################################################

def process_uncompressed(src,dst,halfpulselen):
	i = open(src,"rb")
	s = i.read()
	i.close()

	cdt=cdtfile(halfpulselen)
	cdt.pause(500)
	pilots=1000
	block=0
	addr=0xc000
	bksz=512 #256
	while len(s)>0:
		d=s[:bksz]
		s=s[bksz:]
		fast=cdt.fastblock(0,pilots)
		fast.header(0x12,block,addr,len(d))
		fast.data(d)
		fast.footer()
		pilots=50
		block=block+1
		addr=addr+len(d)
	cdt.write(dst)

##############################################################################

if __name__ == "__main__":
        if len(sys.argv)<2 or len(sys.argv)>4:
                print "usage: %s source.bin [dest.cdt]"%(sys.argv[0])
                sys.exit(1)

        src = sys.argv[1]
        if len(sys.argv)>=3:
                dst = sys.argv[2]
        else:
                if src[-4:] == '.bin':
                        dst = src[:-4] + '.cdt'
                else:
                        dst = src + '.cdt'
	if len(sys.argv)>=4:
		cyles_per_line=int(sys.argv[3])
	else:
		cyles_per_line=DEFAULT_CYCLE_COUNT

	halfpulselen=cyles_per_line * DEFAULT_NUM_LINES
        process_uncompressed(src,dst,halfpulselen)

