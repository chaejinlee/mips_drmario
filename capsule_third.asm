################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Dr Mario.
#
# Student 1: Chaejin Lee, 1009332189
# Student 2: Name, Student Number (if applicable)
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    256
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################



############################################################
# Data Section
############################################################
.data
displayAddress:     .word 0x10008000   # 비디오 메모리 주소
keyboardAddress:    .word 0xffff0000

# Board: 32x32 격자, 각 셀 4바이트
# 0: 빈칸, 9: 벽, 1: 빨강, 2: 파랑, 3: 노랑
board:
    .space 4096    # 32*32*4 = 4096 bytes

removeFlags:
    .space 4096  # 32*32*4 = 4096 bytes (한 칸당 4바이트로 잡음)

# 캡슐 관련 변수
capsule_x:          .word 15
capsule_y:          .word 0
prev_capsule_x:     .word 15
prev_capsule_y:     .word 0
capsule_color:      .word 0xff0000       # 기본 빨강

capsule_color1:     .word 0xff0000   # 캡슐 첫번째 반쪽 (기본 빨강)
capsule_color2:     .word 0x0000ff   # 캡슐 두번째 반쪽 (기본 파랑)

# 새로 추가: 난수로 결정될 값 (1: 빨강, 2: 파랑, 3: 노랑)
capsule_left_color:  .word 1
capsule_right_color: .word 2

background_color:   .word 0x000000   # 지울 때 사용하는 색 (검정)

# 캡슐 방향: 0=가로, 1=세로 (기본: 가로)
capsule_orientation:.word 0

game_on:            .word 1          # 게임 진행 여부 (1: 진행, 0: 종료)
newCapsuleFlag:     .word 0          # 0: 정상, 1: 새 캡슐 생성됨
removeDelay:        .word 0 

############################################################
# Main Program
############################################################
.text
.globl main

main:

    # 초기화 단계
    jal init_bottle       # 보드 초기화 및 병 형태 설정
	jal draw_side_viruses
	jal draw_dr_mario
    jal place_viruses     # 바이러스 배치
    jal draw_screen       # 전체 보드 화면에 출력

    # 메인 게임 루프 실행
    jal loop_start

end_program:
    li $v0, 10
    syscall

end_game:
    # 화면 중앙에 10x10 셀 크기의 빨간 X 그리기
    li   $t0, 11        # startRow = 11
    li   $t1, 11        # startCol = 11
    li   $t2, 10        # size = 10
    li   $t3, 0         # i = 0

draw_x_loop:
    beq  $t3, $t2, after_draw_x  # i == 10이면 종료

    # --- 대각선 1: (startRow+i, startCol+i) ---
    add  $t4, $t0, $t3         # current row = 11 + i, $t4 사용
    add  $t5, $t1, $t3         # current col = 11 + i, $t5 사용
    la   $t6, displayAddress
    lw   $t6, 0($t6)          # 비디오 메모리 베이스 주소를 $t6에 로드
    mul  $t7, $t4, 32         # row * 32, $t7에 저장
    add  $t7, $t7, $t5        # row*32 + col
    sll  $t7, $t7, 2          # 각 셀 4바이트 곱셈
    add  $t6, $t6, $t7        # 최종 픽셀 주소 계산
    li   $t8, 0xff0000        # 빨간색 (0xff0000)을 $t8에 로드
    sw   $t8, 0($t6)          # 해당 위치에 빨간색으로 칠함

    # --- 대각선 2: (startRow+i, startCol+(size-1-i)) ---
    add  $t4, $t0, $t3         # current row = 11 + i (재사용)
    li   $t8, 9               # size-1 = 9를 $t8에 로드 (이전 $t8 값은 더 이상 필요없음)
    sub  $t9, $t8, $t3        # $t9 = 9 - i
    add  $t5, $t1, $t9        # current col = 11 + (9 - i), $t5 재사용
    la   $t6, displayAddress
    lw   $t6, 0($t6)
    mul  $t7, $t4, 32         # row * 32
    add  $t7, $t7, $t5        # row*32 + col
    sll  $t7, $t7, 2
    add  $t6, $t6, $t7
    li   $t8, 0xff0000        # 빨간색 다시 로드
    sw   $t8, 0($t6)

    addi $t3, $t3, 1          # i++
    j    draw_x_loop

after_draw_x:
   # 여기서 "retry" 옵션을 위한 키 입력 대기 루프
retry_loop:
    lw   $t0, 0xffff0000         # 키보드 입력 상태 체크 (메모리 맵 I/O)
    beq  $t0, $zero, retry_loop  # 키 입력이 없으면 계속 대기
    lw   $t1, 0xffff0004         # 키의 ASCII 코드 읽기
    li   $t2, 0x72               # 'r'의 ASCII 코드 (0x72 == 114)
    beq  $t1, $t2, do_retry       # 'r'이면 do_retry로 점프
    j    retry_loop              # 그 외의 입력은 무시하고 계속 대기

do_retry:
    # 게임 상태를 완전히 초기화한 후 메인 게임 루프 재시작

	# 전역 변수(게임 상태) 초기화
    jal reset_game_state
	
    jal init_bottle             # 보드 초기화 및 병 형태 설정
    jal draw_side_viruses       # 사이드 패널 바이러스 그리기
    jal draw_dr_mario           # Dr. Mario 이미지 그리기
    jal place_viruses           # 바이러스 배치
    jal draw_screen             # 전체 화면 그리기
    jal loop_start              # 메인 게임 루프 실행

############################################################
# Main Game Loop
############################################################
loop_start:
	
    ########################################################
    # 1. 이전 캡슐 위치 로드 및 지우기
    ########################################################
    la   $t0, prev_capsule_x
    lw   $t1, 0($t0)       # 이전 red x
    la   $t0, prev_capsule_y
    lw   $t2, 0($t0)       # 이전 red y

    move $s0, $t1         # $s0에 이전 red x 보존
    move $s1, $t2         # $s1에 이전 red y 보존

    # 빨간 부분 지우기
    move $a0, $s0
    move $a1, $s1
    jal erase_tile

    # 파란 부분 지우기 (캡슐 orientation에 따라 결정)
    la   $t8, capsule_orientation
    lw   $t9, 0($t8)
    beq  $t9, $zero, erase_blue_horizontal
    # 세로일 경우: blue = (red_x, red_y+1)
    move $a0, $s0
    addi $a1, $s1, 1
    j    erase_blue_done
erase_blue_horizontal:
    addi $a0, $s0, 1
    move $a1, $s1
erase_blue_done:
    jal erase_tile

    ########################################################
    # 2. 키 입력에 따른 캡슐 이동/회전 처리
    ########################################################
    lw   $t8, 0xffff0000   # 키 입력 상태 확인
    beq  $t8, $zero, skip_input
    lw   $t9, 0xffff0004   # 키의 ASCII 코드 읽기

    li   $s0, 0x77       # 'w'
    beq  $t9, $s0, rotate_capsule
    li   $s0, 0x61       # 'a'
    beq  $t9, $s0, move_left
    li   $s0, 0x73       # 's'
    beq  $t9, $s0, move_down
    li   $s0, 0x64       # 'd'
    beq  $t9, $s0, move_right
    li   $s0, 0x71       # 'q'
    beq  $t9, $s0, end_program

    j end_move_input
	
skip_input:
    # 키 입력 없으면 바로 다음으로

end_move_input:
    ########################################################
    # 3. 캡슐 그리기 및 착지 여부 체크
    ########################################################
    jal draw_capsule       # 새 위치에 캡슐 그리기
    # jal check_landing      # 착지 여부 검사 (착지하면 board에 고정 후 새 캡슐 생성)

	# 새 캡슐 생성 플래그(newCapsuleFlag)를 확인하여,
    # 1이면 이번 프레임에는 착지 체크를 건너뛰고(새 캡슐이 active 상태가 되도록),
    # 0이면 check_landing을 호출한다.
    la   $t0, newCapsuleFlag    # newCapsuleFlag의 주소를 $t0에 로드
    lw   $t1, 0($t0)            # $t1에 newCapsuleFlag의 값을 불러온다
    beq  $t1, $zero, call_check_landing  # 만약 newCapsuleFlag가 0이면 착지 체크를 실행
    j    skip_check_landing     # 그렇지 않으면(플래그가 1이면) 착지 체크를 건너뛴다

call_check_landing:
    jal check_landing           # 착지 여부 체크
skip_check_landing:

	# 새 캡슐 생성 플래그 처리 및 이전 좌표 업데이트 직전에,
    # 입구가 막혔는지 검사하는 코드 추가
    jal check_entrance_blocked
    la   $t0, game_on
    lw   $t1, 0($t0)
    beq  $t1, $zero, end_game  # 만약 game_on이 0이면 즉시 종료

    ########################################################
    # 4. 새 캡슐 생성 플래그 처리 및 이전 좌표 업데이트
    ########################################################
    # active 캡슐의 좌표를 항상 prev 좌표에 업데이트한다.
    la   $t0, capsule_x
    lw   $t1, 0($t0)        # $t1에 active 캡슐의 x 좌표 (새 캡슐 생성 후 값)
    la   $t0, capsule_y
    lw   $t2, 0($t0)        # $t2에 active 캡슐의 y 좌표 (새 캡슐 생성 후 값)
    la   $t0, prev_capsule_x
    sw   $t1, 0($t0)        # prev_capsule_x를 새 캡슐의 x 좌표로 업데이트
    la   $t0, prev_capsule_y
    sw   $t2, 0($t0)        # prev_capsule_y를 새 캡슐의 y 좌표로 업데이트

    # newCapsuleFlag는 항상 클리어한다.
    la   $t0, newCapsuleFlag
    li   $t1, 0
    sw   $t1, 0($t0)

	########################################################
    # 5. 프레임 딜레이 전에 연쇄 제거 처리
    ########################################################
    # bne  $s2, $zero, skip_remove_matches   # $s2가 1이면 제거 건너뛰기
    jal remove_matches                       # $s2가 0이면 remove_matches 실행
# skip_remove_matches:
#     li   $s2, 0                             # 플래그를 0으로 클리어


    ########################################################
    # 5. 프레임 딜레이 (~16ms, 60fps)
    ########################################################
    li  $v0, 32
    li  $a0, 16
    syscall

    j loop_start         # 다음 프레임 루프

############################################################
# Movement & Rotation Functions
############################################################
move_left:

	li   $v0, 33 
      # Simulate key press 'A' -> Play E4
      li   $a0, 0x40          # MIDI note E4 (64 in decimal)
      li   $a1, 0x64          # Duration 1000 ms
      li   $a2, 0x50          # Instrument (80 = Synth Lead)
      li   $a3, 0x64          # Volume (100)
      syscall
	  
    la   $t0, capsule_x
    lw   $t1, 0($t0)
    addi $t1, $t1, -1
    la   $t2, capsule_y
    lw   $t3, 0($t2)
    mul  $t4, $t3, 32
    add  $t4, $t4, $t1
    sll  $t4, $t4, 2
    la   $t5, board
    add  $t5, $t5, $t4
    lw   $t6, 0($t5)
    li   $t7, 9
    beq  $t6, $t7, skip_move_left
    la   $t0, capsule_x
    sw   $t1, 0($t0)
	
skip_move_left:
    j clamp_xy

move_down:

	li   $v0, 33 
      # Simulate key press 'A' -> Play E4
      li   $a0, 0x45          # MIDI note E4 (64 in decimal)
      li   $a1, 0x64          # Duration 1000 ms
      li   $a2, 0x50          # Instrument (80 = Synth Lead)
      li   $a3, 0x64          # Volume (100)
      syscall
	
    la  $t3, capsule_y
    lw  $t4, 0($t3)
    addi $t4, $t4, 1
    sw   $t4, 0($t3)
    j clamp_xy

move_right:

	li   $v0, 33 
      # Simulate key press 'A' -> Play E4
      li   $a0, 0x50          # MIDI note E4 (64 in decimal)
      li   $a1, 0x64          # Duration 1000 ms
      li   $a2, 0x50          # Instrument (80 = Synth Lead)
      li   $a3, 0x64          # Volume (100)
      syscall
	
    la   $t0, capsule_x
    lw   $t1, 0($t0)
    la   $t2, capsule_y
    lw   $t3, 0($t2)
    addi $t1, $t1, 1
    addi $t4, $t1, 1
    mul  $t5, $t3, 32      
    add  $t5, $t5, $t4     
    sll  $t5, $t5, 2       
    la   $t6, board       
    add  $t6, $t6, $t5     
    lw   $t7, 0($t6)
    li   $t8, 9
    beq  $t7, $t8, skip_move_right
    la   $t0, capsule_x
    sw   $t1, 0($t0)
skip_move_right:
    j clamp_xy

rotate_capsule:

	li   $v0, 33 
      # Simulate key press 'A' -> Play E4
      li   $a0, 0x55          # MIDI note E4 (64 in decimal)
      li   $a1, 0x64          # Duration 1000 ms
      li   $a2, 0x50          # Instrument (80 = Synth Lead)
      li   $a3, 0x64          # Volume (100)
      syscall
	  
    la   $t0, capsule_orientation
    lw   $t1, 0($t0)
    xori $t1, $t1, 1
    la   $t2, capsule_x
    lw   $t3, 0($t2)
    la   $t4, capsule_y
    lw   $t5, 0($t4)
    beq  $t1, $zero, rotate_horizontal_candidate
    move $t6, $t3
    addi $t7, $t5, 1
    j    rotate_check_candidate
rotate_horizontal_candidate:
    addi $t6, $t3, 1
    move $t7, $t5
rotate_check_candidate:
    li   $t8, 32
    bge  $t6, $t8, rotate_fail
    bge  $t7, $t8, rotate_fail
    mul  $t9, $t7, 32
    add  $t9, $t9, $t6
    sll  $t9, $t9, 2
    la   $a0, board
    add  $a0, $a0, $t9
    lw   $t0, 0($a0)
    bne  $t0, $zero, rotate_fail
    la   $t0, capsule_orientation
    sw   $t1, 0($t0)
    jr   $ra
rotate_fail:
    jr   $ra

clamp_xy:
    la   $t5, capsule_x
    lw   $t6, 0($t5)
    bltz $t6, fix_x_low
    li   $s0, 31
    bgt  $t6, $s0, fix_x_high
check_y:
    la   $t7, capsule_y
    lw   $t8, 0($t7)
    bltz $t8, fix_y_low
    li   $s0, 31
    bgt  $t8, $s0, fix_y_high
    j end_move_input
fix_x_low:
    li $t6, 0
    sw $t6, 0($t5)
    j check_y
fix_x_high:
    li $t6, 31
    sw $t6, 0($t5)
    j check_y
fix_y_low:
    li $t8, 0
    sw $t8, 0($t7)
    j end_move_input
fix_y_high:
    li $t8, 31
    sw $t8, 0($t7)
# end_move_input:
    jr $ra

############################################################
# Drawing Functions
############################################################

erase_tile:
    la   $t0, displayAddress
    lw   $t0, 0($t0)
    la   $t1, background_color
    lw   $t2, 0($t1)
    mul  $t3, $a1, 32
    add  $t3, $t3, $a0
    sll  $t3, $t3, 2
    add  $t0, $t0, $t3
    sw   $t2, 0($t0)
    jr $ra

draw_capsule:
    # Draw red half using capsule_color1
    la   $t0, displayAddress
    lw   $t0, 0($t0)
    la   $t1, capsule_x
    lw   $t2, 0($t1)
    la   $t1, capsule_y
    lw   $t3, 0($t1)
    mul  $t4, $t3, 32
    add  $t4, $t4, $t2
    sll  $t4, $t4, 2
    add  $t0, $t0, $t4
    la   $t5, capsule_color1
    lw   $t6, 0($t5)
    sw   $t6, 0($t0)
    # Draw blue half using capsule_color2
    la   $t7, capsule_orientation
    lw   $t8, 0($t7)
    la   $t1, capsule_x
    lw   $t2, 0($t1)
    la   $t1, capsule_y
    lw   $t3, 0($t1)
    beq  $t8, $zero, draw_blue_horizontal_modified
    addi $t3, $t3, 1
    j    draw_blue_modified
draw_blue_horizontal_modified:
    addi $t2, $t2, 1
draw_blue_modified:
    la   $t0, displayAddress
    lw   $t0, 0($t0)
    mul  $t4, $t3, 32
    add  $t4, $t4, $t2
    sll  $t4, $t4, 2
    add  $t0, $t0, $t4
    la   $t5, capsule_color2
    lw   $t6, 0($t5)
    sw   $t6, 0($t0)
    jr $ra

draw_screen:
    la   $t0, displayAddress
    lw   $t0, 0($t0)
    la   $t1, board
    li   $t2, 0
draw_screen_loop:
    lw   $t3, 0($t1)
    # 0: 빈 칸 → 검정색 (배경색)
    beq  $t3, $zero, set_black
    # 9: 벽 → 회색
    li   $t4, 9
    beq  $t3, $t4, set_gray
    # 그 외에는 이미 24비트 색상 값이 들어있음
    move $t4, $t3
    j write_pixel
set_black:
    li   $t4, 0x000000
    j write_pixel
set_gray:
    li   $t4, 0x808080
write_pixel:
    li   $t5, 4
    mul  $t5, $t2, $t5
    add  $t5, $t0, $t5
    sw   $t4, 0($t5)
    addi $t1, $t1, 4
    addi $t2, $t2, 1
    li   $t6, 1024
    blt  $t2, $t6, draw_screen_loop
    jr $ra


############################################################
# Landing & New Capsule Functions
############################################################

check_landing:
    la   $t0, capsule_x
    lw   $t1, 0($t0)
    la   $t0, capsule_y
    lw   $t2, 0($t0)
    la   $t0, capsule_orientation
    lw   $t3, 0($t0)
    li   $t8, 32
    beq  $t3, $zero, check_landing_horizontal
    j    check_landing_vertical
check_landing_horizontal:
    addi $t4, $t2, 1
    bge  $t4, $t8, landed
    mul  $t5, $t4, 32
    add  $t5, $t5, $t1
    sll  $t5, $t5, 2
    la   $t6, board
    add  $t6, $t6, $t5
    lw   $t7, 0($t6)
    addi $t9, $t1, 1
    mul  $s0, $t4, 32
    add  $s0, $s0, $t9
    sll  $s0, $s0, 2
    la   $s1, board
    add  $s1, $s1, $s0
    lw   $s0, 0($s1)
    bne  $t7, $zero, landed
    bne  $s0, $zero, landed
    jr   $ra
check_landing_vertical:
    addi $t4, $t2, 2
    bge  $t4, $t8, landed
    mul  $t5, $t4, 32
    add  $t5, $t5, $t1
    sll  $t5, $t5, 2
    la   $t6, board
    add  $t6, $t6, $t5
    lw   $t7, 0($t6)
    bne  $t7, $zero, landed
    jr   $ra
landed:
    la   $t0, capsule_orientation
    lw   $t1, 0($t0)
    la   $t2, capsule_x
    lw   $t3, 0($t2)
    la   $t4, capsule_y
    lw   $t5, 0($t4)
    beq  $t1, $zero, fix_horizontal
    mul  $t6, $t5, 32
    add  $t6, $t6, $t3
    sll  $t6, $t6, 2
    la   $t7, board
    add  $t7, $t7, $t6
    la   $t8, capsule_color1
    lw   $t9, 0($t8)
    sw   $t9, 0($t7)
    addi $t5, $t5, 1
    mul  $t6, $t5, 32
    add  $t6, $t6, $t3
    sll  $t6, $t6, 2
    la   $t7, board
    add  $t7, $t7, $t6
    la   $t8, capsule_color2
    lw   $t9, 0($t8)
    sw   $t9, 0($t7)
    j call_new_capsule
fix_horizontal:
    mul  $t6, $t5, 32
    add  $t6, $t6, $t3
    sll  $t6, $t6, 2
    la   $t7, board
    add  $t7, $t7, $t6
    la   $t8, capsule_color1
    lw   $t9, 0($t8)
    sw   $t9, 0($t7)
    addi $t3, $t3, 1
    mul  $t6, $t5, 32
    add  $t6, $t6, $t3
    sll  $t6, $t6, 2
    la   $t7, board
    add  $t7, $t7, $t6
    la   $t8, capsule_color2
    lw   $t9, 0($t8)
    sw   $t9, 0($t7)

	addi $sp, $sp, -4     # 스택 포인터를 4바이트 줄여서
    sw   $ra, 0($sp)      # 현재 $ra 값을 스택에 저장
    jal  new_capsule      # new_capsule 호출 (여기서 $ra가 변경됨)
    lw   $ra, 0($sp)      # new_capsule이 반환한 후 스택에서 $ra 복원
    addi $sp, $sp, 4      # 스택 포인터를 원래대로 복원
    jr   $ra             # 원래 호출한 곳으로 돌아감


call_new_capsule:
    addi $sp, $sp, -4     # 스택 포인터를 4바이트 줄여서 공간 확보
    sw   $ra, 0($sp)      # 현재 $ra 값을 스택에 저장 (현재 함수로 돌아갈 주소 보존)
    jal  new_capsule      # new_capsule 함수를 호출 (여기서 $ra가 새 반환 주소로 덮어써질 수 있음)
    lw   $ra, 0($sp)      # new_capsule이 반환한 후 스택에서 원래의 $ra 값을 복원
    addi $sp, $sp, 4      # 스택 포인터를 원래대로 복원
    jr   $ra             # 저장된 반환 주소로 돌아간다.

new_capsule:

	addi $sp, $sp, -4   # 스택에 공간 할당
    sw   $ra, 0($sp)    # 원래의 $ra 값을 저장


    # 새 캡슐 생성: 좌표를 (15,0)으로 설정 (예제에서는 입구 위치)
    li   $t0, 15
    la   $t1, capsule_x
    sw   $t0, 0($t1)

    li   $t0, 0
    la   $t1, capsule_y
    sw   $t0, 0($t1)

    # 캡슐 방향을 0 (가로)로 설정
    li   $t0, 0
    la   $t1, capsule_orientation
    sw   $t0, 0($t1)
	
    # 캡슐 색상을 난수로 결정하기 위해 randomize_capsule_colors 호출
    jal  randomize_capsule_colors

    # --- 왼쪽 캡슐 색상 매핑: capsule_left_color (1,2,3) → 실제 24비트 색상 ---
    la   $t0, capsule_left_color
    lw   $t1, 0($t0)      # $t1 값: 1, 2, 또는 3
    li   $t2, 1
    beq  $t1, $t2, left_red
    li   $t2, 2
    beq  $t1, $t2, left_blue
    li   $t2, 3
    beq  $t1, $t2, left_yellow
left_red:
    li   $t3, 0xff0000    # 빨강
    j    left_done
left_blue:
    li   $t3, 0x0000ff    # 파랑
    j    left_done
left_yellow:
    li   $t3, 0xffff00    # 노랑
left_done:
    la   $t0, capsule_color1
    sw   $t3, 0($t0)

    # --- 오른쪽 캡슐 색상 매핑: capsule_right_color (1,2,3) → 실제 24비트 색상 ---
    la   $t0, capsule_right_color
    lw   $t1, 0($t0)
    li   $t2, 1
    beq  $t1, $t2, right_red
    li   $t2, 2
    beq  $t1, $t2, right_blue
    li   $t2, 3
    beq  $t1, $t2, right_yellow
right_red:
    li   $t3, 0xff0000    # 빨강
    j    right_done
right_blue:
    li   $t3, 0x0000ff    # 파랑
    j    right_done
right_yellow:
    li   $t3, 0xffff00    # 노랑
right_done:
    la   $t0, capsule_color2
    sw   $t3, 0($t0)
	
    # 새 캡슐 생성 플래그를 1로 설정
    li   $t0, 1
    la   $t1, newCapsuleFlag
    sw   $t0, 0($t1)
	
    # 이전 캡슐 좌표(prev)를 새 캡슐 좌표와 동기화
    la   $t0, capsule_x
    lw   $t1, 0($t0)
    la   $t0, prev_capsule_x
    sw   $t1, 0($t0)
	
    la   $t0, capsule_y
    lw   $t1, 0($t0)
    la   $t0, prev_capsule_y
    sw   $t1, 0($t0)
	
    # # removeDelay를 글로벌 플래그 $s2에 설정
    # li   $s2, 1

	lw   $ra, 0($sp)    # 스택에서 $ra 복원
    addi $sp, $sp, 4    # 스택 포인터 복원
    jr   $ra

# end_game_new_capsule:
#     # 게임 종료 처리를 위해 적절한 종료 루틴으로 점프하거나, 리턴하도록 함.
#     j   end_program

############################################################
# check_entrance_blocked
#   - row 1, 칼럼 14~17 검사
#   - 만약 4칸 모두 0이나 9가 아니면 (즉, 색상이 채워져 있으면)
#     game_on을 0으로 설정하여 게임 종료 처리
############################################################
check_entrance_blocked:
    li   $t0, 14         # 시작 칼럼 14
    li   $t7, 0          # 채워진 칼럼 개수를 세는 카운터 초기화
    la   $t1, board      # board 배열의 시작 주소

    # row 1: row index = 1, 즉 row offset = 1*32 = 32 (셀 단위)
    li   $t2, 32         # 한 행의 셀 개수
    li   $t3, 1          # 검사할 row 번호 (여기서는 1)

    # row offset 계산: row * 32 (셀 단위)
    mul  $t4, $t3, $t2   # $t4 = row offset (셀 단위)

check_loop:
    # 현재 검사할 셀 인덱스 = row offset + current column (14~17)
    add  $t5, $t4, $t0   # $t5 = (1*32 + col)
    sll  $t5, $t5, 2     # 4바이트 단위로 변환 (offset in bytes)
    add  $t5, $t1, $t5   # $t5 = 주소(board[1][col])
    lw   $t6, 0($t5)     # $t6 = board[1][col]의 값

    # 만약 빈 칸(0) 또는 벽(9)이면 입구가 열려 있으므로 바로 리턴
    beq  $t6, $zero, not_blocked
    li   $t8, 9
    beq  $t6, $t8, not_blocked

    # 해당 칼럼이 색상으로 채워졌으므로 카운터 증가
    addi $t7, $t7, 1

    # 다음 칼럼으로 진행: 칼럼 14에서 17까지 검사
    addi $t0, $t0, 1
    li   $t9, 18         # 14,15,16,17 => 4칸, 즉 $t0가 18이면 종료
    blt  $t0, $t9, check_loop

    # 만약 카운터가 4라면 4칸 모두 색상으로 채워진 것임.
    li   $t9, 4
    beq  $t7, $t9, block_entrance

not_blocked:
    jr   $ra            # 입구가 열려 있으므로 리턴

block_entrance:
    # 입구가 막혔으므로 game_on을 0으로 설정
    li   $t9, 0
    la   $t8, game_on
    sw   $t9, 0($t8)
    jr   $ra


##############################################################################
# randomize_capsule_colors
#  - 캡슐 두 반쪽을 1..3 (빨강, 파랑, 노랑) 중 무작위로 설정
##############################################################################
randomize_capsule_colors:
    # 왼쪽 반쪽
    li   $v0, 42         # 난수 생성 syscall
    li   $a0, 0          # 기본 generator id (0)
    li   $a1, 3          # 최대값 3
    syscall
    addi $a0, $a0, 1     # 결과를 1~3 범위로 조정
    la   $t0, capsule_left_color
    sw   $a0, 0($t0)

    # 오른쪽 반쪽
    li   $v0, 42
    li   $a0, 0
    li   $a1, 3
    syscall
    addi $a0, $a0, 1
    la   $t1, capsule_right_color
    sw   $a0, 0($t1)
    jr   $ra

############################################################
# Initialization Functions
############################################################

init_bottle:
    # 전체 보드를 0으로 초기화
    la   $t0, board
    li   $t1, 0
init_clear_loop:
    sw   $zero, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, 1
    li   $t2, 1024
    blt  $t1, $t2, init_clear_loop
    # 병 목 (row=0, row=1)
    li   $s0, 0
    li   $s1, 0
bottle_row0_loop:
    li   $t3, 14
    li   $t4, 17
    li   $t5, 9
    blt  $s1, $t3, set_wall_0
    bgt  $s1, $t4, set_wall_0
    move $t5, $zero
set_wall_0:
    mul  $t6, $s0, 32
    add  $t6, $t6, $s1
    sll  $t6, $t6, 2
    la   $t7, board
    add  $t7, $t7, $t6
    sw   $t5, 0($t7)
    addi $s1, $s1, 1
    li   $t8, 32
    blt  $s1, $t8, bottle_row0_loop
    li   $s0, 1
    li   $s1, 0
bottle_row1_loop:
    li   $t3, 14
    li   $t4, 17
    li   $t5, 9
    blt  $s1, $t3, set_wall_1
    bgt  $s1, $t4, set_wall_1
    move $t5, $zero
set_wall_1:
    mul  $t6, $s0, 32
    add  $t6, $t6, $s1
    sll  $t6, $t6, 2
    la   $t7, board
    add  $t7, $t7, $t6
    sw   $t5, 0($t7)
    addi $s1, $s1, 1
    li   $t8, 32
    blt  $s1, $t8, bottle_row1_loop
	
    # 병 몸통 (row = 2 ~ 28)
    li   $s0, 2        # row index 시작 (2)
bottle_body_rows:
    li   $s1, 0        # 각 행의 열 index 초기화 (0부터 시작)
bottle_body_cols:
    li   $t5, 0        # 기본값: 빈 칸(0)
    # 만약 현재 열($s1)이 4 이하이면 벽으로 설정
    li   $t9, 4
    ble  $s1, $t9, set_wall_body2
    # 또는 현재 열($s1)이 27 이상이면 벽으로 설정
    li   $t9, 27
    bge  $s1, $t9, set_wall_body2
    j    skip_wall_body2

set_wall_body2:
    li   $t5, 9        # 벽 값 9로 설정

skip_wall_body2:
    # 현재 셀의 주소 계산: (row*32 + col) * 4
    mul  $t6, $s0, 32
    add  $t6, $t6, $s1
    sll  $t6, $t6, 2
    la   $t7, board
    add  $t7, $t7, $t6
    sw   $t5, 0($t7)

    addi $s1, $s1, 1    # 다음 열
    li   $t8, 32
    blt  $s1, $t8, bottle_body_cols

    addi $s0, $s0, 1    # 다음 행
    li   $t8, 29       # row 2부터 28까지 (즉, s0 < 29)
    blt  $s0, $t8, bottle_body_rows
    # 병 바닥 (row=51..63)
    li   $s0, 29
bottle_bottom_rows:
    li   $s1, 0
bottle_bottom_cols:
    mul  $t6, $s0, 32
    add  $t6, $t6, $s1
    sll  $t6, $t6, 2
    la   $t7, board
    add  $t7, $t7, $t6
    li   $t5, 9
    sw   $t5, 0($t7)
    addi $s1, $s1, 1
    li   $t8, 32
    blt  $s1, $t8, bottle_bottom_cols
    addi $s0, $s0, 1
    li   $t9, 32
    blt  $s0, $t9, bottle_bottom_rows
    jr   $ra

draw_dr_mario:
    # Row 20: columns 29,30 -> 빨강 (0xff0000)
    # Row 20, column 29
    li   $t0, 29          # col = 29
    li   $t1, 20          # row = 20
    mul  $t2, $t1, 32     # t2 = row * 32
    add  $t2, $t2, $t0    # t2 = row*32 + col
    sll  $t2, $t2, 2      # offset = (row*32+col)*4
    la   $t3, board
    add  $t3, $t3, $t2
    li   $t4, 0xff0000    # 빨강
    sw   $t4, 0($t3)
    
    # Row 20, column 30
    li   $t0, 30         # col = 30
    li   $t1, 20         # row = 20
    mul  $t2, $t1, 32    
    add  $t2, $t2, $t0   
    sll  $t2, $t2, 2     
    la   $t3, board
    add  $t3, $t3, $t2
    li   $t4, 0xff0000    # 빨강
    sw   $t4, 0($t3)
    
    # Row 21: columns 28,29,30 -> 빨강 (0xff0000)
    li   $t1, 21         # row = 21
    # Column 28
    li   $t0, 28         # col = 28
    mul  $t2, $t1, 32    
    add  $t2, $t2, $t0   
    sll  $t2, $t2, 2     
    la   $t3, board
    add  $t3, $t3, $t2
    li   $t4, 0xff0000    # 빨강
    sw   $t4, 0($t3)
    
    # Column 29
    li   $t0, 29         # col = 29
    mul  $t2, $t1, 32    
    add  $t2, $t2, $t0   
    sll  $t2, $t2, 2     
    la   $t3, board
    add  $t3, $t3, $t2
    li   $t4, 0xff0000    # 빨강
    sw   $t4, 0($t3)
    
    # Column 30
    li   $t0, 30         # col = 30
    mul  $t2, $t1, 32    
    add  $t2, $t2, $t0   
    sll  $t2, $t2, 2     
    la   $t3, board
    add  $t3, $t3, $t2
    li   $t4, 0xff0000    # 빨강
    sw   $t4, 0($t3)

	# Column 31
    li   $t0, 31         # col = 30
    mul  $t2, $t1, 32    
    add  $t2, $t2, $t0   
    sll  $t2, $t2, 2     
    la   $t3, board
    add  $t3, $t3, $t2
    li   $t4, 0xff0000    # 빨강
    sw   $t4, 0($t3)
    
    # Row 22: 
    #   Column 28 -> 노랑 (0xffff00)
    #   Columns 29,30 -> 검정 (0x000000)
    #   Column 31 -> 노랑 (0xffff00)
    li   $t1, 22         # row = 22
    # Column 28
    li   $t0, 28
    mul  $t2, $t1, 32
    add  $t2, $t2, $t0
    sll  $t2, $t2, 2
    la   $t3, board
    add  $t3, $t3, $t2
    li   $t4, 0xffff00    # 노랑
    sw   $t4, 0($t3)
    
    # Column 29
    li   $t0, 29
    mul  $t2, $t1, 32
    add  $t2, $t2, $t0
    sll  $t2, $t2, 2
    la   $t3, board
    add  $t3, $t3, $t2
    li   $t4, 0x000000    # 검정
    sw   $t4, 0($t3)
    
    # Column 30
    li   $t0, 30
    mul  $t2, $t1, 32
    add  $t2, $t2, $t0
    sll  $t2, $t2, 2
    la   $t3, board
    add  $t3, $t3, $t2
    li   $t4, 0x000000    # 검정
    sw   $t4, 0($t3)
    
    # Column 31
    li   $t0, 31
    mul  $t2, $t1, 32
    add  $t2, $t2, $t0
    sll  $t2, $t2, 2
    la   $t3, board
    add  $t3, $t3, $t2
    li   $t4, 0xffff00    # 노랑
    sw   $t4, 0($t3)
    
    # Row 23: columns 28,29,30,31 -> 모두 노랑 (0xffff00)
    li   $t1, 23         # row = 23
    # Column 28
    li   $t0, 28
    mul  $t2, $t1, 32
    add  $t2, $t2, $t0
    sll  $t2, $t2, 2
    la   $t3, board
    add  $t3, $t3, $t2
    li   $t4, 0xffff00    # 노랑
    sw   $t4, 0($t3)
    
    # Column 29
    li   $t0, 29
    mul  $t2, $t1, 32
    add  $t2, $t2, $t0
    sll  $t2, $t2, 2
    la   $t3, board
    add  $t3, $t3, $t2
    li   $t4, 0xffff00    # 노랑
    sw   $t4, 0($t3)
    
    # Column 30
    li   $t0, 30
    mul  $t2, $t1, 32
    add  $t2, $t2, $t0
    sll  $t2, $t2, 2
    la   $t3, board
    add  $t3, $t3, $t2
    li   $t4, 0xffff00    # 노랑
    sw   $t4, 0($t3)
    
    # Column 31
    li   $t0, 31
    mul  $t2, $t1, 32
    add  $t2, $t2, $t0
    sll  $t2, $t2, 2
    la   $t3, board
    add  $t3, $t3, $t2
    li   $t4, 0xffff00    # 노랑
    sw   $t4, 0($t3)
    
    jr   $ra


############################################################
# draw_side_viruses
#   - 사이드 패널에 바이러스를 그린다.
#   - 위치: column 2, row 8, 12, 16, 20 (즉, 8열부터 4칸 간격)
#   - 색상 순서: 빨강, 빨강, 파랑, 노랑
############################################################
draw_side_viruses:
    # Virus 1: (2, 8) 빨강
    li   $t0, 2           # col = 2
    li   $t1, 8           # row = 8
    mul  $t2, $t1, 32     # t2 = row * 32
    add  $t2, $t2, $t0    # t2 = row*32 + col
    sll  $t2, $t2, 2      # 각 셀 4바이트: offset = (row*32 + col)*4
    la   $t3, board      # board의 시작 주소
    add  $t3, $t3, $t2   # 해당 셀 주소
    li   $t4, 0xff0000    # 빨강
    sw   $t4, 0($t3)      # Virus 1 그리기

    # Virus 2: (2, 12) 빨강
    li   $t0, 2           # col = 2
    li   $t1, 12          # row = 12
    mul  $t2, $t1, 32     
    add  $t2, $t2, $t0    
    sll  $t2, $t2, 2      
    la   $t3, board      
    add  $t3, $t3, $t2   
    li   $t4, 0xff0000    # 빨강
    sw   $t4, 0($t3)      # Virus 2 그리기

    # Virus 3: (2, 16) 파랑
    li   $t0, 2           # col = 2
    li   $t1, 16          # row = 16
    mul  $t2, $t1, 32     
    add  $t2, $t2, $t0    
    sll  $t2, $t2, 2      
    la   $t3, board      
    add  $t3, $t3, $t2   
    li   $t4, 0x0000ff    # 파랑
    sw   $t4, 0($t3)      # Virus 3 그리기

    # Virus 4: (2, 20) 노랑
    li   $t0, 2           # col = 2
    li   $t1, 20          # row = 20
    mul  $t2, $t1, 32     
    add  $t2, $t2, $t0    
    sll  $t2, $t2, 2      
    la   $t3, board      
    add  $t3, $t3, $t2   
    li   $t4, 0xffff00    # 노랑
    sw   $t4, 0($t3)      # Virus 4 그리기

    jr   $ra              # 호출한 곳으로 복귀


place_viruses:
    # 바이러스 1: (6, 18) 빨강 (0xff0000)
    li   $t0, 6
    li   $t1, 18
    mul  $t2, $t1, 32
    add  $t2, $t2, $t0
    sll  $t2, $t2, 2
    la   $t3, board
    add  $t3, $t3, $t2
    li   $t4, 0xff0000
    sw   $t4, 0($t3)

    # 바이러스 2: (23, 25) 빨강 (0xff0000)
    li   $t0, 23
    li   $t1, 25
    mul  $t2, $t1, 32
    add  $t2, $t2, $t0
    sll  $t2, $t2, 2
    la   $t3, board
    add  $t3, $t3, $t2
    li   $t4, 0xff0000
    sw   $t4, 0($t3)

    # 바이러스 3: (13, 22) 파랑 (0x0000ff)
    li   $t0, 13
    li   $t1, 22
    mul  $t2, $t1, 32
    add  $t2, $t2, $t0
    sll  $t2, $t2, 2
    la   $t3, board
    add  $t3, $t3, $t2
    li   $t4, 0x0000ff
    sw   $t4, 0($t3)

    # 바이러스 4: (18, 28) 노랑 (0xffff00)
    li   $t0, 18
    li   $t1, 28
    mul  $t2, $t1, 32
    add  $t2, $t2, $t0
    sll  $t2, $t2, 2
    la   $t3, board
    add  $t3, $t3, $t2
    li   $t4, 0xffff00
    sw   $t4, 0($t3)
    jr   $ra


############################################################
# remove_matches 함수
# 보드 전체를 스캔하여, 세로 방향으로 같은 색(1,2,3)의 블록 4개가
# 연속되어 있으면 그 블록들을 제거(0으로 설정)하고, 해당 셀을
# 배경색(검은색)으로 칠한다.
############################################################
remove_matches:
	addi  $sp, $sp, -4     # $ra 저장을 위한 스택 공간 확보
    sw    $ra, 0($sp)
    li   $t0, 0          # $t0: 열(col) 인덱스 (0~31)
col_loop:
    li   $t8, 32
    bge  $t0, $t8, remove_matches_end  # 열 인덱스가 32 이상이면 종료

    li   $t1, 0          # $t1: 행(row) 인덱스 (0부터 시작)
row_loop:
    li   $t8, 29
    bge  $t1, $t8, next_col   # 마지막 3행은 검사하지 않음

    # 현재 셀 (row, col)의 주소 계산
    mul  $t2, $t1, 32     # $t2 = row * 32
    add  $t2, $t2, $t0    # $t2 = row*32 + col
    sll  $t2, $t2, 2      # 각 셀 4바이트 크기이므로 *4
    la   $t3, board
    add  $t3, $t3, $t2   # $t3 = 주소(board[row][col])
    lw   $t4, 0($t3)     # $t4 = board[row][col]의 값

    # 빈 칸(0)이나 벽(9)이면 건너뛰기
    beq  $t4, $zero, skip_match
    li   $t8, 9
    beq  $t4, $t8, skip_match

    # 세로 4칸 일치 검사: (row+1, col), (row+2, col), (row+3, col)
    addi $t5, $t1, 1     # $t5 = row+1
    mul  $t6, $t5, 32
    add  $t6, $t6, $t0
    sll  $t6, $t6, 2
    la   $t7, board
    add  $t7, $t7, $t6
    lw   $t5, 0($t7)     # board[row+1][col]
    bne  $t4, $t5, skip_match

    addi $t5, $t1, 2     # $t5 = row+2
    mul  $t6, $t5, 32
    add  $t6, $t6, $t0
    sll  $t6, $t6, 2
    la   $t7, board
    add  $t7, $t7, $t6
    lw   $t5, 0($t7)     # board[row+2][col]
    bne  $t4, $t5, skip_match

    addi $t5, $t1, 3     # $t5 = row+3
    mul  $t6, $t5, 32
    add  $t6, $t6, $t0
    sll  $t6, $t6, 2
    la   $t7, board
    add  $t7, $t7, $t6
    lw   $t5, 0($t7)     # board[row+3][col]
    bne  $t4, $t5, skip_match

    # # 연속 4개 블록이 일치하면 제거
    # li   $t8, 0         # 0: 빈 칸

        # (row, col) 위치 제거
    move   $s0, $t0       # $s0에 현재 열(col) 저장
    move   $s1, $t1       # $s1에 현재 행(row) 저장
    move   $a0, $s0       # erase_tile에 열 전달
    move   $a1, $s1       # erase_tile에 행 전달
    jal    erase_tile

	# board 배열에서도 해당 셀을 0으로 업데이트
    mul  $t6, $s1, 32
    add  $t6, $t6, $s0
    sll  $t6, $t6, 2
    la   $t7, board
    add  $t7, $t7, $t6
    sw   $zero, 0($t7)

    # # (row+1, col) 위치 제거
    # move   $a0, $s0       # 열은 그대로
    # addi   $a1, $s1, 1    # 행에 1 더해서 전달
    # jal    erase_tile

    # # (row+2, col) 위치 제거
    # move   $a0, $s0
    # addi   $a1, $s1, 2
    # jal    erase_tile

    # # (row+3, col) 위치 제거
    # move   $a0, $s0
    # addi   $a1, $s1, 3
    # jal    erase_tile

	# --- (row+1, col) 위치 ---
    move   $a0, $s0       # 열은 그대로
    addi   $a1, $s1, 1    # 행에 1 더해서 전달
    jal    erase_tile
    addi $t8, $s1, 1
    mul  $t6, $t8, 32
    add  $t6, $t6, $s0
    sll  $t6, $t6, 2
    la   $t7, board
    add  $t7, $t7, $t6
    sw   $zero, 0($t7)

    # --- (row+2, col) 위치 ---
    move   $a0, $s0
    addi   $a1, $s1, 2
    jal    erase_tile
    addi $t8, $s1, 2
    mul  $t6, $t8, 32
    add  $t6, $t6, $s0
    sll  $t6, $t6, 2
    la   $t7, board 
    add  $t7, $t7, $t6
    sw   $zero, 0($t7)

    # --- (row+3, col) 위치 ---
    move   $a0, $s0
    addi   $a1, $s1, 3
    jal    erase_tile
    addi $t8, $s1, 3
    mul  $t6, $t8, 32
    add  $t6, $t6, $s0
    sll  $t6, $t6, 2
    la   $t7, board
    add  $t7, $t7, $t6
    sw   $zero, 0($t7)

	# 4개의 타일을 제거한 후 캡슐 좌표를 (15, 0)으로 강제로 설정
    li     $t0, 15
    la     $t1, capsule_x
    sw     $t0, 0($t1)
    li     $t0, 0
    la     $t1, capsule_y
    sw     $t0, 0($t1)

    # 이전 캡슐 좌표(prev)를 (15, 0)으로 설정
    li     $t0, 15
    la     $t1, prev_capsule_x
    sw     $t0, 0($t1)
    li     $t0, 0
    la     $t1, prev_capsule_y
    sw     $t0, 0($t1)

	# 4개의 타일을 제거한 후 즉시 함수를 종료하도록 함
    j remove_matches_end
	nop


skip_match:
    addi $t1, $t1, 1   # 다음 행으로
    j    row_loop

next_col:
    addi $t0, $t0, 1   # 다음 열로
    j    col_loop

remove_matches_end:
	lw    $ra, 0($sp)   # 스택에서 $ra 복원
    addi  $sp, $sp, 4
    jr   $ra
	nop

############################################################
# Game Over & Retry 처리 코드
############################################################

# 게임 전역 상태를 초기화하는 서브루틴
# capsule_x, capsule_y, prev_capsule_x, prev_capsule_y, newCapsuleFlag,
# game_on, capsule_orientation 등 초기값으로 설정
reset_game_state:
    # capsule_x 초기화 (예: 15)
    li   $t0, 15
    la   $t1, capsule_x
    sw   $t0, 0($t1)
    
    # capsule_y 초기화 (예: 0)
    li   $t0, 0
    la   $t1, capsule_y
    sw   $t0, 0($t1)
    
    # prev_capsule_x 초기화 (예: 15)
    li   $t0, 15
    la   $t1, prev_capsule_x
    sw   $t0, 0($t1)
    
    # prev_capsule_y 초기화 (예: 0)
    li   $t0, 0
    la   $t1, prev_capsule_y
    sw   $t0, 0($t1)
    
    # newCapsuleFlag 초기화 (0: 새 캡슐 없음)
    li   $t0, 0
    la   $t1, newCapsuleFlag
    sw   $t0, 0($t1)
    
    # game_on 초기화 (1: 게임 진행)
    li   $t0, 1
    la   $t1, game_on
    sw   $t0, 0($t1)
    
    # capsule_orientation 초기화 (0: 가로)
    li   $t0, 0
    la   $t1, capsule_orientation
    sw   $t0, 0($t1)
    
    jr   $ra
