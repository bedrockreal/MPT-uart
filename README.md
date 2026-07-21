# MPT-uart - Mario Prints Text to UART

At 133 lines of PowerPC assembly, this minimal program enables debug printing from Gamecube and Wii games through OSReport, and it is capable of formatting %s, %c, %d, %u and %x.
I wrote this program with the PAL version of Mario Power Tennis in mind: whilst debug strings were found in the game files, the implementation to OSreport had been stripped by developers.

The implementation of `OSReport` is found in `printf.s`, whilst `main.s` is used purely for testing.

Use `make` to build a standalone DOL program. To compile `printf.s` only for use as a Gecko code, use `powerpc-eabi-as` from DevKitPPC.
