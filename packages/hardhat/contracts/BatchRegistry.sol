//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract BatchRegistry is Ownable {
    uint256 constant CHECK_IN_REWARD = 0.015 ether;

    string public s_batchName;
    mapping(address => bool) public s_allowList;
    mapping(address => address) public s_checkedInAddresses;
    bool public s_isOpen = true;
    uint256 public s_checkedInCounter;

    event CheckedIn(bool first, address builder, address checkInContract);

    // Errors
    error BatchNotOpen();
    error NotAContract();
    error NotInAllowList();

    modifier batchIsOpen() {
        if (!s_isOpen) revert BatchNotOpen();
        _;
    }

    modifier senderIsContract() {
        if (tx.origin == msg.sender) revert NotAContract();
        _;
    }

    constructor(address initialOwner, string memory batchName) Ownable(initialOwner) {
        s_batchName = batchName;
    }

    function updateAllowList(address[] calldata builders, bool[] calldata statuses) public onlyOwner {
        require(builders.length == statuses.length, "Builders and statuses length mismatch");

        for (uint256 i = 0; i < builders.length; i++) {
            s_allowList[builders[i]] = statuses[i];
        }
    }

    function toggleBatchOpenStatus() public onlyOwner {
        s_isOpen = !s_isOpen;
    }

    function checkIn() public senderIsContract batchIsOpen {
        if (!s_allowList[tx.origin]) revert NotInAllowList();

        bool wasFirstTime;
        if (s_checkedInAddresses[tx.origin] == address(0)) {
            s_checkedInCounter++;
            wasFirstTime = true;
            (bool success,) = tx.origin.call{value: CHECK_IN_REWARD}("");
            require(success, "Failed to send check in reward");
        }

        s_checkedInAddresses[tx.origin] = msg.sender;
        emit CheckedIn(wasFirstTime, tx.origin, msg.sender);
    }

    // Withdraw function for admins in case some builders don't end up checking in
    function withdraw() public onlyOwner {
        (bool success,) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Failed to withdraw");
    }

    receive() external payable {}
}
