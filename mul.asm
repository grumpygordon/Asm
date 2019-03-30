ke                section         .text

                global          _start

; reads 2 numbers up to 2 ** (64 * (block_len - 1)) and multiplies them

_start:

				;mov				rsp, buf
                mov             rcx, 2 * block_len
                ;sub             rsp, 4 * block_len * 8

                lea             rdi, [buf + rcx * 8]
                call            set_zero
                mov             r9, rdi
                ; clear answer
                
                mov             rcx, block_len
                mov             rdi, buf
                call            read_long
                ; read first
                lea             rdi, [buf + rcx * 8]
                call            read_long
                mov             rsi, rdi
                ; read second
                mov             rdi, buf
                call            mul_long_long

                mov             rcx, 2 * block_len
                mov             rdi, r9
                call            write_long

                mov             al, 0x0a
                call            write_char

                jmp             exit

; muls two long number
;    rdi -- address of multiply #1 (long number)
;    rsi -- address of multiply #2 (long number)
;    rcx + 1 -- length of long numbers in qwords
;    there should be one leading zero qword in both rdi and rsi
; result:
;    mul is written to r9 of length 2 * rcx qwords

; for (r11 : len(rdi))
;   r10 = 0 # r10 - carry 
;   for (r12 : len(rsi)) # r13 = ans[r11 + r12]
;     (r10, r13) = r10 + r13 + rdi[r11] * rsi[r12]

mul_long_long:
                push            rdi
                push            rsi
                push            rcx
                xor             r11, r11
; for (r11 : len(rdi))
.loop1:
                xor             r10, r10
                xor             r12, r12
                mov             rbp, rcx
				lea				r13, [r9 + r11]
                clc
;   r10 = 0 # r10 - carry
;   for (r12 : len(rsi))
.loop2:
                mov             rbx, [rdi + r11] ; rdi[r11]
                mov             rax, [rsi + r12] ; rsi[r12]
                mul             rbx ; rdi[r11] * rsi[r12]
				add				rax, r10
				adc				rdx, 0				
                add             [r13], rax ; final sum
                adc             rdx, 0 ; rdx = carry of mul -> carry of mul and add
                mov             r10, rdx

                lea             r12, [r12 + 8]
                lea             r13, [r13 + 8]
                dec             rbp
                jnz             .loop2

                lea             r11, [r11 + 8]
                dec             rcx
                jnz             .loop1

                pop             rcx
                pop             rsi
                pop             rdi
                ret

; adds 64-bit number to long number
;    rdi -- address of summand #1 (long number)
;    rax -- summand #2 (64-bit unsigned)
;    rcx -- length of long number in qwords
; result:
;    sum is written to rdi
add_long_short:
                push            rdi
                push            rcx
                push            rdx

                xor             rdx,rdx
.loop:
                add             [rdi], rax
                adc             rdx, 0
                mov             rax, rdx
                xor             rdx, rdx
                add             rdi, 8
                dec             rcx
                jnz             .loop

                pop             rdx
                pop             rcx
                pop             rdi
                ret

; multiplies long number by a short
;    rdi -- address of multiplier #1 (long number)
;    rbx -- multiplier #2 (64-bit unsigned)
;    rcx -- length of long number in qwords
; result:
;    product is written to rdi
mul_long_short:
                push            rax
                push            rdi
                push            rcx

                xor             rsi, rsi
.loop:
                mov             rax, [rdi]
                mul             rbx
                add             rax, rsi
                adc             rdx, 0
                mov             [rdi], rax
                add             rdi, 8
                mov             rsi, rdx
                dec             rcx
                jnz             .loop

                pop             rcx
                pop             rdi
                pop             rax
                ret

; divides long number by a short
;    rdi -- address of dividend (long number)
;    rbx -- divisor (64-bit unsigned)
;    rcx -- length of long number in qwords
; result:
;    quotient is written to rdi
;    rdx -- remainder
div_long_short:
                push            rdi
                push            rax
                push            rcx

                lea             rdi, [rdi + 8 * rcx - 8]
                xor             rdx, rdx

.loop:
                mov             rax, [rdi]
                div             rbx
                mov             [rdi], rax
                sub             rdi, 8
                dec             rcx
                jnz             .loop

                pop             rcx
                pop             rax
                pop             rdi
                ret

; assigns a zero to long number
;    rdi -- argument (long number)
;    rcx -- length of long number in qwords
set_zero:
                push            rax
                push            rdi
                push            rcx

                xor             rax, rax
                rep stosq

                pop             rcx
                pop             rdi
                pop             rax
                ret

; checks if a long number is a zero
;    rdi -- argument (long number)
;    rcx -- length of long number in qwords
; result:
;    ZF=1 if zero
is_zero:
                push            rax
                push            rdi
                push            rcx

                xor             rax, rax
                rep scasq

                pop             rcx
                pop             rdi
                pop             rax
                ret

; read long number from stdin
;    rdi -- location for output (long number)
;    rcx -- length of long number in qwords
read_long:
                push            rcx
                push            rdi

                call            set_zero
.loop:
                call            read_char
                or              rax, rax
                js              exit
                cmp             rax, 0x0a
                je              .done
                cmp             rax, '0'
                jb              .invalid_char
                cmp             rax, '9'
                ja              .invalid_char

                sub             rax, '0'
                mov             rbx, 10
                call            mul_long_short
                call            add_long_short
                jmp             .loop

.done:
                pop             rdi
                pop             rcx
                ret

.invalid_char:
                mov             rsi, invalid_char_msg
                mov             rdx, invalid_char_msg_size
                call            print_string
                call            write_char
                mov             al, 0x0a
                call            write_char

.skip_loop:
                call            read_char
                or              rax, rax
                js              exit
                cmp             rax, 0x0a
                je              exit
                jmp             .skip_loop

; write long number to stdout
;    rdi -- argument (long number)
;    rcx -- length of long number in qwords
write_long:
                push            rax
                push            rcx

                mov             rax, 20
                mul             rcx
                mov             rbp, rsp
                sub             rsp, rax

                mov             rsi, rbp

.loop:
                mov             rbx, 10
                call            div_long_short
                add             rdx, '0'
                dec             rsi
                mov             [rsi], dl
                call            is_zero
                jnz             .loop

                mov             rdx, rbp
                sub             rdx, rsi
                call            print_string

                mov             rsp, rbp
                pop             rcx
                pop             rax
                ret

; read one char from stdin
; result:
;    rax == -1 if error occurs
;    rax \in [0; 255] if OK
read_char:
                push            rcx
                push            rdi

                sub             rsp, 1
                xor             rax, rax
                xor             rdi, rdi
                mov             rsi, rsp
                mov             rdx, 1
                syscall

                cmp             rax, 1
                jne             .error
                xor             rax, rax
                mov             al, [rsp]
                add             rsp, 1

                pop             rdi
                pop             rcx
                ret
.error:
                mov             rax, -1
                add             rsp, 1
                pop             rdi
                pop             rcx
                ret

; write one char to stdout, errors are ignored
;    al -- char
write_char:
                sub             rsp, 1
                mov             [rsp], al

                mov             rax, 1
                mov             rdi, 1
                mov             rsi, rsp
                mov             rdx, 1
                syscall
                add             rsp, 1
                ret

exit:
                mov             rax, 60
                xor             rdi, rdi
                syscall

; print string to stdout
;    rsi -- string
;    rdx -- size
print_string:
                push            rax

                mov             rax, 1
                mov             rdi, 1
                syscall

                pop             rax
                ret

                section         .rodata
invalid_char_msg:
                db              "Invalid character: "
invalid_char_msg_size: equ             $ - invalid_char_msg

block_len       equ             256

                section         .bss

buf_size:       equ             8 * 4 * block_len
buf:            resb            buf_size
