option = --relocatable-device-code=true -G -g

all:edit

edit:bitadd.o group.o group_by.o
	nvcc $(option) -o bin/edit bitadd.o group.o group_by.o
	python data/gen.py data/data.txt

bitadd.o:src/add/bitadd.cu src/add/bitadd.h
	nvcc $(option) -c src/add/bitadd.cu

group.o:src/group.cu src/add/bitadd.h
	nvcc $(option) -c src/group.cu

group_by.o:src/group_by/group_by.cu src/group_by/group_by.h
	nvcc $(option) -c src/group_by/group_by.cu

clean:
	rm group.o bitadd.o bin/edit group_by.o data/data.txt