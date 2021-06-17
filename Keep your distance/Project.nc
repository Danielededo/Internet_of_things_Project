
#include "Timer.h"
#include "Project.h"
#include "printf.h"

module Project @safe() {
    
    uses {
        interface Boot;
        interface Receive;
        interface AMSend;
        interface Timer<TMilli> as SendTimer;
        interface SplitControl as AMControl;
        interface Packet;
    	}
	}
	
implementation {

    message_t packet;

    bool locked;

    contact_t contacts[CONTACT_SLOTS];
    
    /************************** Functions ***********************************/
    
    void initContacts(){
		uint16_t i = 0;
		
		for(i = 0; i<CONTACT_SLOTS; i++){
		    contacts[i].timeStamp = 0;
		    contacts[i].counter = 0;
		}
    }
    
    contact_t* getContact(uint16_t id){
    
    	uint16_t i = 0; 
    
    	for(i = 0; i<CONTACT_SLOTS; i++){
			if (contacts[i].id==id) return &contacts[i];
		}
		return NULL;
    }
    
    contact_t* addContact(uint16_t id, uint32_t timeStamp){
    
    	contact_t* contact=getContact(0);
    	
    	if (contact!=NULL){
    		contact->id=id;
			contact->timeStamp=timeStamp;
			contact->counter=1;
			return contact;
    	}
    	else{
    		printf("Error adding mote");
    		return NULL;
    	}
    }
    
    /************************** Events ***********************************/
     
    event void Boot.booted() {
        call AMControl.start();
    }

    event void AMControl.startDone(error_t err) {
    
    
        if (err == SUCCESS) {
     
        	call SendTimer.startPeriodic(TIMER_LIMIT);
        	
        	printf("LOG_START:%u\n", TOS_NODE_ID);
        	printfflush();
        }
        else {
          printf("Initialization error. Retrying\n");
          printfflush();
          call AMControl.start();
        }
    }

    event void AMControl.stopDone(error_t err) {}
    
	
    event void SendTimer.fired() {
    
    uint16_t i = 0;
    
		for(i = 0; i<CONTACT_SLOTS; i++){
			
			if(call SendTimer.getNow() - contacts[i].timeStamp > TIMER_LIMIT+50 && contacts[i].counter > 0){
				printf("LOG_OUT:%u/%u\n", TOS_NODE_ID, contacts[i].id);
				printfflush();
				contacts[i].id=0;
				contacts[i].timeStamp=0;
				contacts[i].counter=0;
			}
		}
		
        if (locked) {
            return;
        }
        else {
		    	mote_msg_t* msg = (mote_msg_t*)call Packet.getPayload(&packet, sizeof(mote_msg_t));
		        if (msg == NULL) {
		        	printf("Delivery Error!\n");
		        	printfflush();
		        	return;
		        }
		        
		        msg->senderId = TOS_NODE_ID;
		        if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(mote_msg_t)) == SUCCESS) {
		            locked = TRUE;
		        }
		        else{
		        	printf("Delivery Error!\n");
		        	printfflush();
		        }
   			}
        }
        
    event void AMSend.sendDone(message_t* bufPtr, error_t error) {
      if (&packet == bufPtr) {
        locked = FALSE;
      }
    }


    event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
    	
		if (len != sizeof(mote_msg_t)) {
			return bufPtr;
		}
		else{
			mote_msg_t* msg = (mote_msg_t*)payload;
			uint16_t senderId = msg->senderId;
			uint32_t timeStamp = call SendTimer.getNow();
			
			contact_t* contact=getContact(senderId);
			
			if (contact==NULL){
				contact=addContact(senderId,timeStamp);
				printf("LOG_RANGE:%u/%u\n", TOS_NODE_ID, contact->id);
				printfflush();
			}
			else if (contact->counter==COUNT_LIMIT - 1){
				printf("LOG_ALARM:%u/%u\n", TOS_NODE_ID, contact->id);
				printfflush();
				contact->timeStamp = timeStamp;
				contact->counter = 0;
			}
			else {
				contact->timeStamp = timeStamp;
				contact->counter++;
				printf("LOG_UPDATE:%u/%u-%u\n", contact->id, TOS_NODE_ID, contact->counter);
				printfflush();
			}
			
			return bufPtr;
	   }


   }
}

