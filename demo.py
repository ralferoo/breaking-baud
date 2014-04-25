#!/usr/bin/python

testing = False
#testing = True

(lk_images,term_images,rose_images) = (57,16,10)
#(lk_images,term_images,rose_images) = (1,1,1)


import math
import random
import sys
from struct import pack
from struct import unpack
from cdt import *
from screens import *

from PIL import Image
from intro import intro, outro, post_intro
from time import gmtime

##############################################################################

player_base = 0x1000
text_base   = 0x2800
applet_base = 0x3800
song_data   = 0x4000
song2_data  = 0x5000
font_base   = 0x6000
text_out_base = 0x7000

##############################################################################

def half(im):
	(w,h)=im.size
	return im.resize( (w>>1,h) )

class music_switch():
	def __init__(self,cdt,player,music):
		self.cdt=cdt
		self.player=player
		self.music=music
		self.addr=None

	def block(self):
		try:
			try:	(start,end,symbs)=next(self.player)
			except:	(start,end,symbs)=next(self.music)
			self.cdt.block(start,end,symbs)
		except:
			pass
			#self.first()

	def first(self):
		if self.addr == None:
			for (start,end,symbs) in self.player:
				self.cdt.block(start,end,symbs)
			for (start,end,symbs) in self.music:
				self.cdt.block(start,end,symbs)

			self.addr = song_data
			self.cdt.end_multi_block(player_base)	# start music
	
	def load(self,name):
		if self.addr == song2_data:
			self.addr = song_data
		else:
			self.addr = song2_data

		print "Loading %s at address %04x"%(name,self.addr)
		self.cdt.load_data("music/%s-%04x.bin"%(name, self.addr), self.addr)
		
	def play(self):
		self.cdt.start_music(self.addr)


def makedemo(dst,addfile,cycles_per_line):
	cdt=mainfile(cycles_per_line)
	writer=screen_writer(cdt,"compress.pickle")

#	for i in xrange(0,256):
#		cdt.block(0xc000+i,1,[i])
#	cdt.gap(1000)

	name="build/breaking_baud-%2d.exe"%(cycles_per_line)
	#t=gmtime()
	#cdt.loader(name,"BROKEN BAUD %04d-%02d-%02d"%(t.tm_year,t.tm_mon,t.tm_mday),0x8000,0x8000)
	cdt.loader(name,"BREAKING BAUD",0x8000,0x8000)
	cdt.gap(10)

	musicplayer ="build/arkos_player-%d.bin"%(cycles_per_line) 
	music_block_size = 94

	started = False
	player=cdt.get_data_as_blocks(musicplayer, player_base,music_block_size)
	music=cdt.get_data_as_blocks("music/hardstyle-4000.bin", 0x4000, music_block_size)
	play = music_switch(cdt,player,music)

	# send the intro sequence with music interleaved
	pen=True
	if True or not testing:
		idx = 0
		gen=intro()
		for i in gen:
			if i <> None:
				print "Creating intro image %d"%idx
				try: i.save("build/intro-%02d.gif"%idx)
				except: pass
				writer.add("Intro %d"%idx,i,1000,False)
				idx = idx+1
			else:
				if pen:
					cdt.exec_code("build/remove_pen1-%d.bin"%(cycles_per_line), applet_base)
					writer.reset("Intro %d"%idx,next(gen))
					pen = False
				else:
					play.first()
			
			# interleave music
			play.block()
	
		# send remaining music
		play.first()

		play.load("littlesailor")
		cdt.gap(2000)
		post_intro(cdt,writer,text_base,font_base,text_out_base)
		#writer.present(1000)

#		cdt.write(dst)
#		writer.save()
#		sys.exit(0)

	if not testing:
		cdt.exec_code("build/normal_to_overscan-%d.bin"%(cycles_per_line), applet_base)
		play.play()
		for i in xrange(1,lk_images+1): #74+1, ralf:53+1, 4ab:72+1, 5: 57+1
			f="sequence/lightkeeper/%02d.gif"%i
			print "Adding image %s"%(f)
			writer.add_overscan(f,Image.open(f),BLOCK_SIZE,False)
			if i>=54: cdt.gap(0) #4ab:70, 5:54
			#writer.add(f,Image.open(f).crop((64,72,384,272)))

		cdt.gap(5000)
		#cdt.load_data("music/cr4sh-5000.bin", 0x5000)
		play.load("cr4sh")
		writer.present_overscan(0)
		#cdt.start_music(0x5000)
		play.play()
		cdt.gap(500)
		cdt.exec_code("build/overscan_to_wideonly-%d.bin"%(cycles_per_line), applet_base)

	if not testing:
		for i in xrange(1,term_images+1): #16+1
			f="sequence/bin_renderin/%02d.gif"%i
			print "Adding image %s"%(f)
			writer.add_wideonly(f,Image.open(f),BLOCK_SIZE,False)
			cdt.gap(0)
		if True:
			cdt.gap(5000)
			play.load("bonito")
			#cdt.load_data("music/bonito-4000.bin", 0x4000)
			writer.present_wideonly(0)
			#cdt.start_music(0x4000)
			play.play()
			cdt.gap(500)
			cdt.exec_code("build/wideonly_to_normal-%d.bin"%(cycles_per_line), applet_base)
	

	if not testing:
		for i in xrange(1,rose_images+1):
			f="sequence/rose/%02d.gif"%i
			print "Adding image %s"%(f)
			writer.add(f,half(Image.open(f)),BLOCK_SIZE,False)
			cdt.gap(0)

		if True:
			cdt.gap(5000)
			play.load("seagulls")
			#cdt.load_data("music/remember david-5000.bin", 0x5000)
			writer.present(0)
			#cdt.start_music(0x5000)
			play.play()
			cdt.gap(500)
	
	# send the outtro sequence with music interleaved
	if True:
		idx = 0
		outro(cdt,writer,text_base,font_base,text_out_base)
		cdt.gap(10000)
		play.load("silence")
		play.play()
		cdt.gap(1000)
		cdt.exec_code("build/reboot-%d.bin"%(cycles_per_line), applet_base)
	
	cdt.write(dst)
	writer.save()

##############################################################################

if __name__ == "__main__":
        if len(sys.argv)<2 or len(sys.argv)>3:
                print "usage: %s dest.cdt [speed]"%(sys.argv[0])
                sys.exit(1)

	dst = sys.argv[1]
	if len(sys.argv)>=3:
		cycles_per_line=int(sys.argv[2])
	else:
		cycles_per_line=DEFAULT_CYCLE_COUNT

        makedemo(dst,True,cycles_per_line)
