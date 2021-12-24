****************************************************
* grim005 24/12/2021                               *
*                                                  *
* - modified to work with devpac 3.18              *
* - refactored code                                *
* - handle player tile hits before game over       *
* - added sfx: tile hit, key collected, game over  *
*              extra life                          *
* - added background music                         *
* - M key to toggle music on/off                   *
* - added title gfx with fade in                   *
* - added game instructions/credits                *
* - new life added every 3rd level                 *
****************************************************

   SECTION  grim,CODE
   INCLUDE  cargo_custom.i
   INCDIR   include:
   INCLUDE  exec/exec_lib.i
   INCLUDE  exec/execbase.i            ;AFB_68010,AttnFlags
   INCLUDE  graphics/graphics_lib.i
   INCLUDE  graphics/gfxbase.i         ;gb_ActiView,gb_copinit
   INCLUDE  hardware/cia.i
   INCLUDE  hardware/dmabits.i
   INCLUDE  hardware/intbits.i

SCR_WIDTH   = 320
SCR_HEIGHT  = 256

;protracker channel status
   RSRESET
n_note            rs.w  1     ;2    2
n_cmd             rs.b  1     ;1    3
n_cmdlo           rs.b  1     ;1    4
n_index           rs.b  1     ;1    5
n_sfxpri          rs.b  1     ;1    6
n_reserved1       rs.b  2     ;2    8
n_start           rs.l  1     ;4    12
n_loopstart       rs.l  1     ;4    16
n_length          rs.w  1     ;2    18
n_replen          rs.w  1     ;2    20
n_period          rs.w  1     ;2    22
n_volume          rs.w  1     ;2    24
n_pertab          rs.l  1     ;4    28
n_dmabit          rs.w  1     ;2    30
n_noteoff         rs.w  1     ;2    32
n_toneportspeed   rs.w  1     ;2    34
n_wantedperiod    rs.w  1     ;2    36
n_pattpos         rs.w  1     ;2    38
n_funk            rs.w  1     ;2    40
n_wavestart       rs.l  1     ;4    44
n_reallength      rs.w  1     ;2    46
n_intbit          rs.w  1     ;2    48
n_sfxptr          rs.l  1     ;4    52
n_sfxlen          rs.w  1     ;2    54
n_sfxper          rs.w  1     ;2    56
n_sfxvol          rs.w  1     ;2    58
n_looped          rs.b  1     ;1    59
n_minusft         rs.b  1     ;1    60
n_vibratoamp      rs.b  1     ;1    61
n_vibratospd      rs.b  1     ;1    62
n_vibratopos      rs.b  1     ;1    63
n_vibratoctrl     rs.b  1     ;1    64
n_tremoloamp      rs.b  1     ;1    65
n_tremolospd      rs.b  1     ;1    66
n_tremolopos      rs.b  1     ;1    67
n_tremoloctrl     rs.b  1     ;1    68
n_gliss           rs.b  1     ;1    69
n_sampleoffset    rs.b  1     ;1    70
n_loopcount       rs.b  1     ;1    71
n_funkoffset      rs.b  1     ;1    72
n_retrigcount     rs.b  1     ;1    73
n_freecnt         rs.b  1     ;1    74
n_musiconly       rs.b  1     ;1    75
n_reserved2       rs.b  1     ;1    76    hex $4c
n_sizeof          rs.b  0

   RSRESET
v_osExecBase   rs.l  1
v_gfxbase      rs.l  1
v_oldview      rs.l  1
v_intena       rs.w  1
v_dmacon       rs.w  1
v_intvertb     rs.l  1
v_intports     rs.l  1
v_vectorbase   rs.l  1
g_pFnc         rs.l  1
lSeed          rs.l  1
bKeytab        rs.b  $80
wTilesNumber   rs.w  1
lTileTable     rs.l  SCR_WIDTH/8*SCR_HEIGHT/8
wLevelNumber   rs.w  1
wHeroX         rs.w  1
wHeroY         rs.w  1
wHeroLives     rs.w  1
wKeyX          rs.w  1
wKeyY          rs.w  1
fade_tbl       rs.l  1
delay          rs.w  1
;protracker variable block
mt_chan1       rs.b        n_sizeof       ;76   76
mt_chan2       rs.b        n_sizeof       ;76   152
mt_chan3       rs.b        n_sizeof       ;76   228
mt_chan4       rs.b        n_sizeof       ;76   304
mt_SampleStarts   rs.l     31             ;124  428
mt_mod         rs.l        1              ;4    432
mt_oldLev6     rs.l        1              ;4    436
mt_timerval    rs.l        1              ;4    440
mt_oldtimers   rs.b        4              ;4    444
mt_Lev6Int     rs.l        1              ;4    448
mt_Lev6Ena     rs.w        1              ;2    450
mt_PatternPos  rs.w        1              ;2    452
mt_PBreakPos   rs.w        1              ;2    454
mt_PosJumpFlag rs.b        1              ;1    455
mt_PBreakFlag  rs.b        1              ;1    456
mt_Speed       rs.b        1              ;1    457
mt_Counter     rs.b        1              ;1    458
mt_SongPos     rs.b        1              ;1    459
mt_PattDelTime rs.b        1              ;1    460
mt_PattDelTime2   rs.b     1              ;1    461
mt_SilCntValid    rs.b     1              ;1    462
mt_MasterVolTab   rs.l     1              ;4    466
mt_Enable         rs.b     1              ;1    467   ; exported as _mt_Enable
mt_E8Trigger      rs.b     1              ;1    468   ; exported as _mt_E8Trigger
mt_MusicChannels  rs.b     1              ;1    469   ; exported as _mt_MusicChannels
mt_SongEnd        rs.b     1              ;1    470   ; exported as _mt_SongEnd
vars_sizeof:   rs.b  0

****************************************************

TILE_WIDTH  = 8
TILE_HEIGHT = 8

BPL         = 1                     ;amount of bitlpans (1-8)
BROW        = SCR_WIDTH/8           ;bytes per row

MODULO      = (BPL-1)*BROW          ;modulo rawblit

KEY_ESC     = $45                   ;rawkey code
KEY_LEFT    = $4f
KEY_RIGHT   = $4e
KEY_UP      = $4c
KEY_DOWN    = $4d
KEY_A       = $20
KEY_M       = $37
KEY_I       = $17

HERO_INIT_X = 160
HERO_INIT_Y = 240

KEY_INIT_X  = 320-48
KEY_INIT_Y  = 16
****************************************************
* MACROS
****************************************************
WAITVB: MACRO
.1\@
   btst     #0,(CUSTOM+vposr+1)
   beq      .1\@
.2\@
   btst     #0,(CUSTOM+vposr+1)
   bne      .2\@
   ENDM

FUNCT: MACRO
   lea      \1(pc),a1
   move.l   a1,g_pFnc(a4)
   ENDM

PRINT: MACRO
   lea      \1,a0
   lea      \2,a1
   moveq    \3,d0
   moveq    \4,d1
   bsr      showmsg
   ENDM

SFX: MACRO
   movem.l  a0/a6,-(sp)
   lea      CUSTOM,a6
   move.l   \1,a0
   jsr      _mt_playfx
   movem.l  (sp)+,a0/a6
   ENDM
****************************************************
start:
   lea      vars(pc),a4
   lea      CUSTOM,a5
   bsr      takeos
   bsr      init

   move.l   #cpList,cop1lc(a5)
   move.w   #0,copjmp1(a5)
   move.w   #$87f0,dmacon(a5)       ;15 set, BLIPRI/DMAEN/BPLEN, COPEN/BLTEN/SPREN/DSKEN, audio=0
;sound setup
   lea      vars,a4
   lea      CUSTOM,a6
   jsr      _mt_end                 ;all 4 channels to zero volume, stop audio DMA
   move.l   v_vectorbase(a4),a0     ;Only >68000 needs vector base to be retrieved
   move.b   #1,d0                            ;PAL
   ;lea      CUSTOM,a6
   jsr      _mt_install_cia

   move.l   #music_reiko,a0
   move.l   #0,a1
   move.l   #0,d0
   jsr      _mt_init             ;(a6=CUSTOM, a0=TrackerModule, a1=Samples|NULL, d0=InitialSongPos.b)
   move.b   #1,mt_Enable(a4)

   FUNCT    titleinit

mainloop:
   move.l   g_pFnc(a4),a0
   jsr      (a0)                    ;do FUNCT
   btst     #6,$bfe001              ;LMB pressed ?
   beq      exit                    ;yes then exit

   lea      bKeytab(a4),a0
   tst.b    KEY_ESC(a0)             ;ESC key pressed ?
   bne      exit                    ;yes then exit
   tst.b    KEY_M(a0)               ;M key pressed ?
   beq      .done                   ;no
   sf       KEY_M(a0)               ;yes (set on false)
   cmp.b    #1,mt_Enable(a4)
   bne      .music_on
.music_off
   jsr      _mt_end
   move.b   #0,mt_Enable(a4)
   bra      .done
.music_on
   move.l   #music_reiko,a0
   move.l   #0,a1
   move.l   #0,d0
   jsr      _mt_init             ;(a6=CUSTOM, a0=TrackerModule, a1=Samples|NULL, d0=InitialSongPos.b)
   move.b   #1,mt_Enable(a4)
.done
   bra      mainloop

exit:                               ;shutdown sound and restore OS
   jsr      _mt_end                 ;all 4 channels to zero volume, stop audio DMA
   jsr      _mt_remove_cia
   bra      restore_os

****************************************************
infoinit:
   move.w   #$000,color00(a5)
   move.w   #$eee,color01(a5)
   bsr      setemptysprites
   bsr      clearscreen
   PRINT    txt_line9,screen,#0,#0
   PRINT    txt_line10,screen,#0,#1
   PRINT    txt_line11,screen,#0,#2
   PRINT    txt_line12,screen,#0,#3
   PRINT    txt_line13,screen,#0,#4
   PRINT    txt_line14,screen,#0,#5
   PRINT    txt_line15,screen,#0,#6
   PRINT    txt_line16,screen,#0,#7
   PRINT    txt_line17,screen,#0,#8
   PRINT    txt_line18,screen,#0,#9
   PRINT    txt_line19,screen,#0,#10
   PRINT    txt_line20,screen,#0,#11
   PRINT    txt_line21,screen,#0,#12
   PRINT    txt_line22,screen,#0,#15
   PRINT    txt_line23,screen,#0,#16
   PRINT    txt_line24,screen,#0,#17
   PRINT    txt_line25,screen,#0,#18
   PRINT    txt_line26,screen,#0,#20
   PRINT    txt_line27,screen,#0,#21
   PRINT    txt_line28,screen,#0,#23
   PRINT    txt_line29,screen,#0,#24
   PRINT    txt_line30,screen,#0,#26
   PRINT    txt_line31,screen,#0,#27
   PRINT    txt_line32,screen,#0,#28
   PRINT    txt_line33,screen,#0,#30
   PRINT    txt_line34,screen,#0,#31
   FUNCT    infoloop
   rts

****************************************************
infoloop:
   WAITVB
.userinput
   lea      bKeytab(a4),a0
   tst.b    KEY_I(a0)               ;I key pressed ?
   beq      .exit                   ;no
   sf       KEY_I(a0)               ;yes (set on false)
   FUNCT    titleinit               ;I key pressed so back to titleinit
.exit
   rts

****************************************************
titleinit:
   move.w   #$000,color00(a5)
   move.w   #$000,color01(a5)
   bsr      setemptysprites
   bsr      clearscreen
   bsr      showgrim

   move.l   #fadein,fade_tbl(a4)
   move.w   #0,delay(a4)
   FUNCT    titlecolorfadeloop
   rts

****************************************************
showgrim:
   lea      image_title,a0
   lea      screen,a1
   add.l    #69*BROW,a1             ;move logo down 69 lines
   move.l   #3400-1,d0
.copy
   move.b   (a0)+,(a1)+
   dbf      d0,.copy
   rts

****************************************************
titlecolorfadeloop:
   WAITVB
   move.l   fade_tbl(a4),a0
   move.w   (a0),d0
   btst     #15,d0                  ;$FFFF terminate loop
   bne      .fadecomplete           ;yes @ $FFFF
   move.w   d0,COLOR01
   add.l    #2,fade_tbl(a4)
   bra      .exit
.fadecomplete   
   FUNCT    titletext
.exit
   rts

****************************************************
titletext:
   WAITVB
   add.w    #1,delay(a4)
   cmp.w    #60,delay(a4)
   blt      .userinput
   bgt      .next1
   PRINT    txt_line8,screen,#34,#31
.next1
   cmp.w    #120,delay(a4)
   blt      .userinput
   bgt      .next2
   PRINT    txt_line1,screen,#0,#24
.next2
   cmp.w    #180,delay(a4)
   blt      .userinput
   bgt      .next3
   PRINT    txt_line2,screen,#0,#25
.next3
   cmp.w    #240,delay(a4)
   blt      .userinput
   bgt      .next4
   PRINT    txt_line3,screen,#0,#26
.next4
   cmp.w    #300,delay(a4)
   blt      .userinput
   bgt      .next5
   PRINT    txt_line4,screen,#0,#27
.next5
   cmp.w    #360,delay(a4)
   blt      .userinput
   bgt      .next6
   PRINT    txt_line5,screen,#0,#28
.next6
   cmp.w    #420,delay(a4)
   blt      .userinput
   bgt      .next7
   PRINT    txt_line6,screen,#0,#29
.next7
   cmp.w    #480,delay(a4)
   blt      .userinput
   bgt      .userinput
   PRINT    txt_line7,screen,#0,#30
   FUNCT    titleloop
.userinput
   lea      bKeytab(a4),a0
   tst.b    KEY_A(a0)               ;A key pressed ?
   beq      .userinput2             ;no
   sf       KEY_A(a0)               ;yes (set on false)
   FUNCT    gameinit                ;A key pressed so do gameinit
   rts
.userinput2
   lea      bKeytab(a4),a0
   tst.b    KEY_I(a0)               ;I key pressed ?
   beq      .exit                   ;no
   sf       KEY_I(a0)               ;yes (set on false)
   FUNCT    infoinit                ;I key pressed so do infoinit
.exit
   rts

****************************************************
titleloop:
   WAITVB
.userinput
   lea      bKeytab(a4),a0
   tst.b    KEY_I(a0)               ;I key pressed ?
   beq      .userinput2             ;no
   sf       KEY_I(a0)               ;yes (set on false)
   FUNCT    infoinit                ;I key pressed so do infoinit
   rts
.userinput2
   lea      bKeytab(a4),a0
   tst.b    KEY_A(a0)               ;A key pressed ?
   beq      .exit                   ;no
   sf       KEY_A(a0)               ;yes (set on false)
   FUNCT    gameinit                ;A key pressed so do gameinit
.exit
   rts

****************************************************
gameinit:
   move.w   #0,wLevelNumber(a4)     ;reset level
   move.w   #3,wHeroLives(a4)       ;reset hero amount
   move.w   #50,wTilesNumber(a4)    ;reset amount of tiles
;set colors
   move.w   #$000,color00(a5)
   move.w   #$555,color01(a5)
;set spr colors
   move.w   #$000,color16(a5)
   move.w   #$48f,color17(a5)
   move.w   #$0d9,color18(a5)
   move.w   #$a11,color19(a5)
   move.w   #$f48,color21(a5)

   move.w   clxdat(a5),d0           ;to prevent initial false trigger of collision
   bsr      nextlevel
   FUNCT    gameloop
   rts

****************************************************
gameloop:
   WAITVB                           ;originally in mainloop but needs to be here to avoid double collision hits
   bsr      getinputs

;logic
   tst.w    wLeft
   beq      .right
   sub.w    #1,wHeroX(a4)
.right
   tst.w    wRight
   beq      .up
   add.w    #1,wHeroX(a4)
.up
   tst.w    wUp
   beq      .down
   sub.w    #1,wHeroY(a4)
.down
   tst.w    wDown
   beq      .other
   add.w    #1,wHeroY(a4)
.other
   bsr      updatehero

   move.w   clxdat(a5),d0
   move.w   d0,d1
   and.w    #$2,d0                  ;touch a tile ? playfield 1 to sprite 2(or 3)
   beq      .key                    ;no 
   SFX      #sfx_hit_tile           ;yes
   FUNCT    loselife
   rts
.key
   and.w    #$200,d1                ;touch the key ? sprite 0 (or 1) to sprite 4 (or 5)
   beq      .exit                   ;no
   SFX      #sfx_key_collect        ;yes
   bsr      setemptysprites
   WAITVB
   bsr      nextlevel
.exit
   rts

****************************************************
loselife:
   cmp.w    #1,wHeroLives(a4)       ;was it our last life ?
   bgt      .adjusthero             ;no
   SFX      #sfx_game_over          ;yes
   FUNCT    gameover
   rts
.adjusthero
   move.w   #HERO_INIT_X,wHeroX(a4)
   move.w   #HERO_INIT_Y,wHeroY(a4)
   bsr      showhero
   bsr      updatehero
   sub.w    #1,wHeroLives(a4)
   bsr      updatelivesinfo
   bsr      showinfo
   bsr      updateinfo
;to minimise unfair repeated loss of life - redraw screen with new layout
   bsr      clearscreen
   bsr      renderlevel
   FUNCT    gameloop
   rts

****************************************************
nextlevel:
   add.w    #1,wLevelNumber(a4)
;check if earned a free life   
   moveq    #0,d0
   move.w   wLevelNumber(a4),d0
   divu     #3,d0
   swap     d0                      ;we want to check the remainder 0=add a life
   cmp.w    #0,d0
   bne      .skipnewlife
   cmp.w    #9,wHeroLives(a4)       ;max lives
   bge      .skipnewlife
   add.w    #1,wHeroLives(a4)
   SFX      #sfx_new_life
.skipnewlife   
   add.w    #5,wTilesNumber(a4)
   bsr      clearscreen
   bsr      renderlevel
;set hero
   move.w   #HERO_INIT_X,wHeroX(a4)
   move.w   #HERO_INIT_Y,wHeroY(a4)
   bsr      showhero
   bsr      updatehero
;set key
   move.w   #KEY_INIT_X,wKeyX(a4)
   move.w   #KEY_INIT_Y,wKeyY(a4)
   bsr      showkey
   bsr      updatekey
;set info
   bsr      updatelivesinfo
   bsr      updatelevelinfo

   bsr      showinfo
   bsr      updateinfo

   rts

****************************************************
gameover:
   FUNCT    titleinit
   bsr      setemptysprites

; clean screen
   bsr      clearscreen

; show game over msg
   PRINT    txt_gameover,screen,#15,#16

   moveq    #120,d0

.loop
   WAITVB
   lea      bKeytab(a4),a0
   tst.b    KEY_ESC(a0)
   bne      .wait
   btst     #6,$bfe001
   beq      .exit
   dbf      d0,.loop
   rts

.wait
   tst.b    KEY_ESC(a0)
   beq      .exit
   bra      .wait

.exit
   rts

****************************************************
clearscreen:
   lea      screen,a0
   move.l   #BPL*BROW*SCR_HEIGHT/4,d0
   moveq    #0,d1
.clear
   move.l   d1,(a0)+
   subq.l   #1,d0
   bne      .clear
   rts

****************************************************
renderlevel:
   move.w   wTilesNumber(a4),d2
   lea      lTileTable(a4),a0
.rloop
   bsr      rnd
   asl.l    #2,d0
   move.l   (a0,d0.w),a1
   moveq    #8-1,d0
.copy
   move.b   #$ff,(a1)
   add.l    #BROW,a1
   dbf      d0,.copy
   dbf      d2,.rloop
   rts

****************************************************
showhero:
   lea      cpSprite,a0
   move.l   #sprHero,d0
   move.w   d0,6(a0)
   swap     d0
   move.w   d0,2(a0)
   rts

****************************************************
updatehero
   lea      sprHero,a0
   move.w   wHeroX(a4),d0
   move.w   wHeroY(a4),d1
   moveq    #8,d2
   bsr      setsprite
   rts

****************************************************
showkey:
   lea      cpSprite,a0
   move.l   #sprKey,d0
   move.w   d0,22(a0)
   swap     d0
   move.w   d0,18(a0)
   rts

****************************************************
updatekey
   lea      sprKey,a0
   move.w   wKeyX(a4),d0
   move.w   wKeyY(a4),d1
   moveq    #8,d2
   bsr      setsprite
   rts

****************************************************
showinfo:
   lea      cpSprite,a0
   move.l   #sprInfo,d0
   move.w   d0,30(a0)
   swap     d0
   move.w   d0,26(a0)
   rts

****************************************************
INFO_X      = 304
INFO_Y      = 0
INFO_H      = 26

updateinfo:
   lea      sprInfo,a0
   move.w   #INFO_X,d0
   move.w   #INFO_Y,d1
   moveq    #INFO_H,d2
   bsr      setsprite
   rts

****************************************************
updatelevelinfo:
   moveq    #0,d0
   move.w   wLevelNumber(a4),d0
   moveq    #0,d1
.calc
   cmp.w    #9,d0
   ble      .do
   addq.w   #1,d1
   sub.w    #10,d0
   bra      .calc

	; d0
	; d1
.do
   lea      sprLev,a0
   lea      digits,a1

   asl.w    #3,d1
   add.l    d1,a1
   moveq    #8-1,d1
.copy1
   move.b   (a1)+,(a0)
   addq.l   #4,a0
   dbf      d1,.copy1

   lea      sprLev+1,a0
   lea      digits,a1

   asl.w    #3,d0
   add.l    d0,a1
   moveq    #8-1,d0
.copy2
   move.b   (a1)+,(a0)
   addq.l   #4,a0
   dbf      d0,.copy2
   rts

****************************************************
updatelivesinfo:
   lea      sprInfo+5,a0
   lea      digits,a1

   moveq    #0,d0
   move.w   wHeroLives(a4),d0
   asl.w    #3,d0
   add.l    d0,a1
   moveq    #8-1,d0
.loop
   move.b   (a1)+,(a0)
   addq.l   #4,a0
   dbf      d0,.loop
   rts

****************************************************
getinputs:
   moveq    #0,d0
   moveq    #0,d1
   moveq    #0,d2
   moveq    #0,d3
   lea      bKeytab(a4),a0
   tst.b    KEY_LEFT(a0)
   sne      d0                      ;set on not equal
   tst.b    KEY_RIGHT(a0)
   sne      d1
   tst.b    KEY_UP(a0)
   sne      d2
   tst.b    KEY_DOWN(a0)
   sne      d3
   lea      wDown+2(pc),a0
   movem.w  d0-d3,-(a0)
   rts

wLeft:      dc.w 0
wRight      dc.w 0
wUp:        dc.w 0
wDown:      dc.w 0

****************************************************
init:
;set random seed
   move.w   vhposr(a5),d0
   move.l   d0,lSeed(a4)

;set PORTS int
   move.l   v_vectorbase(a4),a0
   lea      IntPORTS(pc),a1
   move.l   a1,$68(a0)

   move.b   #CIAICRF_SETCLR|CIAICRF_SP,(ciaicr+CIAA)
   tst.b    (ciaicr+CIAA)
   and.b    #~(CIACRAF_SPMODE),(ciacra+CIAA)
   move.w   #INTF_PORTS,(intreq+CUSTOM)
   move.w   #INTF_SETCLR|INTF_INTEN|INTF_PORTS,(intena+CUSTOM)

;sprites
   moveq    #16-1,d0
   move.w   #spr0pt,d1
   lea      cpSprite,a0
   move.l   #emptySprite,d2
.sprites
   move.w   d1,(a0)+
   swap     d2
   move.w   d2,(a0)+
   addq.w   #2,d1
   dbf      d0,.sprites

;bitplanes
   moveq    #BPL*2-1,d0
   move.w   #bpl1pt,d1
   move.l   #screen,d2
   lea      cpBpl,a0
.planes
   move.w   d1,(a0)+
   swap     d2
   move.w   d2,(a0)+
   addq.w   #2,d1
   dbf      d0,.planes

;do look up table for tiles
   lea      lTileTable(a4),a0
   move.l   #screen,d1
   moveq    #SCR_HEIGHT/TILE_HEIGHT-1,d3
.line
   moveq    #SCR_WIDTH/TILE_WIDTH-1,d2
   move.l   d1,d0
.loop
   move.l   d0,(a0)+
   addq.l   #TILE_WIDTH/8,d0
   dbf      d2,.loop
   add.l    #BPL*BROW*TILE_HEIGHT,d1
   dbf      d3,.line
   rts

****************************************************
setemptysprites:
   moveq    #16-1,d0
   move.l   #emptySprite,d1
   lea      cpSprite,a0
.loop
   swap     d1
   move.w   d1,2(a0)
   addq.l   #4,a0
   dbf      d0,.loop
   rts

****************************************************
start_x     equ 127
start_y     equ 44

; a0 - spr adr
; d0 - x
; d1 - y
; d2 - height of spr
;
setsprite:
   add.w    #start_x,d0
   add.w    #start_y,d1
   move.w   d1,d4
   moveq    #0,d3

   move.b   d1,(a0)
   lsl.w    #8,d4
   addx.b   d3,d3

   add.w    d2,d1
   move.b   d1,2(a0)
   lsl.w    #8,d1
   addx.b   d3,d3

   lsr.w    #1,d0
   addx.w   d3,d3	

   move.b   d0,1(a0)
   move.b   d3,3(a0)
   rts

****************************************************

;in	-
;out	d0 - rnd ( 0 - SCR_HEIGHT/TILE*SCR_WIDTH/TILE_WIDTH )
;
;used	d0,d1
;

rnd:
   bsr      random
   and.l    #$ffff,d0
   move.w   #SCR_HEIGHT/TILE_HEIGHT*SCR_WIDTH/TILE_WIDTH,d1    ;max
   mulu     d1,d0
   asr.l    #8,d0
   asr.l    #8,d0
   and.l    #$ffff,d0
   rts

random
   move.l   lSeed(a4),d0
   move.l   d0,d1
   asl.l    #3,d1
   sub.l    d0,d1
   asl.l    #3,d1
   add.l    d0,d1
   add.l    d1,d1
   add.l    d0,d1
   asl.l    #4,d1
   sub.l    d0,d1
   add.l    d1,d1
   sub.l    d0,d1
   addi.l   #$E60,d1
   andi.l   #$7FFFFFFF,d1
   move.l   d1,d0
   subq.l   #1,d0
   move.l   d1,d0
   move.l   d0,lSeed(a4)
   rts

;
; d2 - max
;
rand:
   bsr      random
   and.l    #$ffff,d0
   mulu     d2,d0
   asr.l    #8,d0
   asr.l    #8,d0
   and.l    #$ffff,d0
   rts

****************************************************
IntPORTS:
   movem.l  d0-d1/a0-a2,-(a7)
   lea      (CUSTOM),a0
   lea      (CIAA),a1

;check if keyboard has caused interrupt
   btst     #INTB_PORTS,intreqr+1(a0)
   beq      .end
   btst     #CIAICRB_SP,ciaicr(a1)
   beq      .end

;read key and store him
   move.b   ciasdr(a1),d0
   or.b     #CIACRAF_SPMODE,ciacra(a1)
   not.b    d0
   ror.b    #1,d0
   spl      d1
   and.w    #$7f,d0
   lea      bKeytab(a4),a2
   move.b   d1,(a2,d0.w)

.handshake
;wait for handshake
   moveq    #3-1,d1
.wait1
   move.b   vhposr(a0),d0
.wait2
   cmp.b    vhposr(a0),d0
   beq      .wait2
   dbf      d1,.wait1

;set input mode
   and.b    #~(CIACRAF_SPMODE),ciacra(a1)
.end
   move.w   #INTF_PORTS,intreq(a0)
   tst.w    intreqr(a0)
   movem.l  (a7)+,d0-d1/a0-a2
   rte

****************************************************
takeos:
   movem.l  d0-a6,-(sp)
;store exec base
   move.l   4.w,a6
   move.l   a6,v_osExecBase(a4)

;open graphics library
   moveq    #0,d0
   lea      gfxname(pc),a1
   jsr      _LVOOpenLibrary(a6)
   move.l   d0,v_gfxbase(a4)
   beq.w    errexit
   move.l   d0,a6

;save old view
   move.l   gb_ActiView(a6),v_oldview(a4)

;wait till blitter finish job
   jsr      _LVOWaitBlit(a6)

;take blitter
   jsr      _LVOOwnBlitter(a6)

;reset display
   sub.l    a1,a1
   jsr      _LVOLoadView(a6)
   jsr      _LVOWaitTOF(a6)
   jsr      _LVOWaitTOF(a6)

;multitaskig off
   move.l   v_osExecBase(a4),a6
   jsr      _LVOForbid(a6)

;get vbr
   moveq    #0,d0
   btst.b   #AFB_68010,AttnFlags+1(a6)
   beq      .mc68000
   lea      movectrap(pc),a5
   jsr      _LVOSupervisor(a6)
.mc68000
   lea      v_vectorbase(a4),a5
   move.l   d0,(a5)

   lea      CUSTOM,a5

;store 
   move.w   intenar(a5),d0
   or.w     #$c000,d0
   move.w   d0,v_intena(a4)

   move.w   dmaconr(a5),d0
   or.w     #$8000,d0
   move.w   d0,v_dmacon(a4)

   WAITVB

;stop int & dma
   move.w   #$7fff,d0
   move.w   d0,intena(a5)
   move.w   d0,dmacon(a5)
   move.w   d0,intreq(a5)

;Check AGA
   move.w   deniseid(a5),d0
   cmpi.b   #$f8,d0                 ;AGA ?
   bne.b    .no

;Reset to ECS
   moveq    #0,d0
   move.w   d0,bplcon3(a5)
   move.w   d0,fmode(a5)
.no

;store int pointers
   move.l   v_vectorbase(a4),a0
   move.l   $6c(a0),v_intvertb(a4)
   move.l   $68(a0),v_intports(a4)

   movem.l  (sp)+,d0-a6
   rts
****************************************************
restore_os
   movem.l  d0-a6,-(sp)
   lea      CUSTOM,a5

   WAITVB
;stop int & dma
   move.w   #$7fff,d0
   move.w   d0,intena(a5)
   move.w   d0,dmacon(a5)
   move.w   d0,intreq(a5)

;restore ints pointers
   move.l   v_vectorbase(a4),a0
   move.l   v_intvertb(a4),$6c(a0)
   move.l   v_intports(a4),$68(a0)

;restore
   move.w   v_dmacon(a4),dmacon(a5)
   move.w   v_intena(a4),intena(a5)

;multitasking on
   move.l   v_osExecBase(a4),a6
   jsr      _LVOPermit(a6)

;load old view
   move.l   v_gfxbase(a4),a6
   move.l   v_oldview(a4),a1
   jsr      _LVOLoadView(a6)

   move.l   gb_copinit(a6),cop1lc(a5)     ;restore system clist
;disown blitter
   jsr      _LVODisownBlitter(a6)

;close graphics library
   move.l   v_osExecBase(a4),a6
   move.l   v_gfxbase(a4),a1
   jsr      _LVOCloseLibrary(a6)

   movem.l  (sp)+,d0-a6
   rts

errexit
   moveq    #-1,d0
   rts

movectrap   dc.l  $4e7a0801         ;movec   vbr,d0
   rte

****************************************************
* showmsg                                          *
*                                                  *
* params: a0 - msg,     a1 - screen                *
*         d0 - x(0-39), d1 - y(0-31)               *
****************************************************
showmsg
.loop
   move.l   a1,a2                   ;base address of screen
   movem    d0-d1,-(sp)             ;save original x,y params to stack
   add.l    d0,a2                   ;add the x offset
   mulu.w   #BROW*8,d1              ;y=y*8*40
   add.l    d1,a2                   ;add the y offset
   moveq    #0,d0
   move.b   (a0)+,d0
   beq      .exit                   ;0=end of string to print
   sub.b    #$20,d0
   asl.w    #3,d0
   lea      fonts,a3
   add.l    d0,a3

   moveq    #8-1,d1
.copy
   move.b   (a3)+,(a2)
   add.l    #BROW*BPL,a2
   dbf      d1,.copy

   movem    (sp)+,d0-d1             ;restore x,y params from stack

   addq.l   #1,a1
   bra      .loop
.exit
   movem    (sp)+,d0-d1             ;restore x,y params from stack
   rts

****************************************************
* protracker/sfx - routines
****************************************************
sfx_key_collect
   dc.l  sound_key_collect          ;void *sfx_ptr  (pointer to sample start in Chip RAM, even address)
   dc.w  1441                       ;WORD  sfx_len  (sample length in words)
   dc.w  161                        ;WORD  sfx_per  (hardware replay period for sample)
   dc.w  64                         ;WORD  sfx_vol  (volume 0..64, is unaffected by the song's master volume)
   dc.b  -1                         ;BYTE  sfx_cha  (0..3 selected replay channel, -1 selects best channel)
   dc.b  127                        ;BYTE  sfx_pri  (priority, must be in the range 1..127, lower priority / older same priority replaced)

sfx_hit_tile
   dc.l  sound_hit_tile             ;void *sfx_ptr  (pointer to sample start in Chip RAM, even address)
   dc.w  4317                       ;WORD  sfx_len  (sample length in words)
   dc.w  161                        ;WORD  sfx_per  (hardware replay period for sample)
   dc.w  64                         ;WORD  sfx_vol  (volume 0..64, is unaffected by the song's master volume)
   dc.b  -1                         ;BYTE  sfx_cha  (0..3 selected replay channel, -1 selects best channel)
   dc.b  127                        ;BYTE  sfx_pri  (priority, must be in the range 1..127, lower priority / older same priority replaced)

sfx_new_life
   dc.l  sound_new_life             ;void *sfx_ptr  (pointer to sample start in Chip RAM, even address)
   dc.w  3151                       ;WORD  sfx_len  (sample length in words)
   dc.w  161                        ;WORD  sfx_per  (hardware replay period for sample)
   dc.w  64                         ;WORD  sfx_vol  (volume 0..64, is unaffected by the song's master volume)
   dc.b  -1                         ;BYTE  sfx_cha  (0..3 selected replay channel, -1 selects best channel)
   dc.b  127                        ;BYTE  sfx_pri  (priority, must be in the range 1..127, lower priority / older same priority replaced)

sfx_game_over
   dc.l  sound_game_over            ;void *sfx_ptr  (pointer to sample start in Chip RAM, even address)
   dc.w  21791                      ;WORD  sfx_len  (sample length in words)
   dc.w  236                        ;WORD  sfx_per  (hardware replay period for sample)
   dc.w  64                         ;WORD  sfx_vol  (volume 0..64, is unaffected by the song's master volume)
   dc.b  -1                         ;BYTE  sfx_cha  (0..3 selected replay channel, -1 selects best channel)
   dc.b  127                        ;BYTE  sfx_pri  (priority, must be in the range 1..127, lower priority / older same priority replaced)

   INCLUDE ptplayer6.s

****************************************************
vars           dcb.b vars_sizeof,0
   EVEN
gfxname        dc.b  'graphics.library',0
   EVEN
txt_gameover:  dc.b  'GAME OVER',0
   EVEN
txt_line1:     dc.b  '       GAME CONTROLS       ',0
txt_line2:     dc.b  '---------------------------',0
txt_line3:     dc.b  'A - start new game         ',0
txt_line4:     dc.b  'M - toggle music (restart) ',0
txt_line5:     dc.b  'I - toggle info/credits    ',0
txt_line6:     dc.b  'arrow keys - move character',0
txt_line7:     dc.b  'ESC/LMB - exit to CLI      ',0
txt_line8:     dc.b  'v0.05',0
   EVEN
txt_line9:     dc.b  'grim v0.05 - Simple Amiga game to learn',0
txt_line10:    dc.b  'the basics of Amiga programming. Many  ',0
txt_line11:    dc.b  'thanks to asman2000 for open sourcing  ',0
txt_line12:    dc.b  'the original game. This version    ',0
txt_line13:    dc.b  'adds music, sfx and minor changes to   ',0
txt_line14:    dc.b  'gameplay: lose a life when colliding   ',0
txt_line15:    dc.b  'with a tile, earn a life (up to 9)     ',0
txt_line16:    dc.b  'every 3 levels.                        ',0
txt_line17:    dc.b  'Note: eventually the sheer number of   ',0
txt_line18:    dc.b  'tiles prevents game completion, so you ',0
txt_line19:    dc.b  'have to sacrifice a life and hope with ',0
txt_line20:    dc.b  'level redraw there is a path to the key',0
txt_line21:    dc.b  '(yep that''s why it''s called grim!!)    ',0
txt_line22:    dc.b  '                CREDITS                ',0
txt_line23:    dc.b  '---------------------------------------',0
txt_line24:    dc.b  'Original game by asman2000             ',0
txt_line25:    dc.b  '  github.com/asman2000/grim            ',0
txt_line26:    dc.b  'Title font by Gordon Johnson           ',0
txt_line27:    dc.b  '  pixabay.com/images/id-5975290        ',0
txt_line28:    dc.b  'Music ''Reiko'' by Sam                   ',0
txt_line29:    dc.b  '  modarchive.org/module.php?115060     ',0
txt_line30:    dc.b  'Sound effects by Juhani Junkala        ',0
txt_line31:    dc.b  '  opengameart.org/content/             ',0
txt_line32:    dc.b  '   512-sound-effects-8-bit-style       ',0
txt_line33:    dc.b  'Protracker player by Frank Wille       ',0
txt_line34:    dc.b  '  phoenix.owl.de/ptplayer61beta.lha    ',0
fonts:
   INCLUDE  fontdata.s
image_title
   INCBIN assets/grim320x85.raw     ;  3400 bytes

fadein
   dc.w $000,$100,$000
   dc.w $100,$200,$300,$400,$500,$600,$700,$900,$b00,$d00,$f00,$f00
   dc.w $f11,$f33,$f55,$f77,$f99,$fbb,$fdd,$fff,$ffff

****************************************************
   SECTION  ChipGfx,DATA_C

sound_key_collect                   ;  2882 bytes
   INCBIN assets/key_collect.raw
sound_hit_tile                      ;  8634 bytes
   INCBIN assets/hit_tile.raw
sound_new_life                      ;  6302 bytes
   INCBIN assets/new_life.raw
sound_game_over                     ; 43582 bytes
   INCBIN assets/game_over.raw
music_reiko                         ;207014 bytes
   INCBIN assets/reiko.mod

cpList:
   dc.w  diwstrt,$2c81
   dc.w  diwstop,$2cc1
   dc.w  ddfstrt,$0038
   dc.w  ddfstop,$00d0
   dc.w  bplcon0,BPL*$1000+$200
   dc.w  bplcon1,$0000
   dc.w  bplcon2,$0024
   dc.w  bpl1mod,MODULO
   dc.w  bpl2mod,MODULO
   dc.w  clxcon,$03c1
cpBpl:
   ds.l  BPL*2
   dc.l  $1007fffe
cpSprite:
   ds.l  16
   dc.l  -2,-2

****************************************************

   CNOP  0,4

sprEmpty:
emptySprite:
   dc.l  0,0,0,0

   CNOP  0,4

sprHero:
   dc.l  0
   dc.w  %0001110000000000,0
   dc.w  %0001110000000000,0
   dc.w  %0010101000000000,0
   dc.w  %0101110100000000,0
   dc.w  %0100100100000000,0
   dc.w  %0001110000000000,0
   dc.w  %0010001000000000,0
   dc.w  %0010001000000000,0
   dc.l  0

   CNOP  0,4

sprKey:
   dc.l  0
   dc.w  %0111000000000000,0
   dc.w  %1101100000000000,0
   dc.w  %1101100000000000,0
   dc.w  %0111000000000000,0
   dc.w  %0010000000000000,0
   dc.w  %0010000000000000,0
   dc.w  %0010000000000000,0
   dc.w  %0110000000000000,0
   dc.l  0

   CNOP  0,4

sprInfo:
   dc.l  0
   dc.w  %0000000000000000,0
   dc.w  %0110110000000000,0
   dc.w  %1111111000000000,0
   dc.w  %1111111000000000,0
   dc.w  %0111110000000000,0
   dc.w  %0011100000000000,0
   dc.w  %0001000000000000,0
   dc.w  %0000000000000000,0

   dc.w  %1010101010101010,0
   dc.w  %0101010101010101,0
   dc.w  0,0

   dc.w  %0100110101011010,0
   dc.w  %0100100101010010,0
   dc.w  %0100110101011010,0
   dc.w  %0100100110010010,0
   dc.w  %0110110100011011,0
   dc.w  0,0

sprLev
   dc.w  %0000000000000000,0
   dc.w  %0000000000000000,0
   dc.w  %0000000000000000,0
   dc.w  %0000000000000000,0
   dc.w  %0000000000000000,0
   dc.w  %0000000000000000,0
   dc.w  %0000000000000000,0
   dc.w  %0000000000000000,0
   dc.l  0

****************************************************
   SECTION  CleanGfx,BSS_C
screen:
   ds.b  BROW*SCR_HEIGHT*BPL
