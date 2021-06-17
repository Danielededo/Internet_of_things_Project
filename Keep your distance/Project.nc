
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

    contact_t contacts[CONTACT_SLOTS]; // Contact list of all the other motes currently in range
    
    /************************** Functions ***********************************/
    
    
    /*
    This function clears all the contact entries:
    id=0 because no node can have such value
    timeStamp=0
    counter=0
    */ 
    void initContacts(){
		uint16_t i = 0;
		
		for(i = 0; i<CONTACT_SLOTS; i++){
			contacts[i].id=0;
		    contacts[i].timeStamp = 0;
		    contacts[i].counter = 0;
		}
    }
    
    // This function returns a pointer to the contact with the given id value
    contact_t* getContact(uint16_t id){
    
    	uint16_t i = 0; 
    
    	for(i = 0; i<CONTACT_SLOTS; i++){
			if (contacts[i].id==id) return &contacts[i];
		}
		return NULL;
    }
    
    /*
    This function adds a contact to the list, in the first position available, then it returns 
    a pointer to the newly added contact.
    If there is no space available, then it prints an error message and it returns a NULL value.
    */
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
     
    /*This event starts the mote*/
    event void Boot.booted() {
        call AMControl.start();
    }
	
	/*This event either signals that the mote started correctly (and is ready to
	start the timer accordingly) or it tries to start it again*/
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
    
    /*
    This event clears the contact list from all the nodes that are no longer in range.
    After that, it tries to broadcast the message and prints any error that may pop up.
    */	
    event void SendTimer.fired() {
    
    uint16_t i = 0;
    
		for(i = 0; i<CONTACT_SLOTS; i++){
			
			if(call SendTimer.getNow() - contacts[i].timeStamp > TIMER_LIMIT+50 && contacts[i].counter > 0){
			// The contact is erased if the latest message exchanged has a timestamp lower than the current time minus
			// 550 milliseconds to account also for possible delays or interferences.
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

	/*
	This event is triggered upon the reception of a message and it deals with the
	cases regarding the motes
	*/
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
			//If it is the first time that the two motes came in range, the mote is added to
			//the list of contacts.
				contact=addContact(senderId,timeStamp);
				printf("LOG_RANGE:%u/%u\n", TOS_NODE_ID, contact->id);
				printfflush();
			}
			else if (contact->counter==COUNT_LIMIT - 1){
			// If the contacts have already exchanged 10 packets, it is time to send an alarm message
				printf("LOG_ALARM:%u/%u\n", TOS_NODE_ID, contact->id);
				printfflush();
				contact->timeStamp = timeStamp;
				contact->counter = 0;
			}
			else {
			// If this is not the first message exchanged between the two motes, then the counter of
			//the appropriate entry of the contact list is simply incremented.
				contact->timeStamp = timeStamp;
				contact->counter++;
				printf("LOG_UPDATE:%u/%u-%u\n", contact->id, TOS_NODE_ID, contact->counter);
				printfflush();
			}
			
			return bufPtr;
	   }


   }
}

