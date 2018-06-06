import os
import random

with open('data.txt','w') as f:
    word = 'name,math,english,physical,c++,java,python\n'
    f.write(word)
    for j in range(13000):
        length = random.randint(5,10)
        name = ''.join(random.sample(['z','y','x','w','v','u','t','s','r','q','p','o','n','m','l','k','j','i','h','g','f','e','d','c','b','a'], length))
        for i in range(6):
            grade = random.randint(1,10000000)
            grade = str(grade)
            name = name + ',' + grade
        name = name + '\n'   
        f.write(name)
