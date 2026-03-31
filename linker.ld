ENTRY(_start)

SECTIONS
{
  . = 0x80000;

  .text : ALIGN(16)
  {
    KEEP(*(.text._start))
    *(.text*)
    *(.rodata*)
  }

  .data : ALIGN(16)
  {
    *(.data*)
  }

  .bss (NOLOAD) : ALIGN(16)
  {
    __bss_start = .;
    *(.bss*)
    *(COMMON)
    . = ALIGN(16);
    __bss_end = .;
  }

  .boot_stack (NOLOAD) : ALIGN(16)
  {
    __boot_stack_bottom = .;
    . += 0x10000;
    __boot_stack_top = .;
  }

  /DISCARD/ :
  {
    *(.comment*)
    *(.eh_frame*)
    *(.note*)
  }
}

