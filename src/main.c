#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <string.h>
#include <time.h>
#include <assert.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <termios.h>
#include <stdarg.h>
#include <sys/select.h>
#include <ctype.h>
#include <errno.h>
#include <getopt.h>
#include <signal.h>
#include "openDev.h"
#define MAX_PORTS 4

/*判断是否存在*/
int FileExist(const char *filename)
{
	if (filename && access(filename, F_OK) == 0)
	{
		return 1;
	}
	return 0;
}
int main(int argc, char **argv)
{
	if (argc < 3)
	{
		printf("ERROR demo: sendat /dev/ttyUSB1 'ATI'\n");
		exit(1);
		return 0;
	}
	int debug = 1;
	char *serial_dev = argv[1];
	if (access(serial_dev, F_OK) != 0)
	{
		printf("serial device does not exist.\n");
		return 0;
	}
	char *message = argv[2];
	char *nty = "\r\n";
	int fd = OpenDev(serial_dev);
	// 打开串口
	if (fd >= 0)
	{
		set_speed(fd, 19200);
		// 设置波特率
	}
	else
	{
		printf("Can't Open Serial Port!\n");
		exit(1);
	}
	// 设置校验位
	if (set_Parity(fd, 8, 1, 'N') == FALSE)
	{
		printf("Set Parity Error\n");
		exit(1);
	}
	ssize_t nread;

	serial_parse phandle;
	phandle.rxbuffsize = 0;
	int messageLen = strlen(message);
	int ntyLen = strlen(nty);
	char sendAT[messageLen + ntyLen + 1];
	strcpy(sendAT, message);
	strcat(sendAT, nty);

	// 写入数据，并检查返回值
	ssize_t wlen = write(fd, sendAT, strlen(sendAT));
	if (wlen < 0)
	{
		perror("write error");
		exit(1);
	}

	usleep(10000);

	// 读取数据，并检查返回值
	nread = read(fd, phandle.buff + phandle.rxbuffsize, MAX_BUFF_SIZE - phandle.rxbuffsize);
	if (nread < 0)
	{
		perror("read error");
		exit(1);
	}
	phandle.rxbuffsize += nread;
	phandle.buff[phandle.rxbuffsize] = '\0';
	printf("%s", phandle.buff);
	return 0;
}
