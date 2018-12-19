;^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^^%^%^%^%^%^%^%
;
; GRIM
;
;
;^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^%^^%^%^%^%^%^%^%

	SECTION	game,CODE_P

;=============================================================================


	INCDIR	"include:"
	INCLUDE	"hardware/cia.i"
	INCLUDE	"hardware/custom.i"
	INCLUDE	"hardware/dmabits.i"
	INCLUDE	"hardware/intbits.i"
	
_custom		equ	$dff000
_ciaa		equ	$bfe001
_ciab		equ	$bfd000

;=============================================================================


;#+=-  Screen  -=+#

SCR_WIDTH	= 320
SCR_HEIGHT	= 256

TILE_WIDTH	= 8
TILE_HEIGHT	= 8

BPL		= 1		;amount of bitlpans (1-8)
BROW		= SCR_WIDTH/8	;bytes per row

MODULO		= (BPL-1)*BROW	;modulo rawblit

KEY_ESC		= $45		;rawkey code
KEY_LEFT	= $4f
KEY_RIGHT	= $4e
KEY_UP		= $4c
KEY_DOWN	= $4d

KEY_A		= $20


HERO_INIT_X	= 160
HERO_INIT_Y	= 240

KEY_INIT_X	= 320-48
KEY_INIT_Y	= 16
;=============================================================================
;; M A C R O S
;

WAITVB:	MACRO
.1\@		btst	#0,(_custom+vposr+1)
		beq	.1\@
.2\@		btst	#0,(_custom+vposr+1)
		bne	.2\@
	ENDM


FUNCT:	MACRO

		lea	(g_pFnc,pc),a0
		lea	(\1,pc),a1
		move.l	a1,(a0)

	ENDM

;=============================================================================

start:

		lea	(oldstack,pc),a0
		move.l	a7,(a0)

		bsr	TakeOS
		

		lea	_custom,a5

		bsr	Init

		move.l	#cpList,(cop1lc,a5)
		move.w	#0,(copjmp1,a5)
		move.w	#$87f0,(dmacon,a5)

		FUNCT	TitleInit



mainLoop:
		WAITVB

		move.l	(g_pFnc,pc),a0
		jsr	(a0)


.mouse		btst	#6,$bfe001
		beq	Exit

		lea	bKeytab,a0
		tst.b	($45,a0)
		bne	Exit
		
		bra	mainLoop

Exit:		
		bra	TakeOS\.restore


g_pFnc:		dc.l	0

;=============================================================================

TitleInit:
	;set empty sprites
		bsr	SetEmptySprites

	;clean screen
		bsr	ClearScreen

	;set colors
		move.w	#$000,$dff180
		move.w	#$550,$dff182
	
	;show title

		lea	.msg,a0
		lea	screen,a1
		bsr	showMsg

		FUNCT	TitleLoop

		rts

.msg:		dc.b	"grim",0
	EVEN
	
;=============================================================================

TitleLoop:

		lea	(bKeytab,pc),a0
		tst.w	(KEY_A,a0)
		beq	.exit

		sf	(KEY_A,a0)

		FUNCT	GameInit

.exit		rts


;=============================================================================

GameInit:

	;reset level
		move.w	#0,wLevelNumber
	
	;reset hero amount
	
		move.w	#3,wHeroLives
		
	;reset amount of tiles
	
		move.w	#50,wTilesNumber

	;set colors
		move.w	#0,$dff180
		move.w	#$0555,$dff182

	;set spr colors
		move.w	#$0,$dff1a0
		move.w	#$48f,$dff1a2
		move.w	#$d9,$dff1a4
		move.w	#$a11,$dff1a6
		move.w	#$f48,$dff1aa



		move.w	clxdat(a5),d0	;without this not works!!!

		bsr	NextLevel

		FUNCT	GameLoop
	
		rts

;=============================================================================

GameLoop:

		bsr	GetInputs
		
	;logic
		tst.w	(wLeft)
		beq	.right
		
		sub.w	#1,wHeroX
		
.right		tst.w	(wRight)
		beq	.up
		
		add.w	#1,wHeroX

.up		tst.w	(wUp)
		beq	.down
		
		sub.w	#1,wHeroY

.down		tst.w	(wDown)
		beq	.other
		
		add.w	#1,wHeroY
		
.other
		bsr	UpdateHero

		move.w	clxdat(a5),d0
		move.w	d0,d1
		and.w	#$2,d0	; touch the tile ?
		beq	.key

	;jmp to game over
		FUNCT	GameOver



.key		and.w	#$200,d1
		beq	.exit

		bsr	SetEmptySprites

		WAITVB

		bsr	NextLevel

.exit		rts

;=============================================================================

NextLevel:
		add.w	#1,wLevelNumber
		
		add.w	#5,wTilesNumber
		
		bsr	ClearScreen
		
		bsr	RenderLevel
	
	;set hero
		move.w	#HERO_INIT_X,wHeroX
		move.w	#HERO_INIT_Y,wHeroY
		bsr	ShowHero
		bsr	UpdateHero
		
	;set key
		move.w	#KEY_INIT_X,wKeyX
		move.w	#KEY_INIT_Y,wKeyY
		bsr	ShowKey
		bsr	UpdateKey

	;set info
		bsr	UpdateLivesInfo
		bsr	UpdateLevelInfo

		bsr	ShowInfo
		bsr	UpdateInfo

		rts

;=============================================================================

GameOver:

		FUNCT	TitleInit


		bsr	SetEmptySprites

	; clean screen
		bsr	ClearScreen

	; show game over msg
		bsr	ShowGameOverMsg

		moveq	#120,d0		
		
.loop		WAITVB

		lea	bKeytab,a0
		tst.b	($45,a0)
		bne	.wait

		btst	#6,$bfe001
		beq	.exit

		dbf	d0,.loop
		rts
		

.wait		tst.b	($45,a0)
		beq	.exit
		bra	.wait

.exit		rts
		
;=============================================================================

ClearScreen:
		lea	screen,a0
		move.l	#BPL*BROW*SCR_HEIGHT/4,d0
		moveq	#0,d1

.clear		move.l	d1,(a0)+
		subq.l	#1,d0
		bne	.clear

		rts

;=============================================================================

ShowGameOverMsg:

		lea	.msg,a0
		lea	screen,a1
		bsr	showMsg

		rts

.msg		dc.b	"game over",0
	EVEN

;=============================================================================

RenderLevel:

		move.w	wTilesNumber,d2
		lea	lTileTable,a0

.rloop		bsr	Rnd
		asl.l	#2,d0
		move.l	(a0,d0.w),a1

		moveq	#8-1,d0
.copy		move.b	#$ff,(a1)
		add.l	#BROW,a1
		dbf	d0,.copy
		dbf	d2,.rloop

		rts

;=============================================================================

ShowHero:
		lea	cpSprite,a0
		move.l	#sprHero,d0
		move.w	d0,(6,a0)
		swap	d0
		move.w	d0,(2,a0)
		rts
		
;=============================================================================

UpdateHero
		lea	sprHero,a0
		move.w	(wHeroX,pc),d0
		move.w	(wHeroY,pc),d1
		moveq	#8,d2
		bsr	SetSprite
		rts

;=============================================================================

ShowKey:
		lea	cpSprite,a0
		move.l	#sprKey,d0
		move.w	d0,(22,a0)
		swap	d0
		move.w	d0,(18,a0)
		rts
		
;=============================================================================

UpdateKey
		lea	sprKey,a0
		move.w	(wKeyX,pc),d0
		move.w	(wKeyY,pc),d1
		moveq	#8,d2
		bsr	SetSprite
		rts

;=============================================================================

ShowInfo:
		lea	cpSprite,a0
		move.l	#sprInfo,d0
		move.w	d0,(30,a0)
		swap	d0
		move.w	d0,(26,a0)
		rts

;=============================================================================

INFO_X	= 304
INFO_Y	= 0
INFO_H	= 26

UpdateInfo:
		lea	sprInfo,a0
		move.w	#INFO_X,d0
		move.w	#INFO_Y,d1
		moveq	#INFO_H,d2
		bsr	SetSprite
		rts


;=============================================================================

UpdateLevelInfo:

		moveq	#0,d0
		move.w	wLevelNumber,d0
		moveq	#0,d1

.calc		cmp.w	#9,d0
		ble	.do
		addq.w	#1,d1
		sub.w	#10,d0
		bra	.calc

		
	; d0
	; d1
.do
		lea	sprLev,a0
		lea	digits,a1

		asl.w	#3,d1
		add.l	d1,a1
		moveq	#8-1,d1
.copy1		move.b	(a1)+,(a0)
		addq.l	#4,a0
		dbf	d1,.copy1

		lea	sprLev+1,a0
		lea	digits,a1

		asl.w	#3,d0
		add.l	d0,a1
		moveq	#8-1,d0
.copy2		move.b	(a1)+,(a0)
		addq.l	#4,a0
		dbf	d0,.copy2
		
		rts

;=============================================================================

UpdateLivesInfo:

		lea	sprInfo+5,a0
		lea	digits,a1

		moveq	#0,d0
		move.w	wHeroLives,d0
		asl.w	#3,d0
		add.l	d0,a1
		moveq	#8-1,d0
.loop		move.b	(a1)+,(a0)
		addq.l	#4,a0
		dbf	d0,.loop


		rts
;=============================================================================

GetInputs:
		moveq	#0,d0
		moveq	#0,d1
		moveq	#0,d2
		moveq	#0,d3
		lea	(bKeytab,pc),a0
		tst.b	(KEY_LEFT,a0)
		sne	d0
		tst.b	(KEY_RIGHT,a0)
		sne	d1
		tst.b	(KEY_UP,a0)
		sne	d2
		tst.b	(KEY_DOWN,a0)
		sne	d3
		
		lea	(wDown+2,pc),a0
		movem.w	d0-d3,-(a0)
		rts

wLeft:	dc.w	0
wRight	dc.w	0
wUp:	dc.w	0
wDown:	dc.w	0

;=============================================================================

Init:
	;set random seed

		move.w	(vhposr,a5),d0
		move.l	d0,lSeed

	;set PORTS int
		move.l	(vectorbase,pc),a0
		lea	(IntPORTS,pc),a1
		move.l	a1,($68,a0)
	
		move.b	#CIAICRF_SETCLR|CIAICRF_SP,(ciaicr+_ciaa)
		tst.b	(ciaicr+_ciaa)
		and.b	#~(CIACRAF_SPMODE),(ciacra+_ciaa)
		move.w	#INTF_PORTS,(intreq+_custom)
		move.w	#INTF_SETCLR|INTF_INTEN|INTF_PORTS,(intena+_custom)

	;sprites
		moveq	#16-1,d0
		move.w	#sprpt,d1
		lea	cpSprite,a0
		move.l	#emptySprite,d2
.sprites	move.w	d1,(a0)+
		swap	d2
		move.w	d2,(a0)+
		addq.w	#2,d1
		dbf	d0,.sprites

	;bitplanes
		moveq	#BPL*2-1,d0
		move.w	#bplpt,d1
		move.l	#screen,d2
		lea	cpBpl,a0
.planes		move.w	d1,(a0)+
		swap	d2
		move.w	d2,(a0)+
		addq.w	#2,d1
		dbf	d0,.planes

	;do look up table for tiles
		lea	lTileTable,a0
		move.l	#screen,d1
		moveq	#SCR_HEIGHT/TILE_HEIGHT-1,d3

.line		moveq	#SCR_WIDTH/TILE_WIDTH-1,d2
		move.l	d1,d0
.loop		move.l	d0,(a0)+
		addq.l	#TILE_WIDTH/8,d0
		dbf	d2,.loop
		add.l	#BPL*BROW*TILE_HEIGHT,d1
		dbf	d3,.line

		rts

;=============================================================================

SetEmptySprites:

		moveq	#16-1,d0
		move.l	#emptySprite,d1
		lea	cpSprite,a0
.loop		swap	d1
		move.w	d1,(2,a0)
		addq.l	#4,a0
		dbf	d0,.loop
		rts

;=============================================================================

start_x	equ	127
start_y	equ	44

; a0 - spr adr
; d0 - x
; d1 - y
; d2 - height of spr
;
SetSprite:

		add.w	#start_x,d0
		add.w	#start_y,d1
		move.w	d1,d4
		moveq	#0,d3

		move.b	d1,(a0)
		lsl.w	#8,d4
		addx.b	d3,d3


		add.w	d2,d1
		move.b	d1,(2,a0)
		lsl.w	#8,d1
		addx.b	d3,d3

		lsr.w	#1,d0
		addx.w	d3,d3	

		move.b	d0,(1,a0)
		move.b	d3,(3,a0)

		rts

;=============================================================================

;in	-
;out	d0 - rnd ( 0 - SCR_HEIGHT/TILE*SCR_WIDTH/TILE_WIDTH )
;
;used	d0,d1
;

Rnd:		bsr	Random
		and.l	#$ffff,d0
		move.w	#SCR_HEIGHT/TILE_HEIGHT*SCR_WIDTH/TILE_WIDTH,d1	;max
		mulu	d1,d0
		asr.l	#8,d0
		asr.l	#8,d0
		and.l	#$ffff,d0
		rts

Random
		move.l	(lSeed,pc),d0
		move.l	d0,d1
		asl.l	#3,d1
		sub.l	d0,d1
		asl.l	#3,d1
		add.l	d0,d1
		add.l	d1,d1
		add.l	d0,d1
		asl.l	#4,d1
		sub.l	d0,d1
		add.l	d1,d1
		sub.l	d0,d1
		addi.l	#$E60,d1
		andi.l	#$7FFFFFFF,d1
		move.l	d1,d0
		subq.l	#1,d0
		move.l	d1,d0
		move.l	d0,lSeed
		rts

;
; d2 - max
;
Rand:
		bsr	Random
		and.l	#$ffff,d0
		mulu	d2,d0
		asr.l	#8,d0
		asr.l	#8,d0
		and.l	#$ffff,d0
		rts
		
		

;=============================================================================

IntPORTS:	movem.l	d0-d1/a0-a2,-(a7)
		lea	(_custom),a0
		lea	(_ciaa),a1

	;check if keyboard has caused interrupt
		btst	#INTB_PORTS,(intreqr+1,a0)
		beq	.end
		btst	#CIAICRB_SP,(ciaicr,a1)
		beq	.end


	;read key and store him
		move.b	(ciasdr,a1),d0
		or.b	#CIACRAF_SPMODE,(ciacra,a1)
		not.b	d0
		ror.b	#1,d0
		spl	d1
		and.w	#$7f,d0
		lea	(bKeytab,pc),a2
		move.b	d1,(a2,d0.w)

.handshake
	;wait for handshake
		moveq	#3-1,d1
.wait1		move.b	(vhposr,a0),d0
.wait2		cmp.b	(vhposr,a0),d0
		beq	.wait2
		dbf	d1,.wait1

	;set input mode
		and.b	#~(CIACRAF_SPMODE),(ciacra,a1)
.end		move.w	#INTF_PORTS,(intreq,a0)
		tst.w	(intreqr,a0)
		movem.l	(a7)+,d0-d1/a0-a2
		rte



pressExit:	dc.w	0
oldstack:	dc.l	0

;=============================================================================

bKeytab		dcb.b	$80

lSeed:		dc.l	0

;--- tiles ---

wTilesNumber:	dc.w	0
lTileTable:	dcb.l	SCR_WIDTH/8*SCR_HEIGHT/8


;--- level ---

wLevelNumber:	dc.w	0


;--- hero ---
wHeroX:		dc.w	0
wHeroY:		dc.w	0
wHeroLives:	dc.w	0


;--- key ---

wKeyX:		dc.w	0
wKeyY:		dc.w	0


wExit:		dc.w	0

;=============================================================================


TakeOS:

	RSRESET
.osExecBase	rs.l	1
.gfxbase	rs.l	1
.oldview	rs.l	1
.intena		rs.w	1
.dmacon		rs.w	1
.intvertb	rs.l	1
.intports	rs.l	1
.SIZEOF		rs.b	0

;=== exec ===
.OpenLibrary	= -552
.CloseLibrary	= -414
.Forbid		= -132
.Permit		= -138
.Supervisor	= -30
;=== graphics ===
.LoadView	= -222
.WaitTOF	= -270
.WaitBlit	= -228
.OwnBlitter	= -456
.DisownBlitter	= -462

.gb_ActiView	= $22
.gb_copinit	= $26
.AFB_68010	= 0
.AttnFlags	= $128

		movem.l	d0-a6,-(sp)
		
		lea	.store(pc),a4

	;store exec base
		move.l	4.w,a6
		move.l	a6,.osExecBase(a4)

	;open graphics library
		moveq	#0,d0
		lea	.gfxname(pc),a1
		jsr	.OpenLibrary(a6)
		move.l	d0,.gfxbase(a4)
		beq.w	.errexit
		move.l	d0,a6

	;save old view
		move.l  .gb_ActiView(a6),.oldview(a4)

	;wait till blitter finish job
		jsr	.WaitBlit(a6)

	;take blitter
		jsr	.OwnBlitter(a6)

	;reset display
		sub.l	a1,a1		
		jsr	.LoadView(a6)
		jsr	.WaitTOF(a6)
		jsr	.WaitTOF(a6)

	;multitaskig off
		move.l	.osExecBase(a4),a6
		jsr	.Forbid(a6)

	;get vbr
		moveq	#0,d0
		btst.b	#.AFB_68010,.AttnFlags+1(a6)
		beq	.mc68000
		lea	.movectrap(pc),a5
		jsr	.Supervisor(a6)
.mc68000	lea	vectorbase(pc),a5
		move.l	d0,(a5)


		lea	_custom,a5

	;store 
		move.w	intenar(a5),d0
		or.w	#$c000,d0
		move.w	d0,.intena(a4)

		move.w	dmaconr(a5),d0
		or.w	#$8000,d0
		move.w	d0,.dmacon(a4)

	
		WAITVB

	;stop int & dma
		move.w	#$7fff,d0
		move.w	d0,intena(a5)
		move.w	d0,dmacon(a5)
		move.w	d0,intreq(a5)

	;Check AGA
		move.w	deniseid(a5),d0
		cmpi.b	#$f8,d0		;AGA ?
		bne.b	.no

	;Reset to ECS
		moveq	#0,d0
		move.w	d0,bplcon3(a5)
		move.w	d0,fmode(a5)
.no		


	;store int pointers
		move.l	vectorbase(pc),a0
		move.l	$6c(a0),.intvertb(a4)
		move.l	$68(a0),.intports(a4)

		movem.l	(sp)+,d0-a6
		rts


.restore	movem.l	d0-a6,-(sp)
		
		lea	.store(pc),a4
		lea	_custom,a5

		WAITVB

	;stop int & dma
		move.w	#$7fff,d0
		move.w	d0,intena(a5)
		move.w	d0,dmacon(a5)
		move.w	d0,intreq(a5)

	;restore ints pointers
		move.l	vectorbase(pc),a0
		move.l	.intvertb(a4),$6c(a0)
		move.l	.intports(a4),$68(a0)

	;restore
		move.w	.dmacon(a4),dmacon(a5)
		move.w	.intena(a4),intena(a5)
	

	;multitasking on
		move.l	.osExecBase(a4),a6
		jsr	.Permit(a6)

	;load old view
		move.l	.gfxbase(a4),a6
		move.l	.oldview(a4),a1
		jsr	.LoadView(a6)

		move.l	.gb_copinit(a6),cop1lc(a5) ; restore system clist
	;disown blitter
		jsr	.DisownBlitter(a6)

	;close graphics library
		move.l	.osExecBase(a4),a6
		move.l	.gfxbase(a4),a1
		jsr	.CloseLibrary(a6)
	
		movem.l	(sp)+,d0-a6
		rts

.errexit	moveq	#-1,d0
		rts

.movectrap	dc.l	$4e7a0801	;movec	vbr,d0
		rte


.gfxname	dc.b	"graphics.library",0
	EVEN
.store		ds.b	.SIZEOF
vectorbase	ds.l	1

;=============================================================================
;in
;a0 - msg
;a1 - scr
;
showMsg
		

.loop		move.l	a1,a2
		moveq	#0,d0
		move.b	(a0)+,d0
		beq	.exit

		sub.b	#$20,d0
		asl.w	#3,d0
		lea	fonts,a3
		add.l	d0,a3

		moveq	#8-1,d1
.copy		move.b	(a3)+,(a2)
		add.l	#BROW*BPL,a2
		dbf	d1,.copy

		addq.l	#1,a1
		bra	.loop
		

.exit		rts

;=============================================================================

fonts:	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000

	dc.b	%00011000
	dc.b	%00111100
	dc.b	%00111100
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00000000
	dc.b	%00011000
	dc.b	%00000000
	
	dc.b	%00110110
	dc.b	%00110110
	dc.b	%00110110
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	
	dc.b	%01101100
	dc.b	%01101100
	dc.b	%11111110
	dc.b	%01101100
	dc.b	%11111110
	dc.b	%01101100
	dc.b	%01101100
	dc.b	%00000000
	dc.b	%00010000
	dc.b	%01111110
	dc.b	%11010000
	dc.b	%01111100
	dc.b	%00010110
	dc.b	%11111100
	dc.b	%00010000
	dc.b	%00000000
	dc.b	%01100010
	dc.b	%01100110
	dc.b	%00001100
	dc.b	%00011000
	dc.b	%00110000
	dc.b	%01100110
	dc.b	%11000110
	dc.b	%00000000
	dc.b	%00111000
	dc.b	%01101100
	dc.b	%01101000
	dc.b	%01110110
	dc.b	%11011100
	dc.b	%11001100
	dc.b	%01110110
	dc.b	%00000000
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00110000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00011100
	dc.b	%00110000
	dc.b	%00110000
	dc.b	%00110000
	dc.b	%00110000
	dc.b	%00110000
	dc.b	%00011100
	dc.b	%00000000
	dc.b	%00111000
	dc.b	%00001100
	dc.b	%00001100
	dc.b	%00001100
	dc.b	%00001100
	dc.b	%00001100
	dc.b	%00111000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%01101100
	dc.b	%00111000
	dc.b	%11111110
	dc.b	%00111000
	dc.b	%01101100
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%01111110
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00110000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%01111110
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00000000
	dc.b	%00000010
	dc.b	%00000110
	dc.b	%00001100
	dc.b	%00011000
	dc.b	%00110000
	dc.b	%01100000
	dc.b	%01000000
	dc.b	%00000000
digits:	dc.b	%00000000
	dc.b	%01111100
	dc.b	%11001110
	dc.b	%11011110
	dc.b	%11110110
	dc.b	%11100110
	dc.b	%01111100
	dc.b	%00000000
	dc.b	%00011000
	dc.b	%00111000
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00111100
	dc.b	%00000000
	dc.b	%01111100
	dc.b	%00000110
	dc.b	%01111100
	dc.b	%11000000
	dc.b	%11000000
	dc.b	%11000000
	dc.b	%11111110
	dc.b	%00000000
	dc.b	%01111110
	dc.b	%00000110
	dc.b	%00011100
	dc.b	%00000110
	dc.b	%00000110
	dc.b	%11000110
	dc.b	%01111100
	dc.b	%00000000
	dc.b	%00110000
	dc.b	%00110010
	dc.b	%01100110
	dc.b	%11000110
	dc.b	%11111111
	dc.b	%00000110
	dc.b	%00000110
	dc.b	%00000000
	dc.b	%11111110
	dc.b	%11000000
	dc.b	%11111100
	dc.b	%00000110
	dc.b	%00000110
	dc.b	%11000110
	dc.b	%01111100
	dc.b	%00000000
	dc.b	%01111100
	dc.b	%11000000
	dc.b	%11111100
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%01111100
	dc.b	%00000000
	dc.b	%11111110
	dc.b	%00000110
	dc.b	%00001100
	dc.b	%00011000
	dc.b	%00110000
	dc.b	%00110000
	dc.b	%00110000
	dc.b	%00000000
	dc.b	%01111100
	dc.b	%11000110
	dc.b	%01111100
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%01111100
	dc.b	%00000000
	dc.b	%01111100
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%01111110
	dc.b	%00000110
	dc.b	%01111100
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00000000
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00000000
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00110000
	dc.b	%00000000
	dc.b	%00001100
	dc.b	%00011000
	dc.b	%00110000
	dc.b	%01100000
	dc.b	%00110000
	dc.b	%00011000
	dc.b	%00001100
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%01111110
	dc.b	%00000000
	dc.b	%01111110
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00110000
	dc.b	%00011000
	dc.b	%00001100
	dc.b	%00000110
	dc.b	%00001100
	dc.b	%00011000
	dc.b	%00110000
	dc.b	%00000000
	dc.b	%00111100
	dc.b	%01100110
	dc.b	%00001100
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00000000
	dc.b	%00011000
	dc.b	%00000000
	dc.b	%01111100
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11011110
	dc.b	%11011110
	dc.b	%11000000
	dc.b	%01111110
	dc.b	%00000000
	dc.b	%01111100
	dc.b	%11000110
	dc.b	%11111110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%00000000
	dc.b	%11111000
	dc.b	%11001100
	dc.b	%11111100
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11111100
	dc.b	%00000000
	dc.b	%01111100
	dc.b	%11000110
	dc.b	%11000000
	dc.b	%11000000
	dc.b	%11000000
	dc.b	%11000110
	dc.b	%01111100
	dc.b	%00000000
	dc.b	%11111000
	dc.b	%11001100
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11111100
	dc.b	%00000000
	dc.b	%11111110
	dc.b	%11000000
	dc.b	%11110000
	dc.b	%11000000
	dc.b	%11000000
	dc.b	%11000000
	dc.b	%11111110
	dc.b	%00000000
	dc.b	%11111110
	dc.b	%11000000
	dc.b	%11111000
	dc.b	%11000000
	dc.b	%11000000
	dc.b	%11000000
	dc.b	%11000000
	dc.b	%00000000
	dc.b	%01111100
	dc.b	%11000110
	dc.b	%11000000
	dc.b	%11001110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%01111110
	dc.b	%00000000
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11111110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%00000000
	dc.b	%01111110
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%01111110
	dc.b	%00000000
	dc.b	%00011110
	dc.b	%00000110
	dc.b	%00000110
	dc.b	%00000110
	dc.b	%00000110
	dc.b	%11000110
	dc.b	%01111100
	dc.b	%00000000
	dc.b	%11000110
	dc.b	%11001100
	dc.b	%11011000
	dc.b	%11110000
	dc.b	%11011000
	dc.b	%11001100
	dc.b	%11000110
	dc.b	%00000000
	dc.b	%11000000
	dc.b	%11000000
	dc.b	%11000000
	dc.b	%11000000
	dc.b	%11000000
	dc.b	%11000000
	dc.b	%11111110
	dc.b	%00000000
	dc.b	%10000010
	dc.b	%11000110
	dc.b	%11101110
	dc.b	%11111110
	dc.b	%11010110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%00000000
	dc.b	%11000110
	dc.b	%11100110
	dc.b	%11110110
	dc.b	%11011110
	dc.b	%11001110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%00000000
	dc.b	%01111100
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%01111100
	dc.b	%00000000
	dc.b	%11111000
	dc.b	%11001100
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11111100
	dc.b	%11000000
	dc.b	%11000000
	dc.b	%00000000
	dc.b	%01111100
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11011010
	dc.b	%01101100
	dc.b	%00000110
	dc.b	%11111100
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11111100
	dc.b	%11011000
	dc.b	%11001100
	dc.b	%11000110
	dc.b	%00000000
	dc.b	%01111100
	dc.b	%11000110
	dc.b	%01110000
	dc.b	%00011100
	dc.b	%01000110
	dc.b	%11000110
	dc.b	%01111100
	dc.b	%00000000
	dc.b	%01111110
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00000000
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%01111100
	dc.b	%00000000
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11001100
	dc.b	%11011000
	dc.b	%01110000
	dc.b	%00000000
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11010110
	dc.b	%11111110
	dc.b	%11101110
	dc.b	%01000100
	dc.b	%00000000
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%01101100
	dc.b	%00111000
	dc.b	%01101100
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%00000000
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%01111110
	dc.b	%00000110
	dc.b	%00000110
	dc.b	%11111100
	dc.b	%00000000
	dc.b	%11111110
	dc.b	%11000110
	dc.b	%00001100
	dc.b	%00011000
	dc.b	%00110000
	dc.b	%01100110
	dc.b	%11111110
	dc.b	%00000000
	dc.b	%00111100
	dc.b	%00110000
	dc.b	%00110000
	dc.b	%00110000
	dc.b	%00110000
	dc.b	%00110000
	dc.b	%00111100
	dc.b	%00000000
	dc.b	%11000000
	dc.b	%01100000
	dc.b	%00110000
	dc.b	%00011000
	dc.b	%00001100
	dc.b	%00000110
	dc.b	%00000010
	dc.b	%00000000
	dc.b	%00111100
	dc.b	%00001100
	dc.b	%00001100
	dc.b	%00001100
	dc.b	%00001100
	dc.b	%00001100
	dc.b	%00111100
	dc.b	%00000000
	dc.b	%00010000
	dc.b	%00111000
	dc.b	%01101100
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%11111111
	dc.b	%11111111
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00110000
	dc.b	%00110000
	dc.b	%00011000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00111100
	dc.b	%00000110
	dc.b	%01111110
	dc.b	%11000110
	dc.b	%01111110
	dc.b	%00000000
	dc.b	%11000000
	dc.b	%11000000
	dc.b	%11111100
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11111100
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%01111100
	dc.b	%11000110
	dc.b	%11000000
	dc.b	%11000110
	dc.b	%01111100
	dc.b	%00000000
	dc.b	%00000110
	dc.b	%00000110
	dc.b	%01111110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%01111110
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%01111100
	dc.b	%11000110
	dc.b	%11111110
	dc.b	%11000000
	dc.b	%01111110
	dc.b	%00000000
	dc.b	%00111100
	dc.b	%01100000
	dc.b	%01100000
	dc.b	%01111000
	dc.b	%01100000
	dc.b	%01100000
	dc.b	%01100000
	dc.b	%01100000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%01111110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%01111110
	dc.b	%00000110
	dc.b	%11111100
	dc.b	%11000000
	dc.b	%11000000
	dc.b	%11111100
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%00000000
	dc.b	%00011000
	dc.b	%00000000
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00011000
	dc.b	%00111100
	dc.b	%00000000
	dc.b	%00001100
	dc.b	%00000000
	dc.b	%00001100
	dc.b	%00001100
	dc.b	%00001100
	dc.b	%00001100
	dc.b	%11001100
	dc.b	%01111000
	dc.b	%11000000
	dc.b	%11000000
	dc.b	%11000110
	dc.b	%11001100
	dc.b	%11111000
	dc.b	%11001100
	dc.b	%11000110
	dc.b	%00000000
	dc.b	%01100000
	dc.b	%01100000
	dc.b	%01100000
	dc.b	%01100000
	dc.b	%01100000
	dc.b	%01100000
	dc.b	%00111100
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%11101110
	dc.b	%11010110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%11111100
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%01111100
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%01111100
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%11111000
	dc.b	%11001100
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11111100
	dc.b	%11000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%01111110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%01111110
	dc.b	%00000110
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%11011100
	dc.b	%11100110
	dc.b	%11000000
	dc.b	%11000000
	dc.b	%11000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%01111110
	dc.b	%11000000
	dc.b	%01111100
	dc.b	%00000110
	dc.b	%11111100
	dc.b	%00000000
	dc.b	%01100000
	dc.b	%01100000
	dc.b	%11111000
	dc.b	%01100000
	dc.b	%01100000
	dc.b	%01100000
	dc.b	%00111100
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%01111100
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%01101100
	dc.b	%01101100
	dc.b	%00111000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11010110
	dc.b	%11111110
	dc.b	%01101100
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%11000110
	dc.b	%01101100
	dc.b	%00111000
	dc.b	%01101100
	dc.b	%11000110
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%11000110
	dc.b	%01111110
	dc.b	%00000110
	dc.b	%11111100
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%11111100
	dc.b	%00011000
	dc.b	%00110000
	dc.b	%01100000
	dc.b	%11111110
	dc.b	%00000000
	dc.b	%00001110
	dc.b	%00011000
	dc.b	%00010000
	dc.b	%00110000
	dc.b	%00010000
	dc.b	%00011000
	dc.b	%00001110
	dc.b	%00000000
	dc.b	%01111100
	dc.b	%11000110
	dc.b	%01101100
	dc.b	%10111010
	dc.b	%11111110
	dc.b	%10010010
	dc.b	%00010000
	dc.b	%00111000
	dc.b	%01110000
	dc.b	%00011000
	dc.b	%00001000
	dc.b	%00001100
	dc.b	%00001000
	dc.b	%00011000
	dc.b	%01110000
	dc.b	%00000000
	dc.b	%00110110
	dc.b	%01101100
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%00000000
	dc.b	%11111110
	dc.b	%10000010
	dc.b	%10111010
	dc.b	%10101010
	dc.b	%10111010
	dc.b	%10000010
	dc.b	%11111110
	dc.b	%00000000

;=============================================================================

	SECTION	ChipGfx,DATA_C


cpList:		dc.w	diwstrt,$2c81
		dc.w	diwstop,$2cc1
		dc.w	ddfstrt,$0038
		dc.w	ddfstop,$00d0
		dc.w	bplcon0,BPL*$1000+$200
		dc.w	bplcon1,$0000
		dc.w	bplcon2,$0024
		dc.w	bpl1mod,MODULO
		dc.w	bpl2mod,MODULO
		dc.w	clxcon,$03c1

cpBpl:		ds.l	BPL*2

		dc.l	$1007fffe

cpSprite:	ds.l	16

		dc.l	-2,-2


;----------------------------------------------------------

	CNOP	0,4

sprEmpty:
emptySprite:	dc.l	0,0,0,0

	CNOP	0,4
	
sprHero:
		dc.l	0
		dc.w	%0001110000000000,0
		dc.w	%0001110000000000,0
		dc.w	%0010101000000000,0
		dc.w	%0101110100000000,0
		dc.w	%0100100100000000,0
		dc.w	%0001110000000000,0
		dc.w	%0010001000000000,0
		dc.w	%0010001000000000,0
		dc.l	0

	CNOP	0,4

sprKey:
	dc.l	0
	dc.w	%0111000000000000,0
	dc.w	%1101100000000000,0
	dc.w	%1101100000000000,0
	dc.w	%0111000000000000,0
	dc.w	%0010000000000000,0
	dc.w	%0010000000000000,0
	dc.w	%0010000000000000,0
	dc.w	%0110000000000000,0
	dc.l	0


	CNOP	0,4

sprInfo:	dc.l	0
		dc.w	%0000000000000000,0
		dc.w	%0110110000000000,0
		dc.w	%1111111000000000,0
		dc.w	%1111111000000000,0
		dc.w	%0111110000000000,0
		dc.w	%0011100000000000,0
		dc.w	%0001000000000000,0
		dc.w	%0000000000000000,0

		dc.w	%1010101010101010,0
		dc.w	%0101010101010101,0
		dc.w	0,0

		dc.w	%0100110101011010,0
		dc.w	%0100100101010010,0
		dc.w	%0100110101011010,0
		dc.w	%0100100110010010,0
		dc.w	%0110110100011011,0
		dc.w	0,0

sprLev	dc.w	%0000000000000000,0
	dc.w	%0000000000000000,0
	dc.w	%0000000000000000,0
	dc.w	%0000000000000000,0
	dc.w	%0000000000000000,0
	dc.w	%0000000000000000,0
	dc.w	%0000000000000000,0
	dc.w	%0000000000000000,0
	dc.l	0


;=============================================================================

	SECTION	CleanGfx,BSS_C

screen:		ds.b	BROW*SCR_HEIGHT*BPL
