.intel_syntax noprefix
.global _start
_start:
        mov rax, [rsp] # argc
        cmp rax, 2
        jl help
        mov rdi, [rsp+16] # argv[1]

        lea rsi, str_add
        call strcmp
        test al, al
        jz add_note

        lea rsi, str_done
        call strcmp
        test al, al
        jz done_note

        lea rsi, str_peek
        call strcmp
        test al, al
        jz note_peek

        jmp help

# non following call convention: put how much to read in register rdx
note_read:
        xor rax, rax
        lea rsi, [rsp+8]
        mov rdi, rbx
        syscall
        ret

note_peek:
        mov rsi, 0
        lea rdi, note_file
        mov rax, 2 # open
        syscall
        mov rbx, rax

        mov rdx, 4     # 4 bytes top
        call note_read

        cmp al, 4
        jnz exit_malformed_file

        add eax, dword ptr [rsp]
        mov rsi, rax

        call seek_from_start

        mov rdx, 4     # 4 bytes length
        call note_read

        mov r15d, dword ptr [rsp]
        sub rsp, r15

        mov rdx, r15
        call note_read

        mov byte ptr [rsp+r15-1], 0xa

        lea rsi, [rsp]
        mov rdx, r15
        mov rdi, 1
        mov rax, 1
        syscall

        add rsp, r15
        jmp exit_file_close
        

# set rsi to offset
seek_from_start:
        mov rax, 8
        mov rdi, rbx
        cqo
        syscall
        ret

add_note:

        cmp qword ptr [rsp], 3
        jl help_note_add

        mov rdx, 0600
        mov rsi, 66 # (O_RDWR = 2) | (O_CREAT = 64)
        lea rdi, note_file
        mov rax, 2 # open
        syscall
        mov rbx, rax

        sub rsp, 12 # ptrchunk read
        
        mov rdx, 12     # 4 bytes top, 4 bytes parent, 4 bytes length
        call note_read

        test al, al
        jz empty_note_init

        cmp al, 12
        jnz exit_malformed_file

        mov rax, 8 # lseek
        mov rdi, rbx
        xor rsi, rsi
        mov rdx, 2
        syscall

        # top becomes parent
        mov dword ptr [rsp+8], eax # end is stored temporarily

        mov rdi, [rsp+36]
        call strlen
        inc rax
        mov dword ptr [rsp+4], eax # length is overwritten

        # write the previous note's address
        # and current note's length
        mov rax, 1
        mov rdi, rbx
        lea rsi, [rsp]
        mov rdx, 8
        syscall

        cqo
        mov edx, dword ptr [rsp+4]
        mov rsi, [rsp+36]
        mov rdi, rbx
        mov rax, 1
        syscall

        xor rsi, rsi
        call seek_from_start

        mov rax, 1
        mov rdi, rbx
        lea rsi, [rsp+8]
        mov rdx, 4
        syscall

        jmp ptrchunk_deinit

        empty_note_init:
                mov rdi, [rsp + 36]
                call strlen
                inc rax

                mov qword ptr [rsp], 4
                mov dword ptr [rsp + 8], eax

                mov rax, 1
                mov rdi, rbx
                lea rsi, [rsp]
                mov rdx, 12
                syscall


                xor rdx, rdx
                mov edx, dword ptr [rsp+8]

                mov rsi, [rsp + 36]
                mov rdi, rbx
                mov rax, 1
                syscall

                jmp ptrchunk_deinit

exit_malformed_file:
        mov rax, 1
        mov rdi, 2
        lea rsi, [rip + str_malformed_file]
        mov rdx, offset strlen_malformed_file
        syscall

        jmp exit_file_close

done_note:

        mov rdx, 0600
        mov rsi, 66 # (O_RDWR = 2) | (O_CREAT = 64)
        lea rdi, note_file
        mov rax, 2 # open
        syscall
        mov rbx, rax

        sub rsp, 12 # ptrchunk read
        
        mov rdx, 12    # 4 bytes top, 4 bytes parent, 4 bytes length
        call note_read
        
        cmp al, 12
        jnz exit_malformed_file

        mov esi, dword ptr [rsp]
        call seek_from_start

        mov rdx, 4     # 4 bytes parent pointer
        call note_read

        xor rsi, rsi
        call seek_from_start

        mov rax, 1
        mov rdi, rbx
        lea rsi, [rsp]
        mov rdx, 4
        syscall

        jmp exit_file_close

# returns the length of the string _including the null terminator_
strlen:
        mov rax, -1
        strlen_loop:
                inc rax
                cmp byte ptr [rdi+rax], 0
                jnz strlen_loop
        ret

# Returns the lexicographic difference of the two strings.
# 0 if equal.
strcmp:
        push rcx
        push rbx
        xor rbx, rbx
        strcmp_loop:
                mov cl, byte ptr [rdi+rbx]
                test cl, cl
                jz strcmp_done
                mov ch, byte ptr [rsi+rbx]
                test ch, ch
                jz strcmp_done
                cmp cl, ch
                jnz strcmp_done
                inc rbx
        jz strcmp_loop

        strcmp_done:
                mov al, cl
                sub al, ch
                pop rbx
                pop rcx
                ret

help:
        mov rax, 1
        mov rdi, 1
        lea rsi, [rip + help_str]
        mov rdx, offset help_str_len
        syscall
        jmp exit_clean

help_note_add:
        mov rax, 1
        mov rdi, 1
        lea rsi, [rip + help_note_str_add]
        mov rdx, offset help_note_str_add_len
        syscall
        jmp exit_clean

ptrchunk_deinit:
        add rsp, 12 # ptrchunk read

exit_file_close:
        mov rax, 3 # close
        mov rdi, rbx
        syscall

exit_clean:
        mov rax, 0x3c
        mov rdi, 0x0
        syscall

.section .rodata
help_str:
        .ascii "usage: notestack [add | done | peek] ...\n"
        help_str_len = . - help_str

help_note_str_add:
        .ascii "usage: notestack add 'your next todo'\n"
        help_note_str_add_len = . - help_note_str_add
        
str_malformed_file:
        .ascii "error: malformed file: failed to read note stack file header\n"
        strlen_malformed_file = . - str_malformed_file

str_add:
        .asciz "add"

str_done:
        .asciz "done"

str_peek:
        .asciz "peek"

note_file:
        .asciz "note.bin"

