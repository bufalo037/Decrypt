extern puts
extern printf
extern strlen
extern strstr

section .data
filename: db "./input.dat",0
inputlen: dd 2263
fmtstr: db "Key: %d",0xa,0

dim equ 28 ;dimensiunea alfabetului ( task 6 )
dim_char_cuv equ 26 ;numarul caracterelor care se pot regasi intr-un cuv
;fara caractere speciale

;am facutt aceste constatnte pt ca ele se fac oricum in etapa de preprocesare
;si asa ii dau o noanta mai generala temei
;bineinteles daca se modifica alfabetul codul nu va merge dar macar se va putea
;refolosi o parte din el

section .text
global main

; TODO: define functions and helper functions


search_ch: ;primeste parametrii un string si un caracter,
; intoarce adresa primului caracter cautat in string

    push ebp
    mov ebp, esp
    push edi
    push ecx
    mov ecx, [inputlen]
    cld ;pt siguranta
    mov edi, [ebp + 8]
    mov al, [ebp + 12]
    repne scasb ; parcurge pana gaseste byte-ul dorit si intoarce adresa urmatoare
    dec edi ;ca sa ajunga la byte-ul dorit
    ;fac ast doar pt frumusete (sa arate a strchr)
    ;diferente sunt ca daca nu gaseste byte-ul nu se opreste pana
    ;cand ecx nu e 0
    mov eax, edi
    pop ecx
    pop edi
    leave 
    ret
    
xor_strings: ;primeste paramtrii 2 stringuri, al doilea fiind key-ul
    push ebp
    mov ebp, esp
    push esi
    push edi
    push ecx
    mov edi, [ebp + 8]
    mov esi, [ebp + 12]
    
    mov cl, [edi]
    cmp cl, [esi]
    jz exit_xor
xor_loop: ;xoring begins
    xor cl, [esi]
    mov [edi], cl
    inc edi
    inc esi
    mov cl, [edi]
    cmp cl, [esi]
    jnz xor_loop   
exit_xor: ;xoring ends
    pop ecx
    pop edi
    pop esi
    leave
    xor eax, eax
    ret
    
    
rolling_xor:
    push ebp
    mov ebp, esp
    push ecx ;pt ca va fi folosit in procedura
    push edx ;va fi folosit in procedura
    mov edx, [ebp + 8] ; pt a accesa mai rpd memoria
    push 0
    push edx
    call search_ch
    add esp, 8
    
    mov ecx, eax
    dec ecx ; am in ecx adresa ultimui element din string
    
    cmp ecx, edx
    jz exit_roll
roll_loop:
    mov al, [ecx]   
    dec ecx
    xor al, [ecx]
    mov [ecx + 1], al
    cmp ecx, edx
    jnz roll_loop
exit_roll:
    pop edx
    pop ecx
    xor eax, eax
    leave
    ret
    
char_decode:
    push ebp
    mov ebp, esp
    
    mov al, [ebp + 8]
    cmp al, 0x39
    jg decode_aux
    sub al, 0x30
    leave
    ret
decode_aux:
    sub al,0x57 ; ca sa fie 10+
    leave
    ret

        
decode: ;decodeaza stringul primit ca parametru hexa->zecimal
    push ebp
    mov ebp, esp
    cld ; pt siguranta
    push esi
    push edx
    xor ecx, ecx
    mov esi, [ebp + 8]
    mov edx, esi
loop_decode:

    lodsw ; o sa fie pusi inversi pt ca x86 e Little Endian
    push eax
    call char_decode
    add esp, 4
    xchg al,ah ; pe langa ca trebuie sa fac asta pt pot folosi functia
    ; le si schimb valoarea registrilor ca sa fie in ordine si sa fie mai
    ; lizibil
    push eax
    call char_decode
    add esp,4
    shl ah, 4
    add ah, al
    
    mov byte [edx], ah ;edx este registrul care tine minte adresa byte-ului scris
    inc edx
       
    cmp byte [esi],0
    jnz loop_decode
    dec edx ; ca sa poata sa ii dea inc iar mai jos
exit_decode:
    inc edx
    mov byte [edx], 0x0 ;umplu cu 0 toate caracterele redundante
    cmp edx, esi
    jnz exit_decode; se opreste la finalul stringului
    pop edx
    pop ecx
    pop esi
    leave
    ret

xor_hex_strings:
    push ebp
    mov ebp, esp
    
    push dword [ebp +8] ;string
    call decode
    add esp, 4
    push dword [ebp +12] ;key
    call decode
    add esp, 4
    
    push dword [ebp +12] ;key
    push dword [ebp +8] ;string
    call xor_strings
    add esp, 8
    xor eax, eax
    leave
    ret

decode32char: ;decodifica un caracter dupa algoritmul base32, daca caracterul este
;egal il lasa nemodificat
    push ebp
    mov ebp, esp
    mov eax, [ebp + 8]
    cmp al, 0x41 ; 'A'
    jb decode32nr ; e ori numar ori =
    sub al, 0x41 ; 'A'
    jmp exit_decode32_char ; sa se inteleaga mai bine codul
decode32nr:
    cmp al, 0x3D ; '='
    jz exit_decode32_char
    sub al, 24 ;muta 2-ul in 26 si pe restul la fel; '2' = 50
exit_decode32_char:
    leave
    ret

base32decode_5oct: ;primeste ca parametru un pointer la care se va stoca ultimul
;byte din cei 5 decodificati, reustul de 4 sunt intorsi de functie prin eax
    push ebp
    mov ebp, esp
    push esi
    push ecx
    push edx
    push ebx
    xor ecx, ecx
    xor edx, edx
    mov esi, [ebp + 8]
    mov cl, 32 ; in ah o sa imi calculez numarul cu care o sa shiftez la stanga
base32loop:

    xor ebx, ebx ;important
    lodsb 
    push eax
    call decode32char
    mov bl, al ;mut rezultatul in bl
    pop eax
    cmp bl, 0x3D ; '0x3D'
    jz found_equal
    
    sub cl, 5 ; scad 5 ca sa oncatenez bitii
    cmp cl, 0
    jl last_byte
    
    shl ebx, cl
    add edx, ebx
    
    cmp ecx, 8
    jnz base32loop

last_byte:  
     xor ecx, ecx  
     mov ah, bl
     shr ah, 3
     mov cl, ah   ;ecx nu mai are nici o intrebuintare acum
     add edx, ecx ;am in momentu acesta primii 4 bytes in edx, mai trebuie sa
;fac rost de ultimul
     lodsb
     push eax
     call decode32char
     add esp, 4
     cmp al, 0x3D ; '='
     jz found_equal
     shl bl, 5 ;scap de primii 2 bytes din bl
     add bl, al
     
found_equal: ;indiferent dac a gasit sau nu egal pe aici se iese din proedura
    mov eax, edx
    mov ecx, [ebp + 12]
    mov [ecx], ebx
 
    pop ebx
    pop edx
    pop ecx
    pop esi
    leave
    ret
     
               
base32decode:
    push ebp
    mov ebp, esp
    push ecx
    push ebx
    push esi 
    mov esi, [ebp + 8]
    mov ecx, esi
    sub esp, 4
base32_main_loop:
    
    push esp
    push esi
    call base32decode_5oct
    add esp, 8
    mov ebx, [esp]
    ;incepe suprascrierea din nefericire fiind little endian trebuie sa pun
; byte-ii din eax in oridine inversa de la dreapta la stanga
    
    
    
    add ecx, 3
    ;not so preaty but i guess it works, better than one loop
    mov byte [ecx], al
    dec ecx
    shr eax, 8
    mov byte [ecx], al
    dec ecx
    shr eax, 8
    mov byte [ecx], al
    dec ecx
    shr eax, 8
    mov byte [ecx], al
    shr eax, 8
    ;the not so pretty part ends
    add ecx, 4

    mov byte [ecx], bl ; ultimul byte-ul era stocat in bl
    inc ecx
    add esi, 8
    cmp byte [esi],0
    jnz base32_main_loop
    
base32zeroing_the_surplus:
    mov byte [ecx], 0
    inc ecx
    cmp ecx, esi
    jnz base32zeroing_the_surplus
    add esp, 4
    pop esi
    pop ebx
    pop ecx
    leave
    ret

bruteforce_singlebyte_xor: ;in ebx tin cheia aux pana o gasesc, pt ca este mai rapid
    push ebp
    mov ebp, esp
    push ecx
    push ebx
    push edx
    push edi
    push esi
    mov esi, [ebp + 8] ;string
    ;mov edi, [ebp +12] ;key
    xor ebx, ebx

    push esi   
    call strlen
    add esp, 4
    
    mov ecx, eax
    mov edx, ecx
    
    inc eax
    sub esp, eax
    add esp, ecx ;eax-1
    mov byte [esp], 0
    sub esp, ecx
    
    push esp
    mov edi, [esp]
            
findkey:
    
    mov al, bl
    rep stosb
    mov edi, [esp] ;key
    push edi ;key
    push esi ;string
    call xor_strings
    add esp, 8
    
    xor ecx, ecx
    sub esp, 6
    ;pun la adresa pointata de esp force
    mov cl, 'r'
    mov ch, 'c'
    shl ecx, 16
    mov cl, 'f'
    mov ch, 'o'
    ;as fi putut sa o precalculez dar asa pare mai inteligibil (cred)
    ;4 cicluri suplimentare de procesor nu cred ca vor face o diferenta asa mare
    ;at worst 1020 cicluri suplimentare
    mov dword [esp], ecx
    add esp, 4
    mov byte [esp], 'e'
    inc esp
    mov byte [esp], 0
    sub esp, 5
    ;am pus force pe striva
    
    
    mov eax, esp ;"force"
    push edx
    push eax
    push esi ;string
    call strstr
    add esp, 8
    pop edx 
    add esp, 6
    
    mov ecx, edx ;pun in ecx valoare lui strlen
    cmp eax, 0
    jnz foundkey
    push edi
    push esi
    call xor_strings
    add esp, 8
    inc bl ;cresc cheia

    jmp findkey
    
foundkey:
    mov eax, [ebp +12]
    mov [eax], ebx
    mov esp, ebp
    sub esp, 20
    pop esi
    pop edi
    pop edx
    pop ebx
    pop ecx

    leave
    ret
    
;==================================================================================    
initialize_table:
    push ebp
    mov ebp, esp
    push edi
    mov al, 'a'
    mov edi, [ebp + 8]
loop_init_table:
    mov byte [edi], al
    add edi, 2
    inc al
    cmp al, 'z'
    jle loop_init_table
    mov byte [edi], ' '
    add edi, 2
    mov byte [edi], '.'
    
    pop edi
    leave
    ret
get_char_at_index:
    push ebp
    mov ebp, esp   
    push ecx
    push edx
    mov eax, [ebp +8]
    cmp eax, dim_char_cuv
    jge dot_or_space
    add eax, 'a'
    pop edx
    pop ecx
    leave
    ret
dot_or_space:
    mov cx, ' '
    mov dx, '.'
    cmove ax, cx
    cmovne ax, dx
    pop edx
    pop ecx
    leave
    ret
    
get_index_at_char:
    push ebp
    mov ebp, esp
    
    push ecx
    push edx
    xor eax, eax
    mov al, [ebp +8]
    cmp al, 'a'
    jl special
    sub al, 'a'
    pop edx
    pop ecx
    leave
    ret
special:
    mov cx, 26
    mov dx, 27
    cmp al, ' '
    cmovz ax, cx
    cmovnz ax, dx
    pop edx
    pop ecx
    leave
    ret

substitution:
    push ebp
    mov ebp, esp
    push edi
    push esi
    ;mov esi, [ebp +12] ;tabela de subt
    mov edi, [ebp +8] ;string
    
loopsubst:
    mov esi, [ebp +12] ;tabela de subt
    mov ah, [edi] ; pun caracterul de la adresa lui edi in ah
    inc esi
search_table:
    lodsb
    inc esi
    cmp al, ah
    jnz search_table
    sub esi, 3 ;daca l-a gasit el se gaseste cu 3 pozitii in stanga lui esi
    mov al, [esi]
    mov byte [edi],al
    inc edi
    mov al, [edi]
    cmp al, 0
    jnz loopsubst
    
    pop esi
    pop edi
    leave
    ret


finish_table:
    push ebp
    mov ebp,esp
    push edi
    push esi
    push ecx
    push ebx
    push edx
    
    
    ;mov edx, [ebp + 8]  ;tabela de subtitutie
    ;mov esi, [ebp +12]  ;vector freq 
    mov edi, [ebp + 16]  ;vectoul de substitutie
    
    push dword 0 ;folosesc stiva sa retin o variabila
refind_max:

    xor edx, edx
    xor ecx, ecx
    mov bx, -1
    mov esi, [ebp + 12] ;vector freq
find_max:
    cmp ecx, dim
    jz foundmax
    inc ecx
    lodsw
    cmp bx, ax
    jge find_max
    mov bx, ax
    mov dx, cx
    dec dx
    jmp find_max
    
foundmax:
    ;dec edx ;scad 1 ca am crescut 1 in plus in forul trecut
    mov esi, [ebp + 12] ;vector freq
    add esi, edx
    add esi, edx
    mov word [esi], -1 ;fac valoarea maxima din vectorul de freq -1
    xor eax, eax
    mov al, [edi]
    push eax
    call get_index_at_char
    add esp,4
    add eax, eax ;adaug ca sa fie dimensiune dubla
    add eax, [ebp + 8] ;tabela de substitutie + offset
    inc eax
    xchg eax, edx
    
    push eax
    call get_char_at_index
    add esp, 4
    mov byte [edx], al 
   
    inc edi ;nu il incrementasem dupa ce l-am folosit putin mai sus
    
    pop edx
    inc edx
    push edx
    cmp edx, dim
    jnz refind_max
    add esp,4
    
    pop edx
    pop ebx 
    pop ecx
    pop esi
    pop edi
    leave
    ret
    
complete_table: ;completeaza tabela de substitutie in funtie de frecventa
    push ebp
    mov ebp, esp
    push ecx
    push edx
    push ebx
    push edi
    push esi
    xor eax, eax
    sub esp, dim*2 ;un vector de frecvente (poz 0 e 'a' ... poz 26 e ' ' poz 27 e '.')
    push esp
    mov ecx, dim*2
    ;initiam cei 28 de bytes cu 0
    mov edi, [esp] ;inceputul vectorului de freq
    rep stosb
    ;initializarae a luat sfarsit
    mov esi, [ebp + 8] ;sirul de caractere codificat
    mov edi, [esp] ;inceput vectorului de freq
    
    
umplere_V_freq:
    lodsb
    cmp al, 'a'
    jl special_char
    sub al, 'a' ; transform litera in indicele sau
    add edi, eax
    add edi, eax ;de 2 ori ca am un vector care tine minte frecventa pe 2 bytes
    inc word [edi]
    sub edi, eax
    sub edi, eax
    mov ecx, [esi]
    cmp ecx, 0
    jnz umplere_V_freq
    jmp create_subt_v
    
special_char:
    cmp al, ' '
    jne is_point
    add edi, dim*2-4 ;dublu
    inc word [edi]
    sub edi, dim*2-4
    mov ecx, [esi]
    cmp ecx, 0
    jnz umplere_V_freq
    jmp create_subt_v 
    
is_point:
    add edi, dim*2-2 ;dublu
    inc word [edi]
    sub edi, dim*2-2
    mov ecx, [esi]
    cmp ecx, 0
    jnz umplere_V_freq

 
create_subt_v: 
    ;' 'etaoinshrdlucmfwypvbgkjqxz'.' (1)

 
    xor ecx, ecx 
    sub esp, dim
    push esp
    mov esi, [esp] ;ne-am pierdut interesul in vechiul esi
    ;copy paste ordine frecventa in engleza (1)
    ;din nefericire nu exista o cale sa o fac programatic
    mov byte [esi], ' '
    inc esi
    mov byte [esi], 'e'
    inc esi
    mov byte [esi], 't'
    inc esi
    mov byte [esi], 'a'
    inc esi
    mov byte [esi], 'o'
    inc esi
    mov byte [esi], 'i'
    inc esi
    mov byte [esi], 'n'
    inc esi
    mov byte [esi], 's' ;s
    inc esi
    mov byte [esi], 'h'
    inc esi
    mov byte [esi], 'r'
    inc esi
    mov byte [esi], 'd'
    inc esi
    mov byte [esi], 'l'
    inc esi
    mov byte [esi], 'u'
    inc esi
    mov byte [esi], 'c'
    inc esi
    mov byte [esi], 'm'
    inc esi
    mov byte [esi], 'f'
    inc esi
    mov byte [esi], 'w'
    inc esi
    mov byte [esi], 'y' ;y
    inc esi
    mov byte [esi], 'p'
    inc esi
    mov byte [esi], 'v'
    inc esi
    mov byte [esi], 'b'
    inc esi
    mov byte [esi], 'g'
    inc esi
    mov byte [esi], 'k'
    inc esi
    mov byte [esi], 'j'
    inc esi
    mov byte [esi], 'q'
    inc esi
    mov byte [esi], 'x'
    inc esi
    mov byte [esi], 'z'
    inc esi
    mov byte [esi], '.'
    
    mov esi, [esp]
    
    push esi ;vector de substitutie
    push edi ;vector de frecventa
    push dword [ebp +12] ;tabela de substitutie
    call finish_table
    add esp,12 
        
    mov esp, ebp
    sub esp, 20
    pop esi
    pop edi
    pop ebx
    pop edx
    pop ecx
    leave
    ret
    
manareala: ;cum ii spune si numele, dupa ce am incarcat frecventa default in tabel
;manaresc restul
    push ebp
    mov ebp, esp
    push edi
    
;ce e scris in dreapta sunt valorile de dinante de a face nimic
;gen larandul unul e randul unde se scrie 'a' la final si se
;si e scris din 0x71, care nu a fost modificat   
    
    mov edi, [ebp + 8]
    inc edi
    ;mov byte [edi]      ;a  ;0x71
    add edi, 2
    mov byte [edi],0x72    ;b  0x74
    add edi, 2
    ;mov byte [edi]      ;c 0x77
    add edi, 2
    mov byte [edi],0x65      ;d 0x79
    add edi, 2
    ;mov byte [edi]      ;e 0x20
    add edi, 2
    mov byte [edi],0x75     ;f 0x6d
    add edi, 2
    mov byte [edi],0x74     ;g 0x6a
    add edi, 2
    mov byte [edi],0x79     ;h 0x73
    add edi, 2
    mov byte [edi],0x69     ;i 0x67
    add edi, 2
    mov byte [edi],0x6f     ;j 0x72
    add edi, 2
    ;mov byte [edi]     ;k 0x70
    add edi, 2
    mov byte [edi],0x66    ;l 0x68
    add edi, 2
    mov byte [edi],0x68     ;m 0x6e
    add edi, 2
    mov byte [edi],0x2e     ;n 0x6c
    add edi, 2
    mov byte [edi],0x67    ;o 0x2e
    add edi, 2
    ;mov byte [edi]     ;p 0x64
    add edi, 2
    mov byte [edi],0x61  ;q 0x6f
    add edi, 2
    mov byte [edi],0x73     ;r 0x65
    add edi, 2
    mov byte [edi],0x6c    ;s 0x69
    add edi, 2
    ;mov byte [edi]     ;t 0x6b
    add edi, 2
    mov byte [edi],0x6d   ;u 0x66
    add edi, 2
    mov byte [edi],0x6a     ;v 0x7a
    add edi, 2
    mov byte [edi],  0x6e   ;w 0x78
    add edi, 2
    ;mov byte [edi]     ;x 0x62
    add edi, 2
    mov byte [edi],0x7a     ;y 0x75
    add edi, 2
    ;mov byte [edi]     ;z 0x76
    add edi, 2
    ;mov byte [edi]     ;' ' 0x63
    add edi, 2
    mov byte [edi],0x78     ;'.' 0x61
    
    pop edi
    leave
    ret
break_substitution:
    push ebp
    mov ebp, esp
    push ecx
    push ebx
    push esi
    push edi
    
    mov edi, [ebp + 8] ;string
    mov esi, [ebp + 12] ;subtitution table
    push esi
    call initialize_table
    add esp, 4
    push esi ;substitution table
    push edi ;string
    call complete_table
    add esp, 8
    
    push esi
    call manareala    
    add esp, 4
    
    push esi ;substitution table
    push edi ;string
    call substitution
    add esp, 8 
    
    pop edi
    pop esi
    pop ebx
    pop ecx
    leave
    ret
    
;==================================================================================
main:
    mov ebp, esp; for correct debugging
    push ebp
    mov ebp, esp
    sub esp, 2300
    
    ; fd = open("./input.dat", O_RDONLY);
    mov eax, 5
    mov ebx, filename
    xor ecx, ecx
    xor edx, edx
    int 0x80
        ; read(fd, ebp-2300, inputlen);
    mov ebx, eax
	mov eax, 3
	lea ecx, [ebp-2300]
	mov edx, [inputlen]
	int 0x80

	; close(fd);
	mov eax, 6
	int 0x80

;============================================================================

	; all input.dat contents are now in ecx (address on stack)

	; TASK 1: Simple XOR between two byte streams
	; TODO: compute addresses on stack for str1 and str2
	; TODO: XOR them byte by byte
    	;push addr_str2
	;push addr_str1
	;call xor_strings
	;add esp, 8

   push 0
   push ecx
   call search_ch
   add esp, 8
   inc eax ; pt ca in eax se gaseste primul byte de 0
   push eax ;(1)
   push ecx
   call xor_strings
   add esp,4

	; Print the first resulting string
	;push addr_str1
	;call puts
	;add esp, 4
    
    push ecx
    call puts
    add esp, 4
    pop ecx ;inca era pe stiva (1)
    
    push 0
    push ecx
    call search_ch
    add esp, 8
    
    inc eax
    mov ecx, eax
    
    
;============================================================================
	; TASK 2: Rolling XOR
	; TODO: compute address on stack for str3
	; TODO: implement and apply rolling_xor function
	;push addr_str3
	;call rolling_xor
	;add esp, 4

    push ecx
    call rolling_xor
    ;add esp,4
	; Print the second resulting string
	;push addr_str3
	;call puts
	;add esp, 4
    
   ; push ecx ;nu are rost sa dau pop pt ca e aceasi valoare
    ;e oare good practise sa dau totusi pop?
    call puts
    
    pop ecx
    push 0
    push ecx
    call search_ch ; as fi putut din functia de roll sa obtin adresa noului
    ;sir si sa o returnez dar mi se pare ai estetic asa
    inc eax
    mov ecx, eax
    add esp,4
    push eax
    call search_ch ; 0 era deja pe stiva
    add esp,8
    inc eax
    
	
	; TASK 3: XORing strings represented as hex strings
	; TODO: compute addresses on stack for strings 4 and 5
	; TODO: implement and apply xor_hex_strings
    
    
    
    push eax ; salvez pe stiva adresa cheii
    
    push 0
    push eax
    call search_ch ; o fac inante de xor_hex_strings ca o sa imi modifice memoria
;cu bytes de 0
    add esp, 8
    inc eax
    mov ebx, eax ;salvez inceputulul stringului pt taskul 4 
       
    push ecx
    call xor_hex_strings
    pop ecx
    pop eax
    push ecx
    call puts
    add esp,4
;==================================================================================  
	;push addr_str5
	;push addr_str4
	;call xor_hex_strings
	;add esp, 8

	; Print the third string
	;push addr_str4
	;call puts
	;add esp, 4
	
	; TASK 4: decoding a base32-encoded string
	; TODO: compute address on stack for string 6
	; TODO: implement and apply base32decode
	;push addr_str6
	;call base32decode
	;add esp, 4


    ;caut mai intai care este urmatorul string pt ca o sa fie paduit cu 0
    ;dupa ce va fi apelata functia base32decode
    push 0
    push ebx
    call search_ch
    pop ebx
    add esp, 4
    inc eax
    push eax
    push ebx
    call base32decode
    call puts
    


	; Print the fourth string
	;push addr_str6
	;call puts
	;add esp, 4

    	; TASK 5: Find the single-byte key used in a XOR encoding
	; TODO: determine address on stack for string 7
	; TODO: implement and apply bruteforce_singlebyte_xor
	;push key_addr
	;push addr_str7
	;call bruteforce_singlebyte_xor
	;add esp, 8
    
    add esp, 4
    mov ecx, [esp]
    add esp, 4 
    sub esp, 4 ; am rezervat 4 bytes oe stiva 
    push esp
    push ecx
    call bruteforce_singlebyte_xor
    call puts ;refolosesc ecx
    pop ecx
    pop ebx ;e adresa key-ii
    
    push ecx
    push dword [ebx]
    push fmtstr
    call printf
    add esp, 8
    pop ecx
    ; las in memorie key-ul ca sa se observe ca este acolo
    
    push 0
    push ecx
    call search_ch
    add esp, 8
    inc eax
    mov ecx, eax
    
    
 

	; Print the fifth string and the found key value
	;push addr_str7
	;call puts
	;add esp, 4

	;push keyvalue
	;push fmtstr
	;call printf
	;add esp, 8

	; TASK 6: Break substitution cipher
	; TODO: determine address on stack for string 8
	; TODO: implement break_substitution
	;push substitution_table_addr
	;push addr_str8
	;call break_substitution
	;add esp, 8

    sub esp, dim*2+1 ;posibil 56 (vezi debugging)
    push esp
    mov byte [esp +dim*2],0
    push ecx
    call break_substitution
    call puts
    add esp, 4
	; Print final solution (after some trial and error)
	;push addr_str8
	;call puts
	;add esp, 4
    call puts
    add esp, 4
	; Print substitution table
	;push substitution_table_addr
	;call puts
	;add esp, 4

    ; Phew, finally done
    
    xor eax, eax
    leave
    ret
