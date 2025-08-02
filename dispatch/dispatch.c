#include <stdio.h>
#include <dispatch/dispatch.h>


void jl_dispatch_read(dispatch_fd_t fd,
                      size_t length,
                      dispatch_queue_t queue,
                      void(*handler)(dispatch_data_t data, int error))
{
    dispatch_read(fd, length, queue, ^(dispatch_data_t d, int e) {
        handler(d, e);
    });
}


void jl_dispatch_write(dispatch_fd_t fd,
                       dispatch_data_t data,
                       dispatch_queue_t queue,
                       void(*handler)(dispatch_data_t data, int error))
{
    dispatch_write(fd, data, queue, ^(dispatch_data_t d, int e) {
        handler(d, e);
    });
}

/*

int main() {

    dispatch_queue_t queue =
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    int intbuffer[] = { 1, 2, 3, 4 };
    dispatch_data_t data = 
        dispatch_data_create(intbuffer, 4 * sizeof(int), queue, NULL);

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    // Write
    dispatch_fd_t fd = open("/tmp/data.dat", O_RDWR | O_CREAT | O_TRUNC,
                                             S_IRWXU | S_IRWXG | S_IRWXO);

    printf("FD: %d\n", fd);

    dispatch_write(fd, data, queue,^(dispatch_data_t d, int e) {
        printf("Written %zu bytes!\n",
               dispatch_data_get_size(data) 
             - (d ? dispatch_data_get_size(d) : 0));
        printf("\tError: %d\n", e);
        dispatch_semaphore_signal(sem);
    });

    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

    close(fd);

    // Read
    fd = open("/tmp/data.dat", O_RDWR);

    dispatch_read(fd, 4 * sizeof(int), queue, ^(dispatch_data_t d, int e) {
        printf("Read %zu bytes!\n", dispatch_data_get_size(d));
        printf("\tError: %d\n", e);

        const void *contig_buf;
        size_t contig_size;
        dispatch_data_t tmp = dispatch_data_create_map(d, &contig_buf,
                &contig_size);
        for (int i = 0 ; i < contig_size ; i ++)
        {
            printf("%4d: %02X\n", i, ((char*)contig_buf)[i]);
        }
        dispatch_release(tmp);
        
        dispatch_semaphore_signal(sem);
    });

    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    close(fd);


    return 0;
}

*/
