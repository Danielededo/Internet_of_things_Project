#ifndef PROJECT_HEADER
#define PROJECT_HEADER

#define CONTACT_SLOTS 20 //Slots reserved to contact entries
#define COUNT_LIMIT 10 // Upper bound of the counter
#define TIMER_LIMIT 500 // Timer of the firing of the message

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
