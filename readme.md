# RIsc V assembly barcode ean8 generator

### Summary

Barcode genration with ean8 set C standard (high density code for big numbers) implentation in risc v assembly.

### Usage

You have tu have java enviroment to run RARS vivrtual machine. Risc V is RISC architecture, but intel and AMD CPUs are x86-64 architecture (CISC). Type ub terminal

```
    java -jar rars.jar barcode128.asm
```

If stripe base witdh and text to code length (global variabbles) aren't to big success code 0 will be returned with generated image, otherwise erroc code 1;