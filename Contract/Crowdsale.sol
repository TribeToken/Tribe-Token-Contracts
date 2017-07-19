pragma solidity ^0.4.11;


import "./Pause.sol";
import "./Puller.sol";
import "./Token.sol";

contract Crowdsale is Pause, Puller {
    
    using SafeMath for uint;

  	struct Backer {
		uint weiReceived; // Amount of Ether given
		uint coinSent;
	}
    
	//CONSTANTS
	// Maximum number of TRIBE to sell
	uint public constant MAX_CAP = 160000000000000; // 160 000 000 TRIBE
	// Minimum amount to invest
	uint public constant MIN_INVEST_ETHER = 100 finney; // 0.1ETH
	// Crowdsale period
	uint private constant CROWDSALE_PERIOD = 22 days; // 22 days crowdsale run
	// Number of TRIBE per Ether
	uint public constant COIN_PER_ETHER = 3000000000; // 3 000 TRIBE


	//VARIABLES
	// TRIBE contract reference
	Token public coin;
    // Multisig contract that will receive the Ether
	address public multisigEther;
	// Number of Ether received
	uint public etherReceived;
	// Number of TRIBE sent to Ether contributors
	uint public coinSentToEther;
  // Number of TRIBE to burn
  uint public coinToBurn;
	// Crowdsale start time
	uint public startTime;
	// Crowdsale end time
	uint public endTime;
 	// Is crowdsale still on going
	bool public crowdsaleClosed;
	// Refund open variable
	bool public refundsOpen;

	// Backers Ether indexed by their Ethereum address
	mapping(address => Backer) public backers;


	//MODIFIERS
	modifier respectTimeFrame() {
		if ((now < startTime) || (now > endTime )) throw;
		_;
	}
	
	modifier refundStatus() {
		if ((refunds != true )) throw;
		_;
	}

	//EVENTS
	event LogReceivedETH(address addr, uint value);
	event LogCoinsEmited(address indexed from, uint amount);

	//Crowdsale Constructor
	function Crowdsale(address _TRIBEAddress, address _to) {
		coin = Token(_TRIBEAddress);
		multisigEther = _to;
	}
	
	// Default function to receive ether
	function() stopInEmergency respectTimeFrame payable {
		receiveETH(msg.sender);
	}

	 
	// To call to start the crowdsale
	function start() onlyOwner {
		if (startTime != 0) throw; // Crowdsale was already started

		startTime = now ;            
		endTime =  now + CROWDSALE_PERIOD;    
	}

	// Main function on ETH receive
	function receiveETH(address beneficiary) internal {
		if (msg.value < MIN_INVEST_ETHER) throw; // Do not accept investment if the amount is lower than the minimum allowed investment
		
		uint coinToSend = bonus(msg.value.mul(COIN_PER_ETHER).div(1 ether)); // Calculate the amount of tokens to send
		if (coinToSend.add(coinSentToEther) > MAX_CAP) throw;	

		Backer backer = backers[beneficiary];
		coin.transfer(beneficiary, coinToSend); // Transfer TRIBE

		backer.coinSent = backer.coinSent.add(coinToSend);
		backer.weiReceived = backer.weiReceived.add(msg.value); // Update the total wei collected during the crowdfunding for this backer    

		etherReceived = etherReceived.add(msg.value); // Update the total wei collected during the crowdfunding
		coinSentToEther = coinSentToEther.add(coinToSend);

		// Send events
		LogCoinsEmited(msg.sender ,coinToSend);
		LogReceivedETH(beneficiary, etherReceived); 
	}
	

	// Bonus function for the first week
	function bonus(uint amount) internal constant returns (uint) {
		if (now < startTime.add(7 days)) return amount.add(amount.div(5));   // bonus 20%
		return amount;
	}

	// Finalize function
	function finalize() onlyOwner public {

        // Check if the crowdsale has ended or if the old tokens have been sold
    if(coinSentToEther != MAX_CAP){
        if (now < endTime)  throw; // If Crowdsale still running
    }
		
		if (!multisigEther.send(this.balance)) throw; // Move the remaining Ether to the multisig address
		
		uint remains = coin.balanceOf(this);
		if (remains > 0) {
      coinToBurn = coinToBurn.add(remains);
      // Transfer remains to owner to burn
      coin.transfer(owner, remains);
		}
		crowdsaleClosed = true;
	}

	// Drain functions in case of unexpected issues with the smart contract.
  // ETH drain
	function drain() onlyOwner {
    if (!multisigEther.send(this.balance)) throw; //Transfer to team multisig wallet
	}
  // TOKEN drain
  function coinDrain() onlyOwner {
    uint remains = coin.balanceOf(this);
    coin.transfer(owner, remains); // Transfer to owner wallet
	}

	// Change multisig wallet in case its needed
	function changeMultisig(address addr) onlyOwner public {
		if (addr == address(0)) throw;
		multisigEther = addr;
	}

	// Change contract ownership
	function changeTribeOwner() onlyOwner public {
		coin.transferOwnership(owner);
	}

	// Toggle refund state on and off
	function setRefundState() onlyOwner public {
		if(enableRefund == false){
			enableRefund = true;
		}else{
			enableRefund = false;
		}
	}


	//Refund function when minimum cap isnt reached, this is step is step 2, THIS FUNCTION ONLY AVAILABLE AFTER BEING ENABLED.
	//STEP1: From TRIBE token contract use "approve" function with the amount of TRIBE you got in total.
	//STEP2: From TRIBE crowdsale contract use "refund" function with the amount of TRIBE you got in total.
	//STEP3: From TRIBE crowdsale contract use "withdrawPayement" function to recieve the ETH.
	function refund(uint _value) refundStatus public {
		
		if (_value != backers[msg.sender].coinSent) throw; // compare value from backer balance

		coin.transferFrom(msg.sender, address(this), _value); // get the token back to the crowdsale contract

		uint ETHToSend = backers[msg.sender].weiReceived;
		backers[msg.sender].weiReceived=0;

		if (ETHToSend > 0) {
			asyncSend(msg.sender, ETHToSend); // pull payment to get refund in ETH
		}
	}

}
