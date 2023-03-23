## MAGIC VIM


### **Vim in VSCode:**  
<kbd>Ctrl</kbd> + <kbd>H</kbd> : In normal mode: Vim Navigate to the **left** panel  
<kbd>Ctrl</kbd> + <kbd>L</kbd> : In normal mode: Vim Navigate to the **right** panel  
<kbd>Ctrl</kbd> + <kbd>J</kbd> : In normal mode: Vim Navigate to the **below** panel  
<kbd>Shift</kbd> + <kbd>V</kbd> + <kbd>J</kbd> : `Must press V and J at the same time`. Move blow line to be not break line anymore   

### Basic but fucking good:  
<kbd>:</kbd> + <kbd>reg</kbd> : Show yank registerd  
<kbd>"</kbd> + <kbd>yank name</kbd> + <kbd>p</kbd> : Paste specified yanked text.  
<kbd>g</kbd> + <kbd>e</kbd> : end of previous word  

#### Vim Shortcut  
<kbd>c</kbd> + <kbd>Number of Word</kbd> + <kbd>l</kbd> : Change a number of letter.  
<kbd>u</kbd> : Undo in Vim (Normal mode).  
<kbd>Ctrl</kbd> + <kbd>o</kbd> : Go to history cursor backward. 
<kbd>Ctrl</kbd> + <kbd>i</kbd> : Go to history cursor forward. 
<kbd>Shift</kbd> + <kbd>p</kbd> : Paste before cursor.


<kbd>Z + Z</kbd> : Exit document with saving  
<kbd>Z + Q</kbd> : Exit document without saving  
<kbd>g</kbd> + <kbd>f</kbd> : Go to file .  
<kbd>Shift</kbd> + <kbd>\`</kbd> : Switch uppercase -> lowercase..  
<kbd>Shift</kbd> + <kbd>u</kbd> : Switch selected to uppercase   
<kbd>u</kbd> : Switch selected to lowercase   
<kbd>Shift</kbd> + <kbd>a</kbd> : Go to end of line -> to Insert Mode  
<kbd>Shift</kbd> + <kbd>i</kbd> : Go to start of line -> to Insert Mode  

<kbd>Ctrl</kbd> + <kbd>]</kbd> or <kbd>g</kbd> + <kbd>d</kbd> : Go to usage or definition of a variable.  
<kbd>Shift</kbd> + <kbd>8</kbd> : Go to next occurrence of word  
<kbd>Shift</kbd> + <kbd>3</kbd> : Go to previous occurrence of word  
<kbd>Shift</kbd> + <kbd>9</kbd> : Go to empty space line upward  
<kbd>Shift</kbd> + <kbd>0</kbd> : Go to empty space line downward  


<kbd>v</kbd> + <kbd>i</kbd> + <kbd>\<tag\></kbd> : select in side a HTML tag  
<kbd>v</kbd> + <kbd>a</kbd> + <kbd>\<tag\></kbd> : select out side a HTML tag  
<kbd>d</kbd> + <kbd>i</kbd> + <kbd>w</kbd> : delete whole word even cursor is standing anywhere of word   
<kbd>d</kbd> + <kbd>i</kbd> + <kbd>p</kbd> : delete paragraph  
 
 <kbd>Ctrl</kbd> + <kbd>g</kbd> : Switch between VISUAL mode and SELECT mode  
 
 ### Magic form ThePrimeagen
 <kbd>=</kbd> : format or format selection
 <kbd>=</kbd> + <kbd>a</kbd> + <kbd>p</kbd> : format all line of the paragraph  
 <kbd>v</kbd> + <kbd>i</kbd> + <kbd>w</kbd> : to select a word no matter where ur cursor is  
 <kbd>f</kbd> + <kbd>a char</kbd>: search a char in current line  
 <kbd>F</kbd> + <kbd>a char</kbd>: backward search
 <kbd>v</kbd> + <kbd>t</kbd> + <kbd>a char</kbd> : select from current pos to closest char.   
 <kbd>%</kbd> : Go to match bracket
 
**after using f or F: using <kbd>,</kbd> or <kbd>;</kbd> to move around**

**When in selection press <kbd>o</kbd> or <kbd>O</kbd> to jump around selection**  
#### Command with vim
- Search and replace: 
`:%s/<search-text>/<replace-text>`

- In Visual Mode , select some line and type `:sort` to sort.  
- We can split by `:sp` or `:vs`
