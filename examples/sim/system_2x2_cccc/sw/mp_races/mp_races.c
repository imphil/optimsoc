/* Copyright (c) 2013-2015 by the author(s)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * =============================================================================
 *
 * Race condition example involving message passing
 *
 * Case Study for the JSA Paper
 *
 * Author(s):
 *   Philipp Wagner <philipp.wagner@tum.de>
 */


#include <stdio.h> // For printf
#include <inttypes.h>

#include <optimsoc-mp.h>
#include <or1k-support.h>
#include <optimsoc-baremetal.h>

#include <assert.h>

typedef enum {
    BALANCE_INFO,
    CHANGE_BALANCE
} mp_message_type_t;

typedef struct {
    uint32_t valid;
    uint32_t src;
    mp_message_type_t type;
    size_t payload_len;
    uint32_t payload[1]; // XXX: in reality this would be dynamic
} mp_message_t;

// number of compute tiles
#define NUM_TILES 4
// message buffer per tile
#define MSG_BUF_SIZE 1

// message buffer (per tile)
mp_message_t msg_buf[NUM_TILES][MSG_BUF_SIZE];


/**
 * Lookahead: is a message available?
 *
 * @return 1 if a message is available to be read, 0 otherwise
 */
int mp_is_msg_available()
{
    int rank = optimsoc_get_ctrank();
    return msg_buf[rank][0].valid;
}

/**
 * Receive a message
 *
 * After processing it, "delete" it from the message queue by setting
 * msg.valid to 0.
 *
 * @param[out] msg received message
 * @return 0 on success
 */
int mp_rcv_msg(mp_message_t **msg)
{
    if (msg_buf[optimsoc_get_ctrank()][0].valid == 0) {
        printf("%s: no message available\n", __FUNCTION__);
        return 1;
    }

    *msg = &msg_buf[optimsoc_get_ctrank()][0];
    return 0;
}

/**
 * Callback from interrupt handler: A new message was received
 *
 * Only queue the incoming message in a per-tile queue, no further signaling
 * is done.
 *
 * @private
 */
void _mp_recv(unsigned int *buffer, int len)
{
    int source_tile, source_rank, dest_rank;

    source_tile = extract_bits(buffer[0], OPTIMSOC_SRC_MSB, OPTIMSOC_SRC_LSB);
    source_rank = optimsoc_get_tilerank(source_tile);

    // Print hello for this
    printf("msg received from %d with length %d!\n", source_rank, len);
    printf("type: %d, data: %d\n", buffer[1], buffer[2]);

    dest_rank = optimsoc_get_ctrank();

    // wait until we have a buffer space available
    // XXX: missing: multi-queue support
    while (msg_buf[dest_rank][0].valid == 1) {}

    msg_buf[dest_rank][0].valid = 1;
    msg_buf[dest_rank][0].src = source_rank;
    msg_buf[dest_rank][0].type = buffer[1];
    msg_buf[dest_rank][0].payload_len = 1;
    msg_buf[dest_rank][0].payload[0] = buffer[2];
}

/**
 * Send a message to tile with rank \p dest
 */
static void mp_send_msg(unsigned int dest, uint32_t type, uint32_t payload)
{
    // The message is a three flit packet
    uint32_t buffer[3] = { 0 };

    // Set destination (tile 0)
    set_bits(&buffer[0], dest, OPTIMSOC_DEST_MSB, OPTIMSOC_DEST_LSB);

    // Set class (0)
    set_bits(&buffer[0], 0, OPTIMSOC_CLASS_MSB, OPTIMSOC_CLASS_LSB);

    // Set sender as my rank
    set_bits(&buffer[0], optimsoc_get_ranktile(optimsoc_get_ctrank()),
             OPTIMSOC_SRC_MSB, OPTIMSOC_SRC_LSB);

    // data
    buffer[1] = type;
    buffer[2] = payload;

    // Send the message
    optimsoc_mp_simple_send(sizeof(buffer)/sizeof(uint32_t), buffer);
}

static void task_bank()
{
    int balance = 100;

    // broadcast balance to all ATMs
    mp_send_msg(1, BALANCE_INFO, balance);
    mp_send_msg(2, BALANCE_INFO, balance);

    while (1) {};
}

static void task_atm_1()
{
    mp_message_t* msg;
    int atm_balance;

    while (1) {
        if (mp_is_msg_available()) {
            printf("message available at atm1\n");
            int rv = mp_rcv_msg(&msg);
            if (rv != 0) {
                printf("ERROR receiving message\n");
                continue;
            }
            if (msg->type == BALANCE_INFO) {
                atm_balance = msg->payload[0];
                msg->valid = 0; // remove from queue
                printf("%s: set balance to %d\n", __FUNCTION__, atm_balance);
            }
        }
    }

    //mp_send_msg(0, CHANGE_BALANCE, -70);
}

static void task_atm_2()
{
    mp_send_msg(0, CHANGE_BALANCE, -70);
}

/**
 * Main function: program entry point
 *
 * Initialize system and spawn tasks on the individual cores
 */
void main()
{
    // only run on core 0 in each tile
    if (or1k_coreid() != 0)
        return;

    // Initialize optimsoc library
    optimsoc_init(0);
    optimsoc_mp_simple_init();

    // Add handler for received messages (of class 0)
    optimsoc_mp_simple_addhandler(0, &_mp_recv);
    or1k_interrupts_enable();

    // Determine tiles rank
    int rank = optimsoc_get_ctrank();

    if (rank == 0) {
        task_bank();
        printf("task_bank finished\n");
    }

    if (rank == 1) {
        task_atm_1();
        printf("task_atm_1 finished\n");
    }

    if (rank == 2) {
        task_atm_2();
        printf("task_atm_2 finished\n");
    }

    printf("all finished\n");
}
