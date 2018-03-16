edit:order.o main.o
	nvcc -o edit order.o main.o

order.o:order.cu order.h
	nvcc -c order.cu

main.o:main.cu order.h
	nvcc -c main.cu