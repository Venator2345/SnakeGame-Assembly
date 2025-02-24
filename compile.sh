nasm -f elf code.asm
ld -m elf_i386 -o game code.o
echo arquivos gerados
