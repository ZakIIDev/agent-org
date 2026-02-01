// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * Enhanced BountyEscrow
 * Improvements:
 * 1. Reentrancy Protection (via Checks-Effects-Interactions)
 * 2. Specific Error Types
 * 3. Enhanced Events for Off-chain Indexing
 * 4. Spec alignment with contracts/spec.schema.json
 */

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract BountyEscrow {
    enum Status { Open, Claimed, Submitted, Paid, Cancelled }

    struct Bounty {
        address creator;
        address solver;
        address token; // address(0) = native ETH
        uint256 amount;
        bytes32 metadataHash;
        uint64 createdAt;
        uint64 deadline;
        Status status;
    }

    // Specific Errors
    error NotOwner();
    error InvalidBounty();
    error BadStatus(Status expected, Status got);
    error DeadlinePassed();
    error NotSolver();
    error ZeroAmount();
    error TransferFailed();
    error AlreadyPaid();

    // Enhanced Events
    event BountyCreated(uint256 indexed bountyId, address indexed creator, address indexed token, uint256 amount, bytes32 metadataHash, uint64 deadline);
    event BountyClaimed(uint256 indexed bountyId, address indexed solver);
    event BountySubmitted(uint256 indexed bountyId, address indexed solver, bytes32 indexed workHash, string proofUrl);
    event BountyPaid(uint256 indexed bountyId, address indexed solver, address token, uint256 amount);
    event BountyCancelled(uint256 indexed bountyId, address indexed creator, uint256 refundAmount);

    address public immutable owner;
    uint256 public bountyCount;
    mapping(uint256 => Bounty) public bounties;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function createEthBounty(bytes32 metadataHash, uint64 deadline) external payable onlyOwner returns (uint256 bountyId) {
        if (msg.value == 0) revert ZeroAmount();
        
        bountyId = ++bountyCount;
        bounties[bountyId] = Bounty({
            creator: msg.sender,
            solver: address(0),
            token: address(0),
            amount: msg.value,
            metadataHash: metadataHash,
            createdAt: uint64(block.timestamp),
            deadline: deadline,
            status: Status.Open
        });
        
        emit BountyCreated(bountyId, msg.sender, address(0), msg.value, metadataHash, deadline);
    }

    function createErc20Bounty(address token, uint256 amount, bytes32 metadataHash, uint64 deadline) external onlyOwner returns (uint256 bountyId) {
        if (amount == 0) revert ZeroAmount();
        if (token == address(0)) revert InvalidBounty();

        bountyId = ++bountyCount;
        bounties[bountyId] = Bounty({
            creator: msg.sender,
            solver: address(0),
            token: token,
            amount: amount,
            metadataHash: metadataHash,
            createdAt: uint64(block.timestamp),
            deadline: deadline,
            status: Status.Open
        });

        // Pull funds (Checks-Effects-Interactions: pull last)
        if (!IERC20(token).transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        emit BountyCreated(bountyId, msg.sender, token, amount, metadataHash, deadline);
    }

    function claim(uint256 bountyId) external {
        Bounty storage b = _get(bountyId);
        if (b.status != Status.Open) revert BadStatus(Status.Open, b.status);
        if (b.deadline != 0 && block.timestamp > b.deadline) revert DeadlinePassed();
        
        b.solver = msg.sender;
        b.status = Status.Claimed;
        
        emit BountyClaimed(bountyId, msg.sender);
    }

    function submit(uint256 bountyId, bytes32 workHash, string calldata proofUrl) external {
        Bounty storage b = _get(bountyId);
        if (msg.sender != b.solver) revert NotSolver();
        if (b.status != Status.Claimed) revert BadStatus(Status.Claimed, b.status);
        
        b.status = Status.Submitted;
        
        emit BountySubmitted(bountyId, msg.sender, workHash, proofUrl);
    }

    function acceptAndPay(uint256 bountyId) external onlyOwner {
        Bounty storage b = _get(bountyId);
        if (b.status != Status.Submitted) revert BadStatus(Status.Submitted, b.status);
        
        address solver = b.solver;
        uint256 amount = b.amount;
        address token = b.token;

        // Effects
        b.status = Status.Paid;

        // Interactions
        if (token == address(0)) {
            (bool ok, ) = solver.call{value: amount}("");
            if (!ok) revert TransferFailed();
        } else {
            if (!IERC20(token).transfer(solver, amount)) revert TransferFailed();
        }

        emit BountyPaid(bountyId, solver, token, amount);
    }

    function cancel(uint256 bountyId) external onlyOwner {
        Bounty storage b = _get(bountyId);
        if (b.status == Status.Paid || b.status == Status.Cancelled) revert AlreadyPaid();
        
        uint256 amount = b.amount;
        address token = b.token;

        // Effects
        b.status = Status.Cancelled;

        // Interactions (Refund to owner)
        if (token == address(0)) {
            (bool ok, ) = owner.call{value: amount}("");
            if (!ok) revert TransferFailed();
        } else {
            if (!IERC20(token).transfer(owner, amount)) revert TransferFailed();
        }

        emit BountyCancelled(bountyId, owner, amount);
    }

    function _get(uint256 bountyId) internal view returns (Bounty storage b) {
        b = bounties[bountyId];
        if (b.creator == address(0)) revert InvalidBounty();
    }
}
