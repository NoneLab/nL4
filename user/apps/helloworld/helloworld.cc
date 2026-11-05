#include "l4/schedule.h"
#include "l4io.h"

int main()
{
    printf("Hello L4 Dude");

    while(true)
        L4_Yield();

    return 0;
}