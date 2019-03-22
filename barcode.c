#include <stdio.h>
#include <string.h>
#include <dirent.h>
#include <fcntl.h>
#include <unistd.h>
#include <linux/input.h>
#include <stdlib.h>

#define VENDORID  0x0581
#define PRODUCTID 0x0103
#define SCN_BCD_SZ 15

int scan_fd = -1;

int initScanner(){
	int count;
	char path[32];
	struct dirent **files;
	struct input_id id;

	printf("Inicializa \n");

	count = scandir("/dev/input", &files, NULL, alphasort);
	printf("Archivos: %i \n", count);
	while( count>0 ){
		count--;
		if( scan_fd==-1 && strncmp(files[count]->d_name,"event",5)==0 ){
			sprintf(path,"/dev/input/%s",files[count]->d_name);
			printf("Trying %s\n", path);
			scan_fd = open(path,O_RDONLY);
			if( scan_fd>=0 ){
				printf("open succeeded\n");
				if( ioctl(scan_fd,EVIOCGID,(void *)&id)<0 ) perror("ioctl EVIOCGID");
				else{
					if( id.vendor==VENDORID && id.product==PRODUCTID )
						printf("scanner attached to %s\n",path);
					else{
						printf("not this one...\n");
						close(scan_fd);
						scan_fd = -1;
					}
				}
			}
			else{
				fprintf(stderr,"Error opening %s",path);
				perror("");
			}
		}
		free(files[count]);
	}
	free(files);

	if( scan_fd>=0 ) ioctl(scan_fd,EVIOCGRAB);
	else{ printf("scanner not found or couldn't be opened\n"); return 0;}
	return 1;
}


int closeScanner(){
	close(scan_fd);
	scan_fd = -1;
	return 1;
}


char keycodelist(int scancode){
	char ret = '-';
	//return (unsigned char)scancode;
	switch(scancode){
		case 0x02: ret ='1';break;
		case 0x03: ret ='2';break;
		case 0x04: ret ='3';break;
		case 0x05: ret ='4';break;
		case 0x06: ret ='5';break;
		case 0x07: ret ='6';break;
		case 0x08: ret ='7';break;
		case 0x09: ret ='8';break;
		case 0x0a: ret ='9';break;
		case 0x0b: ret ='0';break;
		case 0x0c: ret ='-';break;

		case 0x10: ret ='q';break;
		case 0x11: ret ='w';break;
		case 0x12: ret ='e';break;
		case 0x13: ret ='r';break;
		case 0x14: ret ='t';break;
		case 0x15: ret ='y';break;
		case 0x16: ret ='u';break;
		case 0x17: ret ='i';break;
		case 0x18: ret ='o';break;
		case 0x19: ret ='p';break;

		case 0x1e: ret ='a';break;
		case 0x1f: ret ='s';break;
		case 0x20: ret ='d';break;
		case 0x21: ret ='f';break;
		case 0x22: ret ='g';break;
		case 0x23: ret ='h';break;
		case 0x24: ret ='j';break;
		case 0x25: ret ='k';break;
		case 0x26: ret ='l';break;

		case 0x2c: ret ='z';break;
		case 0x2d: ret ='x';break;
		case 0x2e: ret ='c';break;
		case 0x2f: ret ='v';break;
		case 0x30: ret ='b';break;
		case 0x31: ret ='n';break;
		case 0x32: ret ='m';break;
		default: break;
	}
	return ret;
}


//read a barcode from the scanner.
//reads as long as *loopcond!=0 (if loopcond is NULL then read
//forever). If termination condition is met, returns NULL.
//read all characters from barcode untill we read 0x28 (carriage
//return).
char* readScanner(int *loopcond){
	static char barcode[SCN_BCD_SZ];
	char code[SCN_BCD_SZ];
	int i=0;
	struct input_event ev;

	while( loopcond==NULL?1:*loopcond ){
		read(scan_fd,&ev,sizeof(struct input_event));
		if( ev.type==1 && ev.value==1 ){
			if( ev.code==28 ){ //carriage return
				//printf("Carriage Return Read \n");
				code[i] = 0;
				strcpy(barcode,code);
				return barcode;
			}
			else{
				if( ev.code!=0 ){
					code[i++] = keycodelist(ev.code);
					//printf("Char: %i-%i \n", keycodelist(ev.code), ev.code);
					if( i==SCN_BCD_SZ-1 ){ printf("Barcode buffer full\n"); return NULL;}
				}
			}
		}
	}
	return NULL;
}

int main(){
	initScanner();
	printf("Escaner Ok \n");
	while(1){
		printf("%s \n", readScanner(NULL));
		printf("Sigiente Código... \n");
	}
}
