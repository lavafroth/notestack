.intel_syntax noprefix
.global _start
_start:
        mov rax, [rsp] # argc
        cmp rax, 2
        jl help
        mov rdi, [rsp+16] # argv[1]

        lea rsi, add_str
        call strcmp
        test al, al
        jz add_note

        lea rsi, done_str
        call strcmp
        test al, al
        jz done_note

        lea rsi, peek_str
        call strcmp
        test al, al
        jz note_peek

        jmp exit_clean

note_peek:

        mov rsi, 0
        lea rdi, note_file
        mov rax, 2 # open
        syscall
        mov rbx, rax

        mov rax, 0     # read
        mov rdx, 4     # 4 bytes top
        mov rdi, rbx   # from the notes file
        lea rsi, [rsp] # onto the stack
        syscall

        xor rsi, rsi
        mov esi, dword ptr [rsp]
        add esi, 4

        mov rax, 8 # lseek
        mov rdi, rbx
        mov rdx, 0
        syscall

        mov rax, 0     # read
        mov rdx, 4     # 4 bytes length
        mov rdi, rbx   # from the notes file
        lea rsi, [rsp] # onto the stack
        syscall

        xor r15, r15
        mov r15d, dword ptr [rsp]
        sub rsp, r15

        
        mov rax, 0 # read the note
        mov rdx, r15   # of length
        mov rdi, rbx   # from the notes file
        lea rsi, [rsp] # onto the stack
        syscall

        mov byte ptr [rsp+r15-1], 0xa

        lea rsi, [rsp]
        mov rdx, r15
        mov rdi, 1
        mov rax, 1
        syscall

        add rsp, r15
        jmp close_and_exit
        


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
        
        mov rax, 0     # read
        mov rdx, 12     # 4 bytes top, 4 bytes parent, 4 bytes length
        mov rdi, rbx   # from the notes file
        lea rsi, [rsp] # onto the stack
        syscall

        test al, al
        jz empty_note_init

        cmp al, 12
        jnz close_and_exit # TODO: report malformed file

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

        xor rdx, rdx
        mov edx, dword ptr [rsp+4]
        mov rsi, [rsp+36]
        mov rdi, rbx
        mov rax, 1
        syscall

        mov rax, 8 # lseek
        mov rdi, rbx
        mov rsi, 0
        mov rdx, 0
        syscall

        mov rax, 1
        mov rdi, rbx
        lea rsi, [rsp+8]
        mov rdx, 4
        syscall


        jmp ptrchunk_deinit

        ptrchunk_deinit:
                add rsp, 12 # ptrchunk read

        close_and_exit:

                mov rax, 3 # close
                mov rdi, rbx
                syscall

                jmp exit_clean

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

done_note:


        mov rdx, 0600
        mov rsi, 66 # (O_RDWR = 2) | (O_CREAT = 64)
        lea rdi, note_file
        mov rax, 2 # open
        syscall
        mov rbx, rax

        sub rsp, 12 # ptrchunk read
        
        mov rax, 0     # read
        mov rdx, 12    # 4 bytes top, 4 bytes parent, 4 bytes length
        mov rdi, rbx   # from the notes file
        lea rsi, [rsp] # onto the stack
        syscall
        
        cmp al, 12
        jnz close_and_exit # TODO: report malformed file

        mov rax, 8
        mov rdi, rbx
        xor rsi, rsi
        mov esi, dword ptr [rsp]
        mov rdx, 0
        syscall

        mov rax, 0     # read
        mov rdx, 4     # 4 bytes parent pointer
        mov rdi, rbx
        lea rsi, [rsp]
        syscall
        
        mov rax, 8
        mov rdi, rbx
        xor rsi, rsi
        mov rdx, 0
        syscall

        mov rax, 1
        mov rdi, rbx
        lea rsi, [rsp]
        mov rdx, 4
        syscall

        jmp close_and_exit

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
        lea rsi, [rip + help_note_add_str]
        mov rdx, offset help_note_add_str_len
        syscall
        jmp exit_clean

exit_clean:
        mov rax, 0x3c
        mov rdi, 0x0
        syscall

.section .rodata
help_str:
        .ascii "usage: notestack [add | done | peek] ...\n"
        help_str_len = . - help_str

help_note_add_str:
        .ascii "usage: notestack add 'your next todo'\n"
        help_note_add_str_len = . - help_note_add_str
        

add_str:
        .asciz "add"

done_str:
        .asciz "done"

peek_str:
        .asciz "peek"

note_file:
        .asciz "note.bin"

