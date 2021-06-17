#ifndef PROJECT_HEADER
#define PROJECT_HEADER

#define CONTACT_SLOTS 20
#define COUNT_LIMIT 10
#define TIMER_LIMIT 500


typedef nx_struct mote_msg {
    nx_uint16_t senderId;
} mote_msg_t;

typedef struct contact {
	uint16_t id;
    uint32_t timeStamp;
    uint8_t counter;
} contact_t;


enum {
    AM_MSG_TYPE = 6,
};

#endif
