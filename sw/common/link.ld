/* ERV26 - linker script
 * Harvard: codigo en la memoria de programa, datos (incluido .rodata) en
 * la memoria de datos. Ambas comparten el espacio de direcciones.
 */
OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    IMEM (rx) : ORIGIN = 0x00000000, LENGTH = 16K
    DMEM (rw) : ORIGIN = 0x00010000, LENGTH = 16K
}

SECTIONS
{
    .text : {
        *(.text.init)
        *(.text .text.*)
    } > IMEM

    .rodata : {
        *(.rodata .rodata.* .srodata .srodata.*)
    } > DMEM

    .data : {
        *(.data .data.*)
        __global_pointer$ = . + 0x800;
        *(.sdata .sdata.*)
    } > DMEM

    .bss (NOLOAD) : {
        __bss_start = .;
        *(.sbss .sbss.* .bss .bss.* COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > DMEM

    _stack_top = ORIGIN(DMEM) + LENGTH(DMEM);

    /DISCARD/ : { *(.comment) *(.riscv.attributes) *(.note*) *(.eh_frame*) }
}
