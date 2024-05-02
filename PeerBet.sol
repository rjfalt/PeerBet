//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract PeerBet is Ownable(msg.sender), Pausable {

    event betInitiated(bytes32 betId);
    event betMatched(bytes32 betId, address matcher);
    event betComplete(bytes32 betId, address winningAddress);

    address thirdPartyApprover = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4; //Can be company address
    uint256 betBalance;
    address winningAddress;


    struct Bet {
        bool betLive;
        address initiator;
        address matcher;
        uint256 betAmount;
        string game;
        string team;
        string spread;
    }

    mapping(bytes32 => Bet) private _bet;
    mapping(address => uint256) private _balances;

    /**
     * @dev Initiates an bet, emits event BetInitiated
     * Must check if auction already exists
     */

    function initiateBet(
        string calldata game, //Lakers vs. Nuggets
        string calldata team, // Lakers
        string calldata spread, // +7
        uint256 betAmount // Bet amount
    ) external {
        require(msg.sender != thirdPartyApprover, "Third Party Cannot Bet");
        bytes32 betId = getBetId(
            _msgSender(),
            game,
            team,
            spread,
            betAmount
        );
        Bet storage b = _bet[betId];
        /* require(
            !p.auctionLive && p.initiator == address(0),
            "Product Auction exists"
        ); */
        b.betLive = true;
        b.game = game;
        b.initiator = _msgSender();
        b.team = team;
        b.betAmount = betAmount;
        //p.floor = floor;
        //p.deadline = block.timestamp + deadline;
        require(_balances[_msgSender()] > b.betAmount, "Not enough funds");
        _balances[msg.sender] -= b.betAmount;
        betBalance += b.betAmount;
        emit betInitiated(betId);
    }


    /**
     * @dev Matches an initiated bet using existing funds, emits event betMatched
     * Must check if bet exists && match hasn't happened && bet amount is equal
     */
    function matchBet(bytes32 betId, uint256 amount) external {
        require(msg.sender != thirdPartyApprover, "Third Party Cannot Bet");
        Bet storage b = _bet[betId];
        require(b.betLive, "Bet Already Matched");
        require(_balances[_msgSender()] > b.betAmount, "Not enough funds");
        require(amount == b.betAmount, "Bet amount not equal");
        b.matcher = _msgSender();
        _balances[msg.sender] -= b.betAmount;
        betBalance += b.betAmount;
        b.betLive = false;
        emit betMatched(betId, msg.sender);
    }

    /**
     * @dev Settles an matched bet, emits event betEnded
     * Must check if bet has already ended
     */
    function settle(bytes32 betId, string calldata winner) external {
        Bet storage b = _bet[betId];
        require(msg.sender == thirdPartyApprover, "Not approved to settle this bet");
        bytes32 initiatorHash = keccak256(abi.encodePacked("initiator"));
        if (keccak256(abi.encodePacked(winner)) == initiatorHash){
            _balances[b.initiator] += betBalance;
            betBalance = 0;
            winningAddress = b.initiator;
        }
        bytes32 matcherHash = keccak256(abi.encodePacked("matcher"));
        if (keccak256(abi.encodePacked(winner)) == matcherHash){
            _balances[b.matcher] += betBalance;
            betBalance = 0;
            winningAddress = b.matcher;
        }
        emit betComplete(betId, winningAddress);
    }

    function balance() public view returns (uint) {
        return _balances[msg.sender];
}

    /**
     * @dev Users can deposit more funds into the contract to be used for future bids
     */
    function deposit() public payable returns (uint){
      _balances[msg.sender] += msg.value;
      return _balances[msg.sender];
   }
    /**
     * @dev Users can withdraw funds that were previously deposited
     */
    function withdraw(uint withdrawAmount) public returns (uint remainingBal) {
      if (withdrawAmount <= _balances[msg.sender]) {
         _balances[msg.sender] -= withdrawAmount;
         payable(msg.sender).transfer(withdrawAmount);
      }
      return _balances[msg.sender];
   }

    function getBetId(
        address initiator,
        //uint256 deadline,
        string calldata game, //Lakers vs. Nuggets
        string calldata team, // Lakers
        string calldata spread, // +7
        uint256 betAmount // Bet amount
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(initiator, game, team, spread, betAmount)
            );
    }
}