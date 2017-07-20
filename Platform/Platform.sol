pragma solidity ^0.4.11;

import "../Contract/Own.sol";
import "../Contract/Token.sol";

contract Platform is Own{
    
	//VARIABLES
	Token public coin;
	bool public active;
	
	//EVENTS
	event projectLog(uint project_id, uint tokens);
	event charityTransfer(uint charity_id, uint tokens);
	
	//MODIFIERS
	modifier platformLock() {
		if ((active != true )) throw;
		_;
	}
	
	function Platform(address _TRIBEAddress){
	    coin = Token(_TRIBEAddress);
	}
	
	// Function for donating to running projects
	// TODO: check if project is over
	function project(uint project, uint amount) platformLock public{
	    projectLog(project, amount); 
	    coin.transferFrom(msg.sender, address(this), amount);
	}
	
	// Function to transfer tokens to a charity directly
	// TODO: transfer to the proper wallet after recieving funds right now it will burn them
	function charity(uint charity, uint amount) platformLock public{
	    charityTransfer(charity, amount);  
	    coin.transferFrom(msg.sender, 0x0, amount);
	}
	
	// Function to change PSC state
	function setState() onlyOwner public {
		if(active == false){
			active = true;
		}else{
			active = false;
		}
	}
}
