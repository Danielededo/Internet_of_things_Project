#define NEW_PRINTF_SEMANTICS
#include "Project.h"
#include "printf.h"


configuration ProjectAppC {}
implementation {
    components MainC, Project as App;
    components new AMSenderC(AM_MSG_TYPE);
    components new AMReceiverC(AM_MSG_TYPE);
    components new TimerMilliC();
    components ActiveMessageC;
    components PrintfC;
    components SerialStartC;

    
    App.Boot -> MainC.Boot;
    App.Receive -> AMReceiverC;
    App.AMSend -> AMSenderC;
    App.AMControl -> ActiveMessageC;
    App.SendTimer -> TimerMilliC;
    
    App.Packet -> AMSenderC;
}


