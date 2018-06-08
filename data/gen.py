import os
import random
import sys


path = 'data.txt'
if len(sys.argv) == 2:
    path = sys.argv[1]

with open(path,'w') as f:
    word = 'name,math,english,physical,c++,java,python\n'
    f.write(word)
    for j in range(30):
        length = random.randint(5,10)
        name = ''.join(random.sample(['z','y','x','w','v','u','t','s','r','q','p','o','n','m','l','k','j','i','h','g','f','e','d','c','b','a'], length))
        for i in range(6):
            grade = random.randint(1,2)
            grade = str(grade)
            name = name + ',' + grade
        name = name + '\n'   
        f.write(name)
