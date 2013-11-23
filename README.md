computersystemenproject
=======================

Project voor Computersystemen: Snake maken met Assembly 8086

#Huidige plan
- We hebben een array van 64O elementen (32*20), een voor elk blokje (dat 10px lang en breed is)
    - Mogelijke waarden voor een element:
        - 0: er zit niks in
        - 1: er zit een deel van de slang in
        - 2: er zit een 'snoepje' in
- De head en tail van de slang moet bijgehouden worden
- Als de snake in een andere richting gaat, moet deze plaats(index in array) bijgehouden worden, zodat elk element van de snake ook in de juiste richting kan bewegen vanaf die plaats
    - Dit kunnen meerdere plaatsen zijn

#Handige links
##Ivm Assembly zelf
- [Intro to ASM](http://www.shsu.edu/~csc_tjm/spring2005/cs272/intro_to_asm.html)
- [8086 Instruction set](http://www.electronics.dit.ie/staff/tscarff/8086_instruction_set/8086_instruction_set.html)
- [Intel CPU 8086/8088 Instruction List](http://ftp.utcluj.ro/pub/users/nedevschi/CA/I8086/8086InstrSet/rtlcode86.pdf)
- [Intel Pentium Instruction Set Reference](http://faydoc.tripod.com/cpu/)
- [STOS/STOSB/STOSW/STOSD--Store String](http://www.jaist.ac.jp/iscenter-new/mpc/altix/altixdata/opt/intel/vtune/doc/users_guide/mergedProjects/analyzer_ec/mergedProjects/reference_olh/mergedProjects/instructions/instruct32_hh/vc304.htm)

##Assembly Projecten van anderen
- [Snake](http://he.scribd.com/doc/114620920/Snake-Code-for-EMU8086?secret_password=10ila7iztx3wd3h77q1v)
- [Ander snake project](https://github.com/AhmadAbdelNaser/emu8086/blob/master/examples/snake.asm)
- [Nog ander snake project](http://snipt.org/vxfd8)
- [Space Invaders](https://github.com/angryzor/space_invaders_8086)
- [Connect 4](https://github.com/mazenwagdy/connect-4/blob/master/code.asm)

##Andere
- [Sublime Text 2 Tutorial](https://tutsplus.com/course/improve-workflow-in-sublime-text-2/)
- [Markdown tutorial](http://daringfireball.net/projects/markdown/basics): Voor het opstellen van dit Readme document
- [Git tutorial](https://www.atlassian.com/git/tutorial/git-basics): Tutorial zonder al te veel zever
- [Githug](https://github.com/Gazler/githug): Practical way of learning Github